import json
from pathlib import Path
import tempfile
import unittest

from archive_conversation import archive, digest, extract


def log(messages):
    rows = [{'type': 'session_meta', 'payload': {'id': 'test-thread'}}]
    rows += [{'type': 'response_item', 'timestamp': f'time-{i}',
              'payload': {'type': 'message', 'role': role, 'phase': phase,
                          'content': [{'type': 'input_text', 'text': text}]}}
             for i, (role, phase, text) in enumerate(messages)]
    return ('\n'.join(json.dumps(row) for row in rows) + '\n').encode()


class ArchiveTests(unittest.TestCase):
    def test_goal_wakeup_is_not_published_as_a_user_message(self):
        data = log([('user', None, 'Upload all code'),
                    ('user', None, '  <codex_internal_context source="goal">PRIVATE SCHEDULER DATA</codex_internal_context>'),
                    ('assistant', 'final', 'Upload complete'),
                    ('user', None, 'Please explain <codex_internal_context source="goal">')])
        messages, excluded = extract(data, 'test-thread')
        self.assertEqual([row['text'] for row in messages],
                         ['Upload all code', 'Upload complete',
                          'Please explain <codex_internal_context source="goal">'])
        self.assertEqual(excluded['injected_workspace_context'], 1)

    def test_empty_heartbeat_does_not_hide_messages_or_attachments(self):
        data = log([('user', None, 'keep me'), ('assistant', 'final', ''),
                    ('assistant', 'commentary', ' '), ('user', None, 'keep me')])
        messages, excluded = extract(data, 'test-thread')
        self.assertEqual([row['text'] for row in messages], ['keep me', ' ', 'keep me'])
        self.assertEqual(excluded['empty_assistant_text'], 1)
        with self.assertRaisesRegex(ValueError, 'Empty visible'):
            extract(log([('user', None, '')]), 'test-thread')
        rows = [json.loads(line) for line in data.splitlines()]
        rows[2]['payload']['content'].append({'type': 'input_image', 'image_url': 'data:private'})
        with self.assertRaisesRegex(ValueError, 'attachment'):
            extract('\n'.join(json.dumps(row) for row in rows).encode(), 'test-thread')

    def test_visible_messages_preserve_repeats_and_exclude_internal_context(self):
        data = log([('user', None, '继续'), ('assistant', 'analysis', 'INTERNAL'),
                    ('developer', None, 'INSTRUCTIONS'), ('user', None, '<environment_context>INJECTED'),
                    ('assistant', 'commentary', '正在处理'), ('user', None, '继续'),
                    ('assistant', 'final_answer', '完成\n```json\n{}\n```')])
        messages, _ = extract(data, 'test-thread')
        self.assertEqual([row['text'] for row in messages], ['继续', '正在处理', '继续', '完成\n```json\n{}\n```'])

    def test_wrong_task_and_partial_log_are_rejected(self):
        data = log([('user', None, 'hello')])
        with self.assertRaisesRegex(ValueError, 'identity'):
            extract(data, 'wrong-thread')
        with self.assertRaises(ValueError):
            extract(data + b'{"partial":', 'test-thread')

    def test_credentials_and_unhandled_attachment_block_export(self):
        with self.assertRaisesRegex(ValueError, 'credential'):
            extract(log([('user', None, 'sk-' + 'a' * 30)]), 'test-thread')
        rows = [json.loads(line) for line in log([('user', None, 'hello')]).splitlines()]
        rows[1]['payload']['content'].append({'type': 'input_image', 'image_url': 'data:private'})
        with self.assertRaisesRegex(ValueError, 'attachment'):
            extract('\n'.join(json.dumps(row) for row in rows).encode(), 'test-thread')

    def test_refresh_is_append_only_and_manifest_hashes_match(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'source.jsonl'; output = root / 'archive'
            source.write_bytes(log([('user', None, 'first')]))
            archive(source, output, 'test-thread')
            source.write_bytes(log([('user', None, 'first'), ('assistant', 'final', ''),
                                    ('assistant', 'final', 'done')]))
            manifest = archive(source, output, 'test-thread')
            self.assertEqual(manifest['message_count'], 2)
            self.assertEqual(manifest['excluded_record_counts']['empty_assistant_text'], 1)
            for name, expected in manifest['files'].items():
                self.assertEqual(digest((output / name).read_bytes()), expected)
            before = (output / 'conversation.json').read_bytes()
            for content in ([('user', None, 'first')], [('user', None, 'changed')]):
                source.write_bytes(log(content))
                with self.assertRaisesRegex(ValueError, 'lose/change'):
                    archive(source, output, 'test-thread')
                self.assertEqual((output / 'conversation.json').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
