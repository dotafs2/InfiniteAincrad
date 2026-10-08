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
    def test_public_archive_redacts_contacts_and_fingerprints_images(self):
        rows = [json.loads(line) for line in log([('user', None, 'Contact person@example.com +86 13812345678; keep my correction')]).splitlines()]
        rows[1]['payload']['content'].append({'type': 'input_image', 'image_url': 'data:private'})
        data = '\n'.join(json.dumps(row) for row in rows).encode()
        messages, excluded = extract(iter(data.splitlines()), 'test-thread', public=True)
        text = messages[0]['text']
        self.assertNotIn('person@example.com', text)
        self.assertNotIn('13812345678', text)
        self.assertNotIn('data:private', text)
        self.assertIn('keep my correction', text)
        self.assertIn('source block SHA-256', text)
        self.assertEqual(messages[0]['public_redactions'], {'email': 1, 'phone': 1})
        self.assertEqual(excluded['image_payloads_retained_locally'], 1)
        with self.assertRaisesRegex(ValueError, 'credential'):
            extract(log([('user', None, 'sk-' + 'x' * 30)]), 'test-thread', public=True)

    def test_streamed_source_hash_and_browser_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'source.jsonl'
            data = log([('user', None, '<in-app-browser-context source="ambient-ui-state">?rapt=private</in-app-browser-context>\nKeep me')])
            source.write_bytes(data)
            manifest = archive(source, root / 'out', 'test-thread', public=True)
            self.assertEqual(manifest['source_snapshot_bytes'], len(data))
            self.assertEqual(manifest['source_snapshot_sha256'], digest(data))
            result = json.loads((root / 'out' / 'conversation.json').read_text())
            self.assertEqual(result['messages'][0]['text'], 'Keep me')

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
