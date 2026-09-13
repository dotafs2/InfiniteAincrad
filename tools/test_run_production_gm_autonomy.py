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
            write(Path(values['--evidence']), {'world_id': WORLD, 'source_revision': current['life']['seq'],
                                               'evidence': []})
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

    def test_new_provider_error_fails_closed_with_nonzero_exit(self):
        scope = dict(self.base_scope)
        write(self.scope, scope)
        def bad_run(command, cwd, timeout, log, env=None):
            values = dict(token.split('=', 1) for token in command[1:])
            changed = world()
            changed['godot']['resident_turns']['shared:fisher'] = {
                'status': 'provider_error', 'request_id': 'turn:shared:fisher:2:16',
                'result': {'code': 'brain_response_invalid'}}
            write(self.world, changed)
            out = Path(values['--out'])
            write(out/'result.json', {'engine_exit': 0, 'validation_passed': False,
                  'model_errors': {'shared:fisher': 'provider_error'}, 'upstream_requests': 1,
                  'budget_stop_reason':'','carried_uncertainty_reviewed':True,
                  'ledger_before': {'ledger_id':'ledger','model':'kimi-k2.6','counts':{'uncertain':6}},
                  'ledger_after': {'ledger_id':'ledger','model':'kimi-k2.6','halted':'','counts':{'uncertain':6}}})
            write(Path(values['--evidence']), {'world_id': WORLD, 'evidence': []})
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
