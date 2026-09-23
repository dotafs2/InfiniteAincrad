#!/usr/bin/env python3
"""Offline construction checks for the native Codex GPT-6 Luna GM route."""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gm_runner  # noqa: E402
from actor_usage import UsageBook  # noqa: E402
from test_gm_runner import RunnerTestBase  # noqa: E402


class NativeLunaRouteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / 'codex-home'
        self.home.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def make_native_route(self):
        with patch.object(gm_runner, 'read_windows_sandbox_backend', return_value='unelevated'):
            return gm_runner.Route(self.root / 'missing-config.json', self.root / 'missing-key.txt',
                                   'codex.exe', self.home, gm_runner.ROUTE_NATIVE_CODEX)

    def test_native_route_needs_no_deepseek_files_and_reports_only_route_metadata(self):
        route = self.make_native_route()
        self.assertEqual(route.model, 'gpt-6-luna')
        self.assertIsNone(route.key)
        reference = route.reference()
        self.assertEqual(reference['route'], 'native-codex')
        self.assertEqual(reference['model'], 'gpt-6-luna')
        self.assertEqual(reference['authentication'], 'codex_native')
        self.assertNotIn('key_path', reference)
        self.assertNotIn('config_path', reference)
        self.assertNotIn('api_key', json.dumps(reference).lower())

    def test_native_command_uses_account_route_without_deepseek_catalog_or_provider_pins(self):
        route = self.make_native_route()
        command = gm_runner.codex_command(route, self.root, self.root / 'result.md',
                                          self.root / 'instructions.md', None, None,
                                          sandbox='read-only', allow_tools=False)
        joined = ' '.join(command)
        self.assertIn('--ignore-user-config', command)
        self.assertIn('--model', command)
        self.assertIn('gpt-6-luna', command)
        self.assertIn('-s read-only', joined)
        self.assertIn('model_reasoning_effort="medium"', joined)
        self.assertIn('approval_policy="never"', joined)
        self.assertIn('model_instructions_file=', joined)
        self.assertNotIn('model_catalog_json', joined)
        self.assertNotIn('model_provider', joined)
        self.assertNotIn('chain_deepseek', joined)
        self.assertNotIn('api.deepseek.com', joined)
        # The API key name remains only in the shell-tool denylist, never as a provider.
        self.assertIn('shell_environment_policy.exclude=', joined)
        self.assertNotIn('model_providers.', joined)

    def test_native_environment_drops_provider_keys_and_proxies(self):
        route = self.make_native_route()
        injected = {'DEEPSEEK_API_KEY': 'deepseek-secret-marker',
                    'OPENAI_API_KEY': 'openai-secret-marker',
                    'KIMI_API_KEY': 'kimi-secret-marker',
                    'HTTPS_PROXY': 'proxy-marker'}
        with patch.dict(os.environ, injected, clear=False):
            env = route.environment()
        for name in injected:
            self.assertNotIn(name, env)
        self.assertNotIn('deepseek-secret-marker', json.dumps(env))
        self.assertNotIn('openai-secret-marker', json.dumps(env))

    def test_deepseek_default_keeps_its_provider_catalog_and_key(self):
        config = self.root / 'route.json'
        key = self.root / 'key.txt'
        config.write_text(json.dumps({'model': 'deepseek-flash',
                                      'base_url': 'https://api.deepseek.com'}), encoding='utf-8')
        key.write_text('sk-' + 'a' * 24, encoding='utf-8')
        with patch.object(gm_runner, 'read_windows_sandbox_backend', return_value=''):
            route = gm_runner.Route(config, key, 'codex.exe', self.home)
        command = gm_runner.codex_command(route, self.root, self.root / 'result.md',
                                          self.root / 'instructions.md',
                                          self.root / 'models.json', None)
        joined = ' '.join(command)
        self.assertEqual(route.route_kind, 'deepseek')
        self.assertIn('model="deepseek-flash"', joined)
        self.assertIn('model_provider="chain_deepseek"', joined)
        self.assertIn('model_catalog_json=', joined)
        self.assertIn('model_providers.chain_deepseek.base_url=', joined)

    def test_native_codex_usage_event_parser_remains_supported(self):
        session = '00000000-0000-4000-8000-000000000001'
        events = '\n'.join([
            json.dumps({'type': 'thread.started', 'thread_id': session}),
            json.dumps({'type': 'turn.completed', 'usage': {
                'input_tokens': 120, 'cached_input_tokens': 20,
                'output_tokens': 30, 'reasoning_output_tokens': 10,
                'total_tokens': 150}}),
        ])
        parsed = gm_runner.parse_events(events)
        self.assertEqual(parsed['thread_id'], session)
        self.assertEqual(parsed['usage']['input_tokens'], 120)
        self.assertEqual(parsed['usage']['output_tokens'], 30)
        self.assertEqual(parsed['turns_completed'], 1)


class NativeLunaEndToEndTests(RunnerTestBase):
    """Exercise runner persistence with its existing offline fake Codex transport."""

    def test_gm05_observation_and_feedback_resume_native_session_without_api_key_files(self):
        missing_config = self.root / 'no-provider-config.json'
        missing_key = self.root / 'no-provider-key.txt'
        fixture = self.accepted_document()
        residents = [{'stable_id': f"fixture:resident-{index:02d}", 'name': f'Resident {index:02d}'}
                     for index in range(10)]
        world = self.root / 'usage-world.json'
        world.write_text(json.dumps({'world_id': fixture['world_id'], 'residents': residents,
                                     'life': {'seq': 0}, 'godot': {}}), encoding='utf-8')
        code, bootstrapped, _ = self.cli(
            'bootstrap-world', '--state-dir', str(self.state), '--world-save', str(world),
            '--world-id', fixture['world_id'], route=False)
        self.assertEqual(code, 0, bootstrapped)
        usage_path = self.root / 'developer-usage.sqlite3'
        actors = [{'id': item['stable_id'], 'role': 'NPC', 'name': item['name']}
                  for item in residents]
        actors.extend({'id': gm_id, 'role': 'GM', 'name': f'GM {gm_id[-2:]}'}
                      for gm_id in gm_runner.GM_IDS)
        UsageBook(usage_path, fixture['world_id'], actors)
        state = gm_runner.load_state(self.state)
        state['developer_usage_book'] = str(usage_path)
        gm_runner.store_state(self.state, state)

        code, observed, _ = self.observe(
            '--gm', 'gm-05', '--max-gms', '1', '--route', gm_runner.ROUTE_NATIVE_CODEX,
            '--config', str(missing_config), '--key-file', str(missing_key), mode='claim')
        self.assertEqual(code, 0, observed)
        self.assertEqual(observed['dispatched'], 1)
        self.assertEqual(observed['route']['route'], gm_runner.ROUTE_NATIVE_CODEX)
        self.assertEqual(observed['route']['model'], gm_runner.NATIVE_CODEX_MODEL)
        gm = self.sessions()['gm-05']
        session_id = gm['session_id']
        self.assertTrue(gm_runner.SESSION_UUID.fullmatch(session_id))
        self.assertEqual(gm['attempts'][-1]['route'], gm_runner.ROUTE_NATIVE_CODEX)
        self.assertEqual(gm['attempts'][-1]['model'], gm_runner.NATIVE_CODEX_MODEL)
        self.assertEqual(gm['attempts'][-1]['status'], 'ok')
        self.assertTrue(gm['attempts'][-1]['usage_measured'])
        self.assertEqual(gm['attempts'][-1]['usage']['input_tokens'], 1200)
        first_calls = self.fake_calls()
        self.assertEqual(len(first_calls), 1)
        first_argv = first_calls[0]['argv']
        self.assertIn('--model', first_argv)
        self.assertIn(gm_runner.NATIVE_CODEX_MODEL, first_argv)
        self.assertNotIn('model_catalog_json', ' '.join(first_argv))
        self.assertNotIn('chain_deepseek', ' '.join(first_argv))

        receipt = self.root / 'native-feedback-receipt.json'
        receipt.write_text(json.dumps({'kind': 'host_receipt', 'review': 'offline fixture'}),
                           encoding='utf-8')
        code, feedback, _ = self.cli(
            'feedback', '--route', gm_runner.ROUTE_NATIVE_CODEX,
            '--state-dir', str(self.state), '--gm', 'gm-05', '--receipt-file', str(receipt))
        self.assertEqual(code, 0, feedback)
        self.assertTrue(feedback['acknowledged'])
        self.assertEqual(feedback['route'], gm_runner.ROUTE_NATIVE_CODEX)
        self.assertEqual(feedback['model'], gm_runner.NATIVE_CODEX_MODEL)
        self.assertTrue(feedback['usage_measured'])
        self.assertEqual(feedback['protected_paths_changed'], [])
        calls = self.fake_calls()
        self.assertEqual(len(calls), 2)
        self.assertIn('resume', calls[1]['argv'])
        self.assertEqual(calls[1]['argv'][calls[1]['argv'].index('resume') + 1], session_id)
        gm_after = self.sessions()['gm-05']
        self.assertEqual(gm_after['session_id'], session_id)
        self.assertEqual(gm_after.get('session_epoch', 1), 1)
        self.assertEqual(gm_after['feedback_attempts'][-1]['status'], 'ok')
        highwater = self.state_json()['usage_highwater'][session_id]
        self.assertEqual(highwater['input_tokens'], 2400)
        self.assertEqual(highwater['output_tokens'], 120)
        usage_calls = {row['id']: row for row in UsageBook(usage_path, fixture['world_id']).snapshot()['calls']}
        gm_usage = [row for row in usage_calls.values() if row['actor_id'] == 'gm-05']
        self.assertEqual(len(gm_usage), 2)
        self.assertEqual({row['model'] for row in gm_usage}, {gm_runner.NATIVE_CODEX_MODEL})
        self.assertEqual({row['status'] for row in gm_usage}, {'measured'})


if __name__ == '__main__':
    unittest.main()
