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
        # A real bounded deployment: one manifest-declared file inside the checkout, so the
        # bridge's deployment content digest is exercised for real instead of through a mock.
        self.manifest = self.root / 'base-manifest.json'
        self.deployed_file = self.deploy / 'game/spatial/town_street.gd'
        self.deployed_file.parent.mkdir(parents=True, exist_ok=True)
        self.deployed_file.write_text('release-bytes', encoding='utf-8')
        write(self.manifest, {'files': {'game/spatial/town_street.gd':
                                        bridge.sha(self.deployed_file)}})
        write(self.policy, {'paths': {}, 'runtime': {},
                            'deployment': {'base_manifest': str(self.manifest), 'path_map': {}},
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


class SettledLocalGmFailureTests(unittest.TestCase):
    """One already-reported, never-published candidate failure may settle locally. Every other
    blocked/nonzero autonomy outcome must keep the global stop it had before."""

    # The bridge fixture is shared, but inheriting the parent test cases would replay them here.
    setUp = ProductionBridgeTests.setUp
    tearDown = ProductionBridgeTests.tearDown

    def _blocked_candidate_report(self, **overrides):
        report = {'status': 'blocked', 'cycle_id': 'blocked-candidate-cycle',
                  'mode': 'production',
                  'blocked_reason': 'host_gate_refused_candidate', 'next_stage': 'validate',
                  'policy': {'world_id': WORLD},
                  'stage_status': {'observe': 'done', 'candidate': 'done', 'validate': 'failed',
                                   'publish': 'pending', 'verify': 'pending', 'feedback': 'done'},
                  'what_changed': [], 'release_digest': None, 'installed': False, 'used': False,
                  'independently_tested': {'host_gate_ok': False,
                                           'failed_checks': ['host_test_commands_pass'],
                                           'runtime_checks': {}},
                  'gm': {'gm_id': 'gm-01', 'issue_id': 'issue-7',
                         'observation_origin': 'public_export'},
                  'deferred_claims': [], 'declined': [],
                  'usage': {'model_calls': 4, 'unknown': None},
                  'owned_processes': {'windows_job': True, 'all_observed_members_exited': True,
                                      'members': [{'stage': 'observe', 'pid': 4321,
                                                   'exit_code': 0}]}}
        report.update(overrides)
        return report

    def _host_test_run(self, **overrides):
        # The real gm_autonomy validate detail shape: one entry per required host test command,
        # carrying the owned-tree snapshot of the command that actually ran.
        run = {'command': ['py', '-3.12', '-m', 'unittest', 'tools.test_target'],
               'exit_code': 1, 'timed_out': False, 'seconds': 1.5,
               'owned': {'containment': 'windows_kill_on_close_job', 'wrapper_pid': 4321,
                         'observed_members': [{'pid': 4322, 'running': False, 'exit_code': 1,
                                               'creation_time_windows_100ns': 638000000000000000}],
                         'total_assigned_processes': 1, 'active_processes': 0,
                         'member_identity_list_complete': True, 'all_members_exited': True},
               'stdout_tail': 'FAILED (failures=1)', 'stderr_tail': ''}
        run.update(overrides)
        return run

    def _retain_cycle(self, report, decision='no_action', suffix='', receipt_digest=None,
                      acknowledge_gm=None, measured=True, observe_calls=2, host_test_run=None,
                      host_test_runs=None, deferred_claims=()):
        directory = self.state / 'autonomy' / ('auto-blockedcandidate' + suffix)
        gm_id, issue_id = report['gm']['gm_id'], report['gm']['issue_id']
        if host_test_runs is None:
            host_test_runs = [host_test_run]
        runs = [self._host_test_run() if item is None else item for item in host_test_runs]
        checks = [{'check': 'candidate_head_is_base', 'ok': True, 'detail': 'base-revision'},
                  {'check': 'candidate_changes_within_scope', 'ok': True,
                   'detail': {'observed': [], 'out_of_scope': []}},
                  {'check': 'host_owned_paths_unchanged', 'ok': True, 'detail': {}},
                  {'check': 'scope_files_exist', 'ok': True,
                   'detail': {'game/spatial/town_street.gd': 'sha'}},
                  {'check': 'host_test_commands_pass', 'ok': False}]
        commands = []
        if all(item is not False for item in runs):
            checks[-1]['detail'] = runs
            commands = [item['command'] for item in runs]
        receipt = {'kind': 'autonomy_release_receipt', 'cycle_id': report['cycle_id'],
                   'issue_id': issue_id, 'world_id': WORLD, 'gm_id': gm_id,
                   'release_digest': None, 'outcome': 'validate_failed', 'published': False,
                   'runtime_verification': {'installed': None, 'used': None,
                                            'installed_but_unused': None, 'observation': None},
                   'host_gate_failed_checks': ['host_test_commands_pass'],
                   'failure': {'stage': 'validate', 'status': 'failed',
                               'blocked_reason': report['blocked_reason'],
                               'failed_checks': ['host_test_commands_pass']}}
        receipt_path = directory / 'feedback-1.json'
        write(receipt_path, receipt)
        recorded_digest = receipt_digest or bridge.sha(receipt_path)
        attempts = [{'attempt': 1, 'exit_code': 0, 'status': 'ok', 'acknowledged': True,
                     'decision': decision, 'next_work': 'none', 'usage_measured': True,
                     'receipt_sha256': recorded_digest, 'owned': {'all_members_exited': True}}]
        usage = report.setdefault('usage', {})
        usage['attempts'] = {issue_id: 1}
        usage['feedback_attempts'] = attempts
        report['deferred_claims'] = list(deferred_claims)
        report['report_path'] = str(directory / 'report.json')
        write(directory / 'report.json', report)
        write(directory / 'cycle.json', {
            'schema_version': 1, 'cycle_id': report['cycle_id'], 'mode': 'production',
            'world_id': WORLD, 'status': 'blocked', 'gm_id': gm_id, 'issue_id': issue_id,
            'blocked_reason': report['blocked_reason'], 'unknown': None, 'repair_blocked': None,
            'deferred_claims': list(deferred_claims), 'declined': [], 'release': None,
            'model_calls': usage.get('model_calls'), 'attempts': dict(usage['attempts']),
            'stages': {'observe': {'status': 'done', 'model_calls_observed': observe_calls},
                       'candidate': {'status': 'done', 'host_test_commands': commands,
                                     'attempts': [{'attempt': 1, 'status': 'ok', 'exit_code': 0,
                                                   'usage_measured': measured}]},
                       'validate': {'status': 'failed', 'ok': False, 'checks': checks},
                       'publish': {'status': 'pending'}, 'verify': {'status': 'pending'},
                       'feedback': {'status': 'done', 'receipt_sha256': recorded_digest,
                                    'attempts': attempts,
                                    'acknowledgement': {'acknowledged': True,
                                                        'gm_id': acknowledge_gm or gm_id,
                                                        'decision': decision,
                                                        'next_work': 'none'},
                                    'receipt': receipt}}})
        return report

    def _gm_cycle_run(self, reports, exit_code=1, gm_mutate=None, owned_exited=True):
        queue = list(reports) if isinstance(reports, list) else [reports]
        def run(command, cwd, timeout, log, env=None):
            if command[0] != 'life':
                report = queue.pop(0) if len(queue) > 1 else queue[0]
                if gm_mutate is not None:
                    gm_mutate()
                Path(log).parent.mkdir(parents=True, exist_ok=True)
                Path(log).write_text('diagnostic\n' + json.dumps(report) + '\n', encoding='utf-8')
                return {'exit_code': exit_code, 'timed_out': False,
                        'owned': {'all_members_exited': owned_exited, 'active': 0}}
            values = dict(token.split('=', 1) for token in command[1:])
            current = json.loads(self.world.read_text())
            current['life']['seq'] += 1
            write(self.world, current)
            out = Path(values['--out'])
            write(out / 'result.json', {
                'engine_exit': 0, 'validation_passed': False, 'model_errors': {},
                'upstream_requests': 1, 'budget_stop_reason': '',
                'carried_uncertainty_reviewed': True,
                'ledger_before': {'ledger_id': 'ledger', 'model': 'kimi-k2.6',
                                  'counts': {'settled': 1139, 'uncertain': 6}},
                'ledger_after': {'ledger_id': 'ledger', 'model': 'kimi-k2.6', 'halted': '',
                                 'counts': {'settled': 1140, 'uncertain': 6}}})
            write(Path(values['--evidence']), {
                'world_id': WORLD, 'evidence': [],
                'source_revision': {'life_seq': current['life']['seq'],
                                    'world_elapsed_seconds': current.get('elapsed_seconds', 3076.75)}})
            return {'exit_code': 0, 'timed_out': False,
                    'owned': {'all_members_exited': True, 'active': 0}}
        return run

    def _run_bridge(self, scope_overrides, report, expect, **run_kwargs):
        scope = dict(self.base_scope)
        scope.update(scope_overrides)
        write(self.scope, scope)
        with mock.patch.object(bridge, 'validate', return_value=[]), \
             mock.patch.object(bridge, 'tracked', return_value={'head': 'head', 'files': {'a': '1'}}), \
             mock.patch.object(bridge, 'run_owned', side_effect=self._gm_cycle_run(report,
                                                                                  **run_kwargs)):
            self.assertEqual(bridge.main(['--scope', str(self.scope)]), expect)
        return json.loads((Path(scope['out_root']) / 'run.json').read_text())

    def test_settled_local_candidate_failure_continues_to_the_next_life_stage(self):
        first_report = self._retain_cycle(
            self._blocked_candidate_report(cycle_id='blocked-candidate-1'), suffix='one')
        second_report = self._retain_cycle(
            self._blocked_candidate_report(cycle_id='blocked-candidate-2'), suffix='two')
        result = self._run_bridge({'max_cycles': 2}, [first_report, second_report], 0)
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual(len(result['cycles']), 2, 'the next canonical life stage still runs')
        first = result['cycles'][0]
        self.assertEqual(first['status'], 'closed')
        self.assertEqual(first['resident_adoption'], 'no_release')
        self.assertTrue(first['gm_usage_counted'])
        receipt = first['gm_local_failures'][0]
        self.assertEqual(receipt['classification'],
                         'settled_local_candidate_failure_unpublished')
        self.assertEqual(receipt['cycle_id'], 'blocked-candidate-1')
        self.assertEqual(receipt['author_decision'], 'no_action')
        self.assertEqual(receipt['accounted_model_calls'], 4)
        self.assertEqual(receipt['deployment_files'], ['game/spatial/town_street.gd'])
        self.assertTrue(receipt['deployment_matches_pinned_base'])
        self.assertEqual(receipt['failed_validate_checks'], ['host_test_commands_pass'])
        self.assertEqual(receipt['blocked_reason'], 'host_gate_refused_candidate')
        self.assertFalse(receipt['published'])
        self.assertEqual(receipt['model_calls'], 4)
        self.assertEqual(result['gm_local_failures_total'], 2,
                         'each canonical life stage reports its own settled local failure')
        self.assertEqual(result['gm_local_failure_classes'],
                         ['settled_local_candidate_failure_unpublished'])
        self.assertEqual(result['cycles'][1]['gm_local_failures'][0]['cycle_id'],
                         'blocked-candidate-2')
        self.assertEqual(result['gm_model_calls'], 8, 'each distinct cycle is charged once')
        self.assertEqual([c['gm_usage_counted'] for c in result['cycles']], [True, True])
        self.assertEqual(result['kimi_requests'], 2)

    def test_candidate_failure_usage_contributes_to_the_total_gm_cap(self):
        report = self._retain_cycle(self._blocked_candidate_report(
            usage={'model_calls': 6, 'unknown': None}), observe_calls=4)
        result = self._run_bridge({'max_cycles': 3, 'max_gm_model_calls': 6}, report, 0)
        self.assertEqual(result['reason'], 'lifetime_model_call_limit')
        self.assertEqual(result['gm_model_calls'], 6)
        self.assertEqual(len(result['cycles']), 1, 'the spent cap stops the next life stage')
        self.assertEqual(result['cycles'][0]['status'], 'closed')

    def test_known_calls_are_charged_and_the_unknown_tail_is_marked_without_settling(self):
        report = self._retain_cycle(self._blocked_candidate_report(
            usage={'model_calls': 4,
                   'unknown': {'stage': 'code', 'reserved': {'model_calls_reserved': 1}}}))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_usage_unknown')
        self.assertNotIn('gm_local_failures', result['cycles'][0])
        self.assertEqual(result['gm_model_calls'], 4,
                         'the known part of the quota count stays in the cumulative scope')
        self.assertEqual(result['cycles'][0]['gm_quota_calls_charged'], 4)
        self.assertEqual(result['gm_unknown_usage'],
                         {'cycle_id': 'blocked-candidate-cycle', 'quota_calls_charged': 4,
                          'counts_including_unresolved_reservations': 4,
                          'usage_unknown': {'stage': 'code',
                                            'reserved': {'model_calls_reserved': 1}}})
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_unmeasured_cycle_total_is_never_read_as_zero(self):
        report = self._retain_cycle(self._blocked_candidate_report(usage={'unknown': None}))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_usage_unmeasured')
        self.assertEqual(result['gm_model_calls'], 0, 'nothing measurable is charged or invented')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_live_gm_descendants_stop_the_run(self):
        report = self._retain_cycle(self._blocked_candidate_report())
        result = self._run_bridge({'max_cycles': 2}, report, 1, owned_exited=False)
        self.assertEqual(result['reason'], 'autonomy_failed')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_report_level_live_descendant_stops_local_classification(self):
        report = self._retain_cycle(self._blocked_candidate_report(
            owned_processes={'windows_job': True, 'all_observed_members_exited': False,
                             'members': [{'stage': 'observe', 'pid': 99, 'exit_code': None}]}))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_world_conflict_stops_before_local_classification(self):
        report = self._retain_cycle(self._blocked_candidate_report())
        def mutate():
            changed = json.loads(self.world.read_text())
            changed['life']['seq'] += 99
            write(self.world, changed)
        result = self._run_bridge({'max_cycles': 2}, report, 1, gm_mutate=mutate)
        self.assertEqual(result['reason'], 'canonical_world_changed_during_gm_cycle')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_published_but_unverified_stays_global_even_with_unchanged_save_bytes(self):
        report = self._retain_cycle(self._blocked_candidate_report(
            stage_status={'observe': 'done', 'candidate': 'done', 'validate': 'failed',
                          'publish': 'done', 'verify': 'failed', 'feedback': 'done'},
            what_changed=['game/spatial/town_street.gd'], release_digest='digest-1',
            installed=True,
            independently_tested={'host_gate_ok': False,
                                  'failed_checks': ['host_test_commands_pass'],
                                  'runtime_checks': {'deployed_bytes_match_release': False}}))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])
        self.assertEqual(result['gm_model_calls'], 4, 'the published attempt is still charged')

    def test_repair_decision_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(self._blocked_candidate_report(), decision='repair')
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_escalate_decision_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(self._blocked_candidate_report(), decision='escalate')
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')

    def test_arbitrary_decision_string_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(self._blocked_candidate_report(),
                                    decision='definitely-not-a-decision')
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')

    def test_stale_receipt_digest_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(self._blocked_candidate_report(),
                                    receipt_digest='0' * 64)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_unmeasured_individual_attempt_hidden_by_the_summary_stops(self):
        report = self._retain_cycle(self._blocked_candidate_report(), measured=False)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_acknowledgement_from_another_gm_stops(self):
        report = self._retain_cycle(self._blocked_candidate_report(),
                                    acknowledge_gm='gm-99')
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')

    def test_summary_total_that_the_retained_attempts_cannot_account_for_stops(self):
        report = self._retain_cycle(self._blocked_candidate_report(
            usage={'model_calls': 9, 'unknown': None}), observe_calls=2)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')

    def test_changed_deployment_bytes_with_identical_status_stop_the_local_path(self):
        report = self._retain_cycle(self._blocked_candidate_report())
        def mutate():
            # Same path, same would-be porcelain entry, different bytes.
            self.deployed_file.write_text('release-bytes-tampered', encoding='utf-8')
        result = self._run_bridge({'max_cycles': 2}, report, 1, gm_mutate=mutate)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_missing_base_manifest_fails_closed_instead_of_claiming_the_parent_repo(self):
        report = self._retain_cycle(self._blocked_candidate_report())
        unverifiable = json.loads(self.policy.read_text())
        unverifiable['deployment'] = {'path_map': {}}
        write(self.policy, unverifiable)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])
        self.assertIsNone(bridge.deployment_content_digest(self.deploy, None),
                          'an absent manifest is None, never a parent-repo claim')

    def test_deployment_digest_reads_bytes_and_never_consults_version_control(self):
        before = bridge.deployment_content_digest(self.deploy, self.manifest)
        self.assertEqual(before['files'], {'game/spatial/town_street.gd':
                                           bridge.sha(self.deployed_file)})
        self.assertTrue(before['matches_pinned_base'])
        self.deployed_file.write_text('tampered', encoding='utf-8')
        after = bridge.deployment_content_digest(self.deploy, self.manifest)
        self.assertNotEqual(before['files'], after['files'],
                            'same path and same porcelain text, different bytes')
        self.assertFalse(after['matches_pinned_base'])
        with mock.patch.object(bridge.subprocess, 'check_output',
                               side_effect=AssertionError('git must never be consulted')):
            self.assertEqual(bridge.deployment_content_digest(self.deploy, self.manifest),
                             after)

    def test_missing_declared_deployment_file_fails_closed(self):
        self.deployed_file.unlink()
        self.assertIsNone(bridge.deployment_content_digest(self.deploy, self.manifest))

    def test_empty_supported_base_manifest_cannot_verify_the_deployment(self):
        # The supported validate_gm_autonomy harness pins the trial base as
        # {'schema_version': 1, 'files': {}} (validate_gm_autonomy.py:700), and every prepared
        # scenario under tmp/gm-autonomy-20260913 carries that same empty declaration. An empty
        # declaration pins no bounded deployment content, so the bridge must stop truthfully
        # instead of treating an empty file set as proof that the deployment is unchanged.
        write(self.manifest, {'schema_version': 1, 'files': {}})
        self.assertIsNone(bridge.deployment_content_digest(self.deploy, self.manifest))
        report = self._retain_cycle(self._blocked_candidate_report())
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_checkout_under_a_parent_repository_is_measured_by_content_only(self):
        # A checkout that is not itself a repository must never be measured by letting version
        # control discover an enclosing parent repository: only manifest-declared files inside
        # the checkout are read.
        outer = self.root / 'outer'
        (outer / '.git').mkdir(parents=True)
        checkout = outer / 'trial-deployment'
        target = checkout / 'game/spatial/town_street.gd'
        target.parent.mkdir(parents=True)
        target.write_text('parent-repo-bytes', encoding='utf-8')
        (checkout / 'unrelated.bin').write_bytes(b'not declared by the manifest')
        manifest = self.root / 'parent-repo-base.json'
        write(manifest, {'files': {'game/spatial/town_street.gd': bridge.sha(target)}})
        with mock.patch.object(bridge.subprocess, 'check_output',
                               side_effect=AssertionError('git must never be consulted')):
            digest = bridge.deployment_content_digest(checkout, manifest)
        self.assertEqual(digest['checkout'], str(checkout.resolve()))
        self.assertEqual(digest['files'], {'game/spatial/town_street.gd': bridge.sha(target)})
        self.assertTrue(digest['matches_pinned_base'])
        target.write_text('parent-repo-bytes-tampered', encoding='utf-8')
        with mock.patch.object(bridge.subprocess, 'check_output',
                               side_effect=AssertionError('git must never be consulted')):
            changed = bridge.deployment_content_digest(checkout, manifest)
        self.assertNotEqual(digest['files'], changed['files'],
                            'same path and same porcelain text, different bytes')
        self.assertFalse(changed['matches_pinned_base'])

    def test_repeated_cycle_id_is_charged_only_the_incremental_delta(self):
        first = self._retain_cycle(self._blocked_candidate_report(cycle_id='resumed-cycle'),
                                   suffix='one')
        resumed = self._retain_cycle(self._blocked_candidate_report(
            cycle_id='resumed-cycle', usage={'model_calls': 6, 'unknown': None}),
            suffix='two', observe_calls=4)
        result = self._run_bridge({'max_cycles': 2}, [first, resumed], 0)
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual([c['gm_quota_calls_charged'] for c in result['cycles']], [4, 2])
        self.assertEqual([c['gm_usage_counted'] for c in result['cycles']], [True, True])
        self.assertEqual(result['gm_model_calls'], 6, 'the cumulative total is charged once')
        self.assertEqual(result['counted_gm_cycle_calls'], {'resumed-cycle': 6})
        self.assertEqual(result['cycles'][0]['gm_local_failures'][0]['model_calls_basis'],
                         'gm_autonomy_quota_count_including_retained_reservations')

    def test_real_schema_directory_prefix_path_map_forms_still_settle_locally(self):
        # gm_autonomy.deployment_target maps concrete SOURCE paths through a directory PREFIX
        # map. Both real forms must leave the manifest-target digest usable; a digest that
        # hashed the prefix value would return None and never settle.
        for index, path_map in enumerate(({'game/': ''}, {'game/': 'game/'})):
            with self.subTest(path_map=path_map):
                policy = json.loads(self.policy.read_text())
                policy['deployment']['path_map'] = path_map
                write(self.policy, policy)
                self.assertIsNotNone(
                    bridge.deployment_content_digest(self.deploy, self.manifest))
                report = self._retain_cycle(
                    self._blocked_candidate_report(cycle_id='prefix-form-%d' % index),
                    suffix='prefix%d' % index)
                result = self._run_bridge(
                    {'max_cycles': 1, 'out_root': str(self.root / ('run-prefix-%d' % index))},
                    report, 0)
                first = result['cycles'][0]
                self.assertEqual(first['status'], 'closed')
                self.assertEqual(first['gm_local_failures'][0]['classification'],
                                 'settled_local_candidate_failure_unpublished')
                self.assertEqual(result['gm_local_failures_total'], 1)

    def test_timed_out_host_test_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(
            self._blocked_candidate_report(),
            host_test_run=self._host_test_run(exit_code=None, timed_out=True))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_live_host_test_descendant_is_not_a_settled_local_failure(self):
        owned = dict(self._host_test_run()['owned'])
        owned.update({'all_members_exited': False, 'active_processes': 1,
                      'observed_members': [{'pid': 4322, 'running': True, 'exit_code': None,
                                            'creation_time_windows_100ns': 1}]})
        report = self._retain_cycle(self._blocked_candidate_report(),
                                    host_test_run=self._host_test_run(owned=owned))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_absent_host_test_detail_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(self._blocked_candidate_report(), host_test_run=False)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_multiple_required_host_tests_settle_when_every_run_is_fully_observed(self):
        failing = self._host_test_run(command=['py', '-3.12', '-m', 'unittest', 'tools.test_a'])
        passing = self._host_test_run(
            command=['py', '-3.12', '-m', 'unittest', 'tools.test_b'], exit_code=0,
            owned={'containment': 'windows_kill_on_close_job', 'wrapper_pid': 4331,
                   'observed_members': [{'pid': 4332, 'running': False, 'exit_code': 0,
                                         'creation_time_windows_100ns': 638000000000000001}],
                   'total_assigned_processes': 1, 'active_processes': 0,
                   'member_identity_list_complete': True, 'all_members_exited': True})
        report = self._retain_cycle(self._blocked_candidate_report(cycle_id='two-command-cycle'),
                                    suffix='two-command', host_test_runs=[failing, passing])
        result = self._run_bridge({'max_cycles': 1}, report, 0)
        first = result['cycles'][0]
        self.assertEqual(first['status'], 'closed')
        self.assertEqual(first['gm_local_failures'][0]['classification'],
                         'settled_local_candidate_failure_unpublished')
        self.assertEqual(first['gm_local_failures'][0]['model_calls'], 4)

    def test_host_test_detail_shorter_than_the_required_commands_stops(self):
        report = self._retain_cycle(self._blocked_candidate_report())
        cycle_file = self.state / 'autonomy' / 'auto-blockedcandidate' / 'cycle.json'
        document = json.loads(cycle_file.read_text())
        document['stages']['candidate']['host_test_commands'].append(
            ['py', '-3.12', '-m', 'unittest', 'tools.test_second'])
        write(cycle_file, document)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_a_failed_host_gate_with_only_zero_exits_is_not_settled(self):
        report = self._retain_cycle(self._blocked_candidate_report(),
                                    host_test_run=self._host_test_run(exit_code=0))
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_a_second_failed_validate_check_is_not_a_settled_local_failure(self):
        report = self._retain_cycle(self._blocked_candidate_report())
        cycle_file = self.state / 'autonomy' / 'auto-blockedcandidate' / 'cycle.json'
        document = json.loads(cycle_file.read_text())
        document['stages']['validate']['checks'][3] = {
            'check': 'scope_files_exist', 'ok': False, 'detail': {}}
        write(cycle_file, document)
        result = self._run_bridge({'max_cycles': 2}, report, 1)
        self.assertEqual(result['reason'], 'autonomy_blocked_unresolved')
        self.assertNotIn('gm_local_failures', result['cycles'][0])

    def test_another_gm_deferred_claim_does_not_block_a_settled_local_failure(self):
        # The real deferred-claim shape gm_autonomy retains for another GM pending work.
        claim = {'gm_id': 'gm-02', 'issue_id': 'issue-9'}
        report = self._retain_cycle(self._blocked_candidate_report(), deferred_claims=[claim],
                                    suffix='claims')
        result = self._run_bridge({'max_cycles': 2}, report, 0)
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual(len(result['cycles']), 2, 'the next canonical life stage still runs')
        receipt = result['cycles'][0]['gm_local_failures'][0]
        self.assertEqual(receipt['other_gm_deferred_claims'], 1,
                         'another GM claims are pending work, not an integrity failure')
        retained = json.loads((self.state / 'autonomy' / 'auto-blockedcandidateclaims'
                               / 'cycle.json').read_text())
        self.assertEqual(retained['deferred_claims'], [claim],
                         'the claim is preserved, neither refused nor cleared')

    def test_shrinking_cycle_cumulative_stops_instead_of_crediting_calls_back(self):
        first = self._retain_cycle(self._blocked_candidate_report(
            cycle_id='shrinking-cycle', usage={'model_calls': 6, 'unknown': None}),
            suffix='one', observe_calls=4)
        shrunk = self._retain_cycle(self._blocked_candidate_report(cycle_id='shrinking-cycle'),
                                    suffix='two')
        result = self._run_bridge({'max_cycles': 2}, [first, shrunk], 1)
        self.assertEqual(result['reason'], 'autonomy_usage_regressed')
        self.assertEqual(result['gm_model_calls'], 6)

    def test_completed_release_path_still_closes_the_cycle(self):
        report = self._blocked_candidate_report(
            status='completed', blocked_reason=None, next_stage=None,
            independently_tested={'host_gate_ok': True, 'failed_checks': [],
                                  'runtime_checks': {'deployed_bytes_match_release': True}})
        result = self._run_bridge({'max_cycles': 1}, report, 0, exit_code=0)
        self.assertEqual(result['status'], 'completed_finite')
        self.assertEqual(result['cycles'][0]['status'], 'closed')
        self.assertEqual(result['cycles'][0]['resident_adoption'],
                         'pending_next_canonical_life')
        self.assertEqual(result['cycles'][0]['gm_usage_counted'], True)
        self.assertEqual(result['gm_model_calls'], 4)


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
