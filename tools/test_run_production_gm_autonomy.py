import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools import run_production_gm_autonomy as bridge


WORLD = 'shared:aincrad-trial-1'


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding='utf-8')


def world(seq=142):
    residents = [{'stable_id': f'shared:r{i}', 'name': f'r{i}', 'runtime': {}}
                 for i in range(10)]
    return {'world_id': WORLD, 'residents': residents,
            'life': {'seq': seq, 'events': [{'event_id': 'old'}]},
            'godot': {'resident_turns': {'shared:innkeeper': {
                'status': 'rule_rejection', 'request_id': 'turn:shared:innkeeper:0:18',
                'replan_policy': 'stale_option_v1', 'result': {'code': 'option_unavailable'}}}}}


class ProductionBridgeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.world = self.root / 'world.json'
        self.state = self.root / 'state'
        self.deploy = self.root / 'deploy'
        self.policy = self.root / 'policy.json'
        self.scope = self.root / 'scope.json'
        self.out = self.root / 'run'
        self.deploy.mkdir()
        self.state.mkdir()
        write(self.world, world())
        write(self.policy, {'paths': {}, 'deployment': {}, 'runtime': {},
                            'limits': {'max_model_calls': 20}})
        self.base_scope = {
            'schema_version': 1, 'world_id': WORLD, 'canonical_world': str(self.world),
            'gm_state_dir': str(self.state), 'deployment_checkout': str(self.deploy),
            'autonomy_policy_template': str(self.policy), 'life_command': [
                'life', '--world={world}', '--out={out}', '--evidence={evidence}',
                '--max-requests={max_requests}'],
            'out_root': str(self.out), 'max_cycles': 2, 'max_seconds': 600,
            'life_timeout': 30, 'autonomy_timeout': 30, 'head': 'head',
            'stop_file': str(self.root/'stop'), 'status_path': str(self.root/'status.json'),
            'life_max_requests': 32, 'max_kimi_requests': 64, 'max_gm_model_calls': 20,
            'settlement_reserve_seconds': 5,
            'canonical_world_sha256': bridge.sha(self.world),
            'allowed_existing_model_errors': {'shared:innkeeper': {
                'status': 'rule_rejection', 'request_id': 'turn:shared:innkeeper:0:18',
                'result_code': 'option_unavailable', 'replan_policy': 'stale_option_v1'}}}

    def tearDown(self):
        self.tmp.cleanup()

    def fake_run(self, command, cwd, timeout, log, env=None):
        if command[0] == 'life':
            values = dict(token.split('=', 1) for token in command[1:])
            current = json.loads(self.world.read_text())
            current['life']['seq'] += 1
            write(self.world, current)
            out = Path(values['--out'])
            write(out/'result.json', {'engine_exit': 0, 'validation_passed': False,
                  'model_errors': {'shared:innkeeper': 'rule_rejection'},
                  'ledger_before': {'ledger_id':'ledger','model':'kimi-k2.6',
                                    'counts': {'settled':1139,'uncertain':6}},
                  'ledger_after': {'ledger_id':'ledger','model':'kimi-k2.6','halted':'',
                                   'counts': {'settled':1140,'uncertain':6}},
                  'budget_stop_reason':'','carried_uncertainty_reviewed':True,
                  'upstream_requests': 1})
            write(Path(values['--evidence']), {
                'world_id': WORLD, 'evidence': [],
                'source_revision': {'life_seq': current['life']['seq'],
                                    'world_elapsed_seconds': current.get('elapsed_seconds', 3076.75)}})
            current.setdefault('elapsed_seconds', 3076.75)
        else:
            Path(log).parent.mkdir(parents=True, exist_ok=True)
            Path(log).write_text('diagnostic\n' + json.dumps({
                'status': 'no_action', 'cycle_id': 'same-evidence-cycle',
                'usage': {'model_calls': 10}}) + '\n', encoding='utf-8')
        return {'exit_code': 0, 'timed_out': False,
                'owned': {'all_members_exited': True, 'active': 0}}

    def test_no_action_does_not_end_ongoing_life_and_limits_are_carried(self):
        write(self.scope, self.base_scope)
        fixed = {'head': 'head', 'files': {'a': '1'}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value=fixed), \
             mock.patch.object(bridge, 'run_owned', side_effect=self.fake_run):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual(len(result['cycles']), 2)
        self.assertEqual(result['kimi_requests'], 2)
        self.assertEqual(result['gm_model_calls'], 10)
        self.assertEqual([c['gm_usage_counted'] for c in result['cycles']], [True, False])
        self.assertTrue(all(c['status'] == 'closed' for c in result['cycles']))
        status = json.loads((self.root/'status.json').read_text())
        self.assertEqual(status['status'], 'completed_finite')
        self.assertEqual(status['pid'], result['pid'])

    def _life_run(self, model_errors, mutate=None, evidence_revision=None, exit_code=0,
                  capture=None, export_world=WORLD):
        # Actual launcher schema from the real run: per-actor model_errors, settled ledger
        # counts, and a public export carrying source_revision.
        def run(command, cwd, timeout, log, env=None):
            if command[0] != 'life':
                if capture is not None:
                    capture['autonomy_command'] = list(command)
                Path(log).parent.mkdir(parents=True, exist_ok=True)
                Path(log).write_text('diagnostic\n' + json.dumps({
                    'status': 'no_action', 'cycle_id': 'local-failure-cycle',
                    'usage': {'model_calls': 10}}) + '\n', encoding='utf-8')
                return {'exit_code': 0, 'timed_out': False,
                        'owned': {'all_members_exited': True, 'active': 0}}
            values = dict(token.split('=', 1) for token in command[1:])
            current = json.loads(self.world.read_text())
            if mutate is not None:
                mutate(current)
            current['life']['seq'] += 1
            write(self.world, current)
            out = Path(values['--out'])
            write(out/'result.json', {'engine_exit': 0, 'validation_passed': False,
                  'model_errors': dict(model_errors), 'upstream_requests': 1,
                  'budget_stop_reason': '', 'carried_uncertainty_reviewed': True,
                  'ledger_before': {'ledger_id': 'ledger', 'model': 'kimi-k2.6',
                                    'counts': {'settled': 1139, 'uncertain': 6}},
                  'ledger_after': {'ledger_id': 'ledger', 'model': 'kimi-k2.6', 'halted': '',
                                   'counts': {'settled': 1140, 'uncertain': 6}}})
            export = {'world_id': export_world, 'evidence': []}
            export['source_revision'] = ({'life_seq': current['life']['seq'],
                                          'world_elapsed_seconds': current.get('elapsed_seconds', 3076.75)}
                                         if evidence_revision is None else evidence_revision)
            write(Path(values['--evidence']), export)
            return {'exit_code': exit_code, 'timed_out': False,
                    'owned': {'all_members_exited': True, 'active': 0}}
        return run

    def test_real_schema_local_provider_error_is_quarantined_and_life_and_gm_continue(self):
        write(self.scope, self.base_scope)
        def herder(current):
            current['godot']['resident_turns']['shared:herder'] = {
                'status': 'provider_error', 'request_id': 'turn:shared:herder:0:9',
                'result': {'code': 'provider_error'}}
        fixed = {'head': 'head', 'files': {'a': '1'}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value=fixed), \
             mock.patch.object(bridge, 'run_owned',
                               side_effect=self._life_run({'shared:herder': 'provider_error'},
                                                          mutate=herder, exit_code=1)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual(len(result['cycles']), 2, "a local settled failure must not stop the loop")
        self.assertEqual(result['degraded_residents'], ['shared:herder'])
        self.assertEqual(result['local_failure_classes'], ['resident_local_settled_quarantine'])
        receipt = result['cycles'][0]['local_failures'][0]
        self.assertEqual((receipt['actor'], receipt['classification'], receipt['request_id']),
                         ('shared:herder', 'resident_local_settled_quarantine', 'turn:shared:herder:0:9'))
        self.assertNotIn('reason', receipt)

    def test_bridge_module_is_the_exact_sibling_under_test(self):
        # Portable: anchored in THIS file's own directory, so a private run verifies the private
        # sibling and an installed run verifies the installed sibling - never a hardcoded path.
        module_path = Path(bridge.__file__).resolve()
        sibling = (Path(__file__).resolve().parent / 'run_production_gm_autonomy.py').resolve()
        self.assertEqual(module_path, sibling,
                         'the imported bridge must be the exact sibling module next to this test file')

    def test_input_too_large_identifier_reaches_the_host_projection(self):
        write(self.scope, self.base_scope)
        def carpenter(current):
            current['godot']['resident_turns']['shared:carpenter'] = {
                'status': 'provider_error', 'error': 'brain_input_too_large',
                'request_id': 'turn:shared:carpenter:1:13',
                'result': {'code': 'provider_error'}}
        fixed = {'head': 'head', 'files': {'a': '1'}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value=fixed), \
             mock.patch.object(bridge, 'run_owned',
                               side_effect=self._life_run({'shared:carpenter': 'provider_error'},
                                                          mutate=carpenter, exit_code=1)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        receipt = result['cycles'][0]['local_failures'][0]
        self.assertEqual((receipt['actor'], receipt['request_id'], receipt['error_identifier']),
                         ('shared:carpenter', 'turn:shared:carpenter:1:13', 'brain_input_too_large'))
        self.assertEqual(receipt['classification'], 'resident_local_settled_quarantine')
        projections = list(Path(self.out).rglob(bridge.OPERATIONAL_EVIDENCE_NAME))
        self.assertTrue(projections, "the host operational projection must exist")
        document = json.loads(projections[0].read_text())
        entries = [e for e in document['evidence']
                   if e.get('evidence_kind') == bridge.OPERATIONAL_EVIDENCE_KIND]
        self.assertEqual(len(entries), 1)
        self.assertEqual((entries[0]['operational']['actor'], entries[0]['operational']['request_id'],
                          entries[0]['operational']['error_identifier']),
                         ('shared:carpenter', 'turn:shared:carpenter:1:13', 'brain_input_too_large'))
        self.assertNotIn('reason', entries[0]['operational'])

    def test_unknown_or_secret_like_error_text_never_reaches_the_projection(self):
        secret = 'token=sk-live-9f3c-private-marker'
        self.assertIsNone(bridge.known_error_identifier({'error': secret}))
        self.assertIsNone(bridge.known_error_identifier({'error': None}))
        self.assertIsNone(bridge.known_error_identifier({}))
        self.assertIsNone(bridge.known_error_identifier({'error': 'brand_new_unknown_class'}))
        self.assertEqual(bridge.known_error_identifier({'error': 'brain_input_too_large'}),
                         'brain_input_too_large')
        self.assertEqual(bridge.known_error_identifier({'error': 'brain_session_request_limit'}),
                         'brain_session_request_limit')
        source = self.out/'source-export.json'
        write(source, {'world_id': WORLD, 'evidence': [], 'proposals': [],
                       'source_revision': {'life_seq': 180, 'world_elapsed_seconds': 3766.5}})
        receipts = [
            {'actor': 'shared:carpenter', 'code': 'provider_error', 'controller_status': 'provider_error',
             'request_id': 'turn:shared:carpenter:1:13', 'result_code': None, 'replan_policy': None,
             'classification': 'resident_local_settled_quarantine',
             'error_identifier': bridge.known_error_identifier({'error': secret})},
            {'actor': 'shared:herder', 'code': 'provider_error', 'controller_status': 'provider_error',
             'request_id': 'turn:shared:herder:0:16', 'result_code': None, 'replan_policy': None,
             'classification': 'resident_local_settled_quarantine'},
        ]
        destination = self.out/'projection.json'
        result = bridge.build_operational_evidence(source, receipts, destination)
        text = destination.read_text()
        self.assertNotIn(secret, text)
        self.assertNotIn('sk-live', text)
        self.assertEqual(result['appended_operational_entries'], 2)
        self.assertEqual(result['parser_errors'], [])
        entries = result and json.loads(text)['evidence']
        by_actor = {e['operational']['actor']: e['operational'] for e in entries}
        self.assertIsNone(by_actor['shared:carpenter']['error_identifier'],
                          "unknown text must be omitted, never forwarded")
        self.assertIsNone(by_actor['shared:herder']['error_identifier'],
                          "a legacy receipt without an identifier keeps its generic semantics")
        self.assertEqual(by_actor['shared:herder']['classification'], 'resident_local_settled_quarantine')
        self.assertEqual(by_actor['shared:herder']['code'], 'provider_error')

    def test_real_schema_known_stale_option_cooldown_is_not_fatal(self):
        scope = dict(self.base_scope)
        scope['allowed_existing_model_errors'] = {'shared:well-keeper': {
            'status': 'rule_rejection', 'request_id': 'turn:shared:well-keeper:0:17',
            'result_code': 'option_unavailable', 'replan_policy': 'stale_option_v1'}}
        write(self.scope, scope)
        stale = {'status': 'rule_rejection', 'request_id': 'turn:shared:well-keeper:0:17',
                 'result': {'code': 'option_unavailable'}, 'replan_policy': 'stale_option_v1'}
        def seed(current):
            current['godot']['resident_turns']['shared:well-keeper'] = dict(stale)
        seeded = world()
        current = json.loads(self.world.read_text()); seed(current); write(self.world, current)
        fixed = {'head': 'head', 'files': {'a': '1'}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value=fixed), \
             mock.patch.object(bridge, 'run_owned',
                               side_effect=self._life_run({'shared:well-keeper': 'rule_rejection'})):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual(result['local_failure_classes'], ['known_stale_option_cooldown'])

    def test_ambiguous_or_global_error_code_still_stops_the_run(self):
        write(self.scope, self.base_scope)
        def ambiguous(current):
            current['godot']['resident_turns']['shared:herder'] = {
                'status': 'provider_error', 'request_id': 'turn:shared:herder:0:9',
                'result': {'code': 'provider_error'}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned',
                               side_effect=self._life_run({'shared:herder': 'gateway_timeout'},
                                                          mutate=ambiguous, exit_code=1)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 1)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['reason'], 'new_life_model_error')
        self.assertEqual(result['cycles'][0]['fatal_errors'][0]['classification'],
                         'fatal_global_or_ambiguous')

    def test_absolute_cutoff_and_admission_buffer_stop_without_dispatch(self):
        import datetime as _dt
        now = _dt.datetime.now(_dt.timezone.utc)
        exhausted = dict(self.base_scope)
        exhausted['cutoff_utc'] = (now - _dt.timedelta(seconds=60)).isoformat()
        write(self.scope, exhausted)
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=AssertionError('no dispatch')):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['reason'], 'absolute_cutoff')
        self.assertEqual(result['cycles'], [])

        tight = dict(self.base_scope)
        tight['out_root'] = str(self.root/'run-tight')
        tight['status_path'] = str(self.root/'status-tight.json')
        tight['cutoff_utc'] = (now + _dt.timedelta(seconds=30)).isoformat()
        write(self.scope, tight)
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=AssertionError('no dispatch')):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        tight_result = json.loads((self.root/'run-tight'/'run.json').read_text())
        self.assertEqual(tight_result['reason'], 'absolute_cutoff_admission_buffer')
        self.assertEqual(tight_result['cycles'], [], "no cycle may start without its settling buffer")

    def test_cutoff_utc_is_type_and_format_validated(self):
        bad = dict(self.base_scope); bad['cutoff_utc'] = 'not-a-timestamp'
        errors = bridge.validate(bad)
        self.assertTrue(any('cutoff_utc' in e for e in errors), errors)
        wrong = dict(self.base_scope); wrong['admission_buffer_seconds'] = 'soon'
        self.assertTrue(any('admission_buffer_seconds' in e for e in bridge.validate(wrong)))

    def test_final_evidence_freshness_is_recorded_and_enforced_when_required(self):
        scope = dict(self.base_scope)
        write(self.scope, scope)
        stale_revision = {'life_seq': 142, 'world_elapsed_seconds': 2177.75}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned',
                               side_effect=self._life_run({'shared:innkeeper': 'rule_rejection'},
                                                          evidence_revision=stale_revision)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        freshness = result['cycles'][0]['final_evidence_freshness']
        self.assertFalse(freshness['fresh'], "the real stale-export gap must be visible in the durable run")
        self.assertEqual(freshness['export_life_seq'], 142)

        strict = dict(self.base_scope); strict['require_fresh_final_evidence'] = True
        self.out2 = self.root/'run2'
        strict['out_root'] = str(self.out2); strict['status_path'] = str(self.root/'status2.json')
        write(self.scope, strict)
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned',
                               side_effect=self._life_run({'shared:innkeeper': 'rule_rejection'},
                                                          evidence_revision=stale_revision)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 1)
        strict_result = json.loads((self.out2/'run.json').read_text())
        self.assertEqual(strict_result['reason'], 'final_evidence_stale_or_unverifiable')

    def _error_world(self, extra_failures=()):
        current = world()
        current['elapsed_seconds'] = 3076.75
        current['godot']['resident_turns']['shared:well-keeper'] = {
            'status': 'rule_rejection', 'request_id': 'turn:shared:well-keeper:0:17',
            'result': {'code': 'option_unavailable'}, 'replan_policy': 'stale_option_v1',
            'error': 'PRIVATE_SENTINEL_TEXT', 'accepted_reply': {'reason': 'PRIVATE_SENTINEL_TEXT'}}
        current['godot']['resident_turns']['shared:herder'] = {
            'status': 'provider_error', 'request_id': 'turn:shared:herder:0:9',
            'result': {'code': 'provider_error'}, 'error': 'PRIVATE_SENTINEL_TEXT'}
        return current

    def test_operational_projection_reaches_gm_with_both_real_schema_failures(self):
        scope = dict(self.base_scope)
        scope['allowed_existing_model_errors'] = {'shared:well-keeper': {
            'status': 'rule_rejection', 'request_id': 'turn:shared:well-keeper:0:17',
            'result_code': 'option_unavailable', 'replan_policy': 'stale_option_v1'}}
        write(self.scope, scope)
        seeded = self._error_world(); write(self.world, seeded)
        capture = {}
        export_hashes = {}
        def mutate(current):
            current['elapsed_seconds'] = 3100.5
            for actor in ('shared:well-keeper', 'shared:herder'):
                current['godot']['resident_turns'][actor] = dict(seeded['godot']['resident_turns'][actor])
        inner = self._life_run({'shared:well-keeper': 'rule_rejection', 'shared:herder': 'provider_error'},
                               mutate=mutate, exit_code=1, capture=capture)
        def run(command, cwd, timeout, log, env=None):
            if command[0] == 'life':
                passed = inner(command, cwd, timeout, log, env)
                export = Path(dict(tok.split('=', 1) for tok in command[1:])['--evidence'])
                export_hashes['after'] = bridge.sha(export)
                return passed
            return inner(command, cwd, timeout, log, env)
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=run):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['status'], 'completed_finite', "healthy life and the GM phase continue")
        self.assertEqual(result['degraded_residents'], ['shared:herder', 'shared:well-keeper'])
        record = result['cycles'][-1]
        projection_path = Path(record['operational_evidence']['path'])
        policy_path = Path(capture['autonomy_command'][capture['autonomy_command'].index('--policy') + 1])
        policy = json.loads(policy_path.read_text())
        self.assertEqual(Path(policy['paths']['evidence']), projection_path,
                         "the GM intake must read the labelled combined projection")
        document = json.loads(projection_path.read_text())
        self.assertEqual(bridge.gm_runner.validate_evidence(document), [], "the GM parser must accept it")
        self.assertEqual(document['counts'],
                         {'issues': len(document['evidence']), 'proposals': len(document['proposals'])})
        self.assertTrue(document['boundaries'])
        kinds = [e['evidence_kind'] for e in document['evidence']]
        self.assertEqual(kinds.count(bridge.OPERATIONAL_EVIDENCE_KIND), 2,
                         "both degraded actors must be visible to the GM intake")
        self.assertEqual(document['operational_projection']['source_export_sha256'],
                         record['operational_evidence']['source_export_sha256'])
        self.assertTrue(record['operational_evidence']['source_export_bytes_unchanged'])
        self.assertEqual(record['operational_evidence']['source_export_sha256'], export_hashes['after'],
                         "the game export bytes are preserved")
        blob = json.dumps(document)
        self.assertNotIn('PRIVATE_SENTINEL_TEXT', blob,
                         "no raw error text, reason or accepted reply may reach the projection")
        receipts = [e['operational'] for e in document['evidence'] if e['evidence_kind'] == bridge.OPERATIONAL_EVIDENCE_KIND]
        self.assertEqual(sorted(r['actor'] for r in receipts), ['shared:herder', 'shared:well-keeper'])
        self.assertTrue(all(set(r) <= {'actor', 'controller_status', 'request_id', 'code', 'result_code',
                                       'error_identifier',
                                       'replan_policy', 'classification'} for r in receipts))

    def test_freshness_requires_exact_world_seq_and_elapsed_time(self):
        write(self.scope, dict(self.base_scope))
        cases = [
            ('same_seq_stale_time', {'life_seq': 2, 'world_elapsed_seconds': 100.0}, WORLD),
            ('future_seq', {'life_seq': 99, 'world_elapsed_seconds': 3100.5}, WORLD),
            ('wrong_world', {'life_seq': 2, 'world_elapsed_seconds': 3100.5}, 'shared:other-town'),
        ]
        for label, revision, export_world in cases:
            self.out = self.root / f'run-{label}'
            scope = dict(self.base_scope)
            scope['out_root'] = str(self.out)
            scope['status_path'] = str(self.root / f'status-{label}.json')
            write(self.scope, scope)
            def mutate(current):
                current['elapsed_seconds'] = 3100.5
            with mock.patch.object(bridge, 'validate', return_value=[]), \
                 mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
                 mock.patch.object(bridge, 'run_owned',
                                   side_effect=self._life_run({'shared:innkeeper': 'rule_rejection'},
                                                              mutate=mutate, evidence_revision=revision,
                                                              export_world=export_world)):
                self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
            freshness = json.loads((self.out/'run.json').read_text())['cycles'][0]['final_evidence_freshness']
            self.assertFalse(freshness['fresh'], label)

    def test_cutoff_naive_timestamp_is_refused_without_crashing(self):
        naive = dict(self.base_scope)
        naive['cutoff_utc'] = '2026-09-14T01:00:00'
        self.assertTrue(any('timezone offset' in e for e in bridge.validate(naive)))
        write(self.scope, naive)
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=AssertionError('no dispatch')):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 2, "a naive cutoff is refused, never a crash")
        self.assertFalse(self.out.exists(), "refusal happens before any output or dispatch")

    def test_unknown_accounting_change_still_stops_the_run(self):
        write(self.scope, dict(self.base_scope))
        def run(command, cwd, timeout, log, env=None):
            values = dict(token.split('=', 1) for token in command[1:])
            current = json.loads(self.world.read_text()); current['life']['seq'] += 1
            current['elapsed_seconds'] = 3100.5; write(self.world, current)
            out = Path(values['--out'])
            write(out/'result.json', {'engine_exit': 0, 'validation_passed': False,
                  'model_errors': {'shared:herder': 'provider_error'}, 'upstream_requests': 1,
                  'budget_stop_reason': '', 'carried_uncertainty_reviewed': True,
                  'ledger_before': {'ledger_id': 'ledger', 'model': 'kimi-k2.6', 'counts': {'uncertain': 6}},
                  'ledger_after': {'ledger_id': 'ledger', 'model': 'kimi-k2.6', 'halted': '',
                                   'counts': {'uncertain': 7}}})
            write(Path(values['--evidence']), {'world_id': WORLD, 'evidence': [],
                                               'source_revision': {'life_seq': current['life']['seq'],
                                                                   'world_elapsed_seconds': 3100.5}})
            return {'exit_code': 1, 'timed_out': False,
                    'owned': {'all_members_exited': True, 'active': 0}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=run):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 1)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['reason'], 'ledger_identity_or_uncertainty_changed',
                         "a new unknown cost is never swallowed as a local failure")



    def test_new_provider_error_fails_closed_with_nonzero_exit(self):
        scope = dict(self.base_scope)
        write(self.scope, scope)
        def bad_run(command, cwd, timeout, log, env=None):
            if command[0] != 'life':
                Path(log).parent.mkdir(parents=True, exist_ok=True)
                Path(log).write_text(json.dumps({'status': 'no_action', 'usage': {'model_calls': 0}}) + '\n',
                                     encoding='utf-8')
                return {'exit_code': 0, 'timed_out': False,
                        'owned': {'all_members_exited': True, 'active': 0}}
            values = dict(token.split('=', 1) for token in command[1:])
            changed = world()
            changed['godot']['resident_turns']['shared:fisher'] = {
                'status': 'provider_error', 'request_id': 'turn:shared:fisher:2:16',
                'result': {'code': 'brain_response_invalid'}}
            write(self.world, changed)
            out = Path(values['--out'])
            write(out/'result.json', {'engine_exit': 0, 'validation_passed': False,
                  'model_errors': {'shared:fisher': 'gateway_contract_violation'}, 'upstream_requests': 1,
                  'budget_stop_reason':'','carried_uncertainty_reviewed':True,
                  'ledger_before': {'ledger_id':'ledger','model':'kimi-k2.6','counts':{'uncertain':6}},
                  'ledger_after': {'ledger_id':'ledger','model':'kimi-k2.6','halted':'','counts':{'uncertain':6}}})
            write(Path(values['--evidence']), {
                'world_id': WORLD, 'evidence': [],
                'source_revision': {'life_seq': changed['life']['seq'],
                                    'world_elapsed_seconds': changed.get('elapsed_seconds', 3076.75)}})
            return {'exit_code': 1, 'timed_out': False,
                    'owned': {'all_members_exited': True, 'active': 0}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head':'head','files':{}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=bad_run):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 1)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['reason'], 'new_life_model_error')
        self.assertEqual(json.loads((self.root/'status.json').read_text())['status'], 'stopped')

    def test_gm_cycle_cannot_mutate_post_life_canonical_world(self):
        write(self.scope, self.base_scope)
        ordinary = self.fake_run
        def mutate_during_gm(command, cwd, timeout, log, env=None):
            result = ordinary(command, cwd, timeout, log, env)
            if command[0] != 'life':
                changed = json.loads(self.world.read_text())
                changed['life']['seq'] += 99
                write(self.world, changed)
            return result
        fixed = {'head': 'head', 'files': {'a': '1'}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value=fixed), \
             mock.patch.object(bridge, 'run_owned', side_effect=mutate_during_gm):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 1)
        result = json.loads((self.out/'run.json').read_text())
        self.assertEqual(result['reason'], 'canonical_world_changed_during_gm_cycle')

    def test_real_retained_state_schema_counts_sessions(self):
        write(self.scope, self.base_scope)
        state = {'world_id': WORLD, 'sessions': {f'gm-{i:02d}': {} for i in range(1, 11)}}
        with mock.patch.object(bridge.subprocess, 'check_output', return_value='head\n'), \
             mock.patch.object(bridge.gm_runner, 'load_state', return_value=state), \
             mock.patch.object(bridge.gm_runner, 'global_unknown_gms', return_value=[]):
            self.assertEqual(bridge.validate(self.base_scope), [])

    def test_outer_deadline_refuses_before_starting_a_partially_budgeted_cycle(self):
        scope = dict(self.base_scope); scope['max_seconds'] = 10
        write(self.scope, scope)
        called=[]; fixed={'head':'head','files':{}}
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value=fixed), \
             mock.patch.object(bridge, 'run_owned', side_effect=lambda *a,**k: called.append(a)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), 0)
        self.assertFalse(called)
        self.assertEqual(json.loads((self.out/'run.json').read_text())['reason'], 'time_limit')


class JourneyHostContractTests(unittest.TestCase):
    def test_actual_town_copy_contract_binds_real_projection_without_gateway(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); checkout = root/'checkout'; checkout.mkdir()
            target = checkout/'game/spatial/town_street.gd'; target.parent.mkdir(parents=True); target.write_text('release')
            save_copy = root/'world-copy.json'; original = world(); write(save_copy, original)
            evidence = root/'producer.json'
            write(evidence, {'world_id': WORLD, 'source_revision': 142, 'evidence': [{
                'issue_id': 'journey_stall:19', 'status': 'open', 'resident_id': 'shared:carpenter',
                'physical_facts': {'remaining_distance': 12.0}}]})
            out = root/'contract.json'
            def fake_run(command, cwd, timeout, log, env=None):
                updated = world(143); updated['life']['events'].append({'event_id': 'progress'})
                write(save_copy, updated)
                export_token = next(x for x in command if x.startswith('--town-gm-export='))
                export = Path(export_token.split('=', 1)[1])
                write(export, {'world_id': WORLD, 'source_revision': 143, 'evidence': [{
                    'issue_id': 'journey_stall:19', 'status': 'open',
                    'physical_facts': {'remaining_distance': 5.0}}]})
                return {'exit_code': 0, 'timed_out': False,
                        'owned': {'all_members_exited': True, 'active': 0}}
            argv = ['--save',str(save_copy),'--out',str(out),'--release','digest',
                    '--issue','issue-1','--identity','journey_stall:19',
                    '--target','game/spatial/town_street.gd','--target-sha',bridge.sha(target),
                    '--evidence',str(evidence),'--phase','open','--godot','godot',
                    '--checkout',str(checkout),'--source-world-sha',bridge.sha(save_copy)]
            with mock.patch.object(bridge, 'run_owned', side_effect=fake_run):
                self.assertEqual(bridge.verify_journey_stall(argv), 0)
            result = json.loads(out.read_text())
            self.assertTrue(all(result['causal_checks'].values()))
            self.assertFalse(result['resident_adoption'])


    def _journey_case(self, projection_writer, save_after=None):
        root = Path(tempfile.mkdtemp()); checkout = root/'checkout'; checkout.mkdir()
        target = checkout/'game/spatial/town_street.gd'; target.parent.mkdir(parents=True); target.write_text('release')
        save_copy = root/'world-copy.json'; write(save_copy, world())
        evidence = root/'producer.json'
        write(evidence, {'world_id': WORLD, 'source_revision': 142, 'evidence': [{
            'issue_id': 'journey_stall:19', 'status': 'open',
            'physical_facts': {'remaining_distance': 12.0}}]})
        out = root/'contract.json'
        def fake_run(command, cwd, timeout, log, env=None):
            if save_after is not None:
                write(save_copy, save_after)
            export_token = next(x for x in command if x.startswith('--town-gm-export='))
            projection_writer(Path(export_token.split('=', 1)[1]))
            return {'exit_code': 0, 'timed_out': False,
                    'owned': {'all_members_exited': True, 'active': 0}}
        argv = ['--save', str(save_copy), '--out', str(out), '--release', 'digest',
                '--issue', 'issue-1', '--identity', 'journey_stall:19',
                '--target', 'game/spatial/town_street.gd', '--target-sha', bridge.sha(target),
                '--evidence', str(evidence), '--phase', 'open', '--godot', 'godot',
                '--checkout', str(checkout), '--source-world-sha', bridge.sha(save_copy)]
        with mock.patch.object(bridge, 'run_owned', side_effect=fake_run):
            code = bridge.verify_journey_stall(argv)
        return code, json.loads(out.read_text())

    def test_missing_export_is_not_read_as_a_resolved_journey_stall(self):
        code, result = self._journey_case(lambda export: None)
        self.assertEqual(code, 1, "a missing public projection must not certify resolution")
        self.assertFalse(result['causal_checks']['public_projection_present_and_readable'])
        self.assertFalse(result['causal_checks']['bound_journey_progressed_or_closed'])
        self.assertFalse(result['ok'])
        self.assertFalse(result['observed_facts']['declared_source_matches_loaded_copy'] is None)

    def test_empty_projection_evidence_is_not_read_as_resolution(self):
        def empty(export):
            write(export, {'world_id': WORLD, 'source_revision': 143})
        code, result = self._journey_case(empty)
        self.assertEqual(code, 1)
        self.assertFalse(result['causal_checks']['public_projection_present_and_readable'])
        self.assertFalse(result['ok'])

    def test_wrong_world_projection_cannot_close_the_issue(self):
        def other_world(export):
            write(export, {'world_id': 'shared:some-other-town', 'source_revision': 143, 'evidence': []})
        code, result = self._journey_case(other_world)
        self.assertEqual(code, 1)
        self.assertFalse(result['causal_checks']['public_projection_present_and_readable'])
        self.assertFalse(result['ok'])

    def test_legitimate_closure_still_certifies_when_the_projection_was_read(self):
        def closed(export):
            write(export, {'world_id': WORLD, 'source_revision': 143, 'evidence': []})
        updated = world(143); updated['life']['events'].append({'event_id': 'progress'})
        code, result = self._journey_case(closed, save_after=updated)
        self.assertEqual(code, 0, "a genuinely read projection with the issue closed is a real resolution")
        self.assertTrue(all(result['causal_checks'].values()))
        self.assertTrue(result['ok'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
