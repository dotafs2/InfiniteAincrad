"""Archive visible messages from one explicitly selected local task, without tool logs.

Run again before each handoff/push. A timestamp and hashes make the covered interval
checkable; this is a snapshot, not a promise that future messages are already saved.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re


VISIBLE_PHASES = {'commentary', 'final', 'final_answer'}
CONTEXT_PREFIXES = ('# AGENTS.md instructions', '<environment_context>', '<codex_internal_context ')
SECRET_PATTERNS = (
    r'\bsk-[A-Za-z0-9_-]{20,}',
    r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})',
    r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    r'(?i)\b(?:api[_-]?key|access[_-]?token|authorization)\s*[=:]\s*["\']?(?:Bearer\s+)?[A-Za-z0-9_-]{24,}',
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def extract(data, expected_thread):
    messages, excluded = [], Counter()
    meta = None
    for number, line in enumerate(data.splitlines(), 1):
        if not line.strip():
            continue
        # A truncated or malformed log must not silently become a complete archive.
        record = json.loads(line)
        payload = record.get('payload', {})
        if record.get('type') == 'session_meta':
            meta = payload
        if record.get('type') != 'response_item' or payload.get('type') != 'message':
            excluded[record.get('type', 'unknown')] += 1
            continue
        role = payload.get('role')
        if role not in ('user', 'assistant'):
            excluded['non_conversation_role'] += 1
            continue
        phase = payload.get('phase', payload.get('channel'))
        if role == 'assistant' and phase not in VISIBLE_PHASES:
            excluded['non_visible_assistant_phase'] += 1
            continue
        content = payload.get('content', [])
        if any(block.get('type') not in ('input_text', 'output_text', 'text') for block in content):
            raise ValueError(f'Message at source line {number} includes an attachment; archive it explicitly first')
        body = ''.join(block.get('text', '') for block in content)
        if role == 'user' and body.lstrip().startswith(CONTEXT_PREFIXES):
            excluded['injected_workspace_context'] += 1
            continue
        # Quiet heartbeat turns can finish with no visible text. Record that
        # omission explicitly; attachment checks still run before this branch.
        # Empty user messages remain unsupported, and whitespace is preserved.
        if role == 'assistant' and body == '':
            excluded['empty_assistant_text'] += 1
            continue
        if not isinstance(body, str) or not body:
            raise ValueError(f'Empty visible message at source line {number}')
        if any(re.search(pattern, body) for pattern in SECRET_PATTERNS):
            raise ValueError(f'Possible credential in visible message at source line {number}; review before export')
        messages.append({'source_line': number, 'timestamp': record.get('timestamp'),
                         'role': role, 'phase': phase, 'text': body,
                         'text_sha256': digest(body.encode('utf-8'))})
    if not meta or meta.get('id') != expected_thread:
        raise ValueError('Source task identity does not match --thread-id')
    if not messages or not any(row['role'] == 'user' for row in messages):
        raise ValueError('No visible conversation found; unsupported log schema or empty task')
    return messages, excluded


def archive(source, output, thread_id):
    # Snapshot once; a concurrent append is outside this recorded byte boundary.
    with source.open('rb') as stream:
        size = source.stat().st_size
        data = stream.read(size)
    messages, excluded = extract(data, thread_id)
    snapshot = {'schema_version': 1, 'thread_id': thread_id, 'messages': messages}
    serialized = (json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    markdown = ['# 本任务对话原文快照\n', f'任务：`{thread_id}`\n',
                f'范围：{messages[0]["timestamp"]} 至 {messages[-1]["timestamp"]}，共 {len(messages)} 条。\n',
                '保留用户消息、助手进度和最终答复；不含内部推理、系统指令、工具日志与注入环境信息。'
                '没有补写未留存的旧对话；本文件是截至上述时间的快照。Markdown 展示去除行尾空格，'
                '含完整空白的结构化原文与校验见同目录 JSON 文件。\n']
    for index, row in enumerate(messages, 1):
        label = '用户' if row['role'] == 'user' else '助手'
        markdown.append(f'## {index}. {label} · {row["timestamp"]}\n')
        fence = '`' * max(4, 1 + max((len(x) for x in re.findall(r'`+', row['text'])), default=0))
        display_text = '\n'.join(line.rstrip() for line in row['text'].splitlines())
        markdown.append(f'{fence}text\n{display_text}\n{fence}\n')
    rendered = '\n'.join(markdown).encode('utf-8')
    manifest = {'schema_version': 1, 'thread_id': thread_id,
                'exported_at_utc': datetime.now(timezone.utc).isoformat(),
                'source_basename': source.name, 'source_snapshot_bytes': len(data),
                'source_snapshot_sha256': digest(data),
                'first_message_at': messages[0]['timestamp'], 'last_message_at': messages[-1]['timestamp'],
                'message_count': len(messages), 'role_counts': dict(Counter(row['role'] for row in messages)),
                'excluded_record_counts': dict(excluded),
                'coverage': 'visible text messages in this task only; no other tasks, tool logs, internal reasoning, or future messages',
                'files': {'conversation.json': digest(serialized), 'conversation.md': digest(rendered)}}
    # Refuse a refresh that would erase already archived messages or change their text.
    existing = output / 'conversation.json'
    if existing.exists():
        previous = json.loads(existing.read_text(encoding='utf-8'))
        if previous['thread_id'] != thread_id or snapshot['messages'][:len(previous['messages'])] != previous['messages']:
            raise ValueError('Refresh would lose/change earlier archived messages; preserve the previous snapshot')
    output.mkdir(parents=True, exist_ok=True)
    for name, body in [('conversation.json', serialized), ('conversation.md', rendered),
                       ('manifest.json', (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))]:
        temporary = output / (name + '.next')
        temporary.write_bytes(body)
        temporary.replace(output / name)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', type=Path, required=True)
    parser.add_argument('--thread-id', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    manifest = archive(args.session, args.out, args.thread_id)
    print(json.dumps({key: manifest[key] for key in ('thread_id', 'message_count', 'role_counts', 'last_message_at', 'files')}))


if __name__ == '__main__':
    main()
