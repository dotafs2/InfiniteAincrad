"""Focused checks for the labelled local-trial preparation helper and its mode labels."""
import json
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gm_autonomy  # noqa: E402
import gm_runner  # noqa: E402
import prepare_gm_autonomy_local as helper  # noqa: E402
import validate_gm_autonomy as va  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = ROOT / 'tmp' / 'gm-autonomy-20260913' / 'helper-tests'


def scratch_label(suffix):
    SCRATCH.mkdir(parents=True, exist_ok=True)
    return 'local-trial-' + suffix


def slashed(value):
    return str(value).replace('\\', '/')


def seed_local_trial(label, ledger_kind='carried_accounting_reference_ledger'):
    """Seed a complete local_trial fixture (all required inputs present) for reuse tests."""
    paths = helper.paths_for(helper.fixture_root(label))
    paths['root'].mkdir(parents=True, exist_ok=True)
    paths['runtime'].mkdir(parents=True, exist_ok=True)
    paths['state'].mkdir(parents=True, exist_ok=True)
    paths['deployment'].mkdir(parents=True, exist_ok=True)
    paths['save'].write_bytes(b'{"world_id": "fixture:well-street"}\n')
    gm_runner.save_json(paths['evidence'], {'kind': 'seeded_evidence'})
    gm_runner.save_json(paths['ledger'], {'schema_version': 1, 'kind': ledger_kind, 'calls': []})
    gm_runner.save_json(paths['deployment'] / 'deployment-base.json', {'files': {}})
    (paths['root'] / 'godot.exe').write_text('', encoding='utf-8')
    gm_runner.save_json(paths['policy'], {
        'schema_version': 1, 'policy_id': 'p-' + label, 'mode': 'local_trial',
        'limits': {'max_gms': 10},
        'paths': {'evidence': gm_runner.relative(paths['evidence']),
                  'state_dir': gm_runner.relative(paths['state']),
                  'prior_ledger': gm_runner.relative(paths['ledger'])},
        'deployment': {'checkout': gm_runner.relative(paths['deployment']),
                       'base_manifest': gm_runner.relative(
                           paths['deployment'] / 'deployment-base.json')},
        'runtime': {'godot': gm_runner.relative(paths['root'] / 'godot.exe'),
                    'save_path': gm_runner.relative(paths['save'])}})
    return paths


class RouteAndCommandTests(unittest.TestCase):
    def test_route_document_is_nonsecret_and_names_the_existing_key_file(self):
        route = helper.route_document()
        self.assertEqual(route['model'], 'deepseek-flash')
        self.assertEqual(route['base_url'], 'https://api.deepseek.com')
        self.assertTrue(slashed(route['key_file']).endswith(
            'C:/InfiniteAincrad/private/deepseek-api-key.txt'), route['key_file'])
        self.assertNotIn('sk-', json.dumps(route), 'the route file must never carry a key value')

    def test_commands_use_absolute_paths_and_the_private_key_reference(self):
        paths = helper.paths_for(Path('tmp/x'))
        commands = helper.commands_for(paths)
        self.assertEqual(set(commands), {'status', 'preflight', 'cycle', 'watch'})
        preflight = commands['preflight']
        self.assertIn('--dry-run', preflight)
        key = preflight[preflight.index('--key-file') + 1]
        self.assertTrue(Path(key).is_absolute())
        self.assertTrue(slashed(key).endswith('private/deepseek-api-key.txt'))
        self.assertNotIn('secrets/deepseek-key.txt', ' '.join(preflight))
        watch = commands['watch']
        self.assertIn('--max-calls', watch, 'the watch entry point stays bounded')


class RefusalAndIdempotenceTests(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        self.original = helper.LABEL_ROOT
        helper.LABEL_ROOT = SCRATCH
        self.addCleanup(lambda: setattr(helper, 'LABEL_ROOT', self.original))
        self.label = scratch_label(self._testMethodName.replace('_', '-'))
        self.addCleanup(shutil.rmtree, SCRATCH / self.label, True)

    def _seed_fixture_files(self, label):
        return seed_local_trial(label)

    def test_an_existing_save_is_refused_and_left_unchanged(self):
        paths = self._seed_fixture_files(self.label)
        before = paths['save'].read_bytes()
        code, result = helper.prepare(self.label, run_preflight=False)
        self.assertEqual(code, 3)
        self.assertEqual(result['status'], 'refused_existing_save')
        self.assertEqual(paths['save'].read_bytes(), before, 'the save bytes are untouched')
        self.assertFalse(paths['marker'].exists())

    def test_a_second_preparation_reuses_the_fixture_byte_for_byte(self):
        paths = self._seed_fixture_files(self.label)
        gm_runner.save_json(paths['marker'], {'schema_version': 1,
                                              'created_utc': '2026-09-13T00:00:00+00:00'})
        save_before = paths['save'].read_bytes()
        policy_before = paths['policy'].read_bytes()
        code, result = helper.prepare(self.label, run_preflight=False)
        self.assertEqual(code, 0)
        self.assertEqual(result['status'], 'already_prepared')
        self.assertEqual(paths['save'].read_bytes(), save_before)
        self.assertEqual(paths['policy'].read_bytes(), policy_before)
        self.assertTrue(result['save_sha256'])

    def test_a_marker_without_its_save_is_refused_not_repaired(self):
        paths = helper.paths_for(helper.fixture_root(self.label))
        paths['root'].mkdir(parents=True, exist_ok=True)
        gm_runner.save_json(paths['marker'], {'schema_version': 1})
        code, result = helper.prepare(self.label, run_preflight=False)
        self.assertEqual(code, 3)
        self.assertEqual(result['status'], 'refused_marker_without_save')

    def test_a_label_outside_the_local_trial_prefix_is_refused(self):
        self.assertEqual(helper.main(['--label', 'happy']), 2)


class ModeProvenanceTests(unittest.TestCase):
    def test_local_trial_is_an_accepted_mode_and_unknown_modes_are_still_refused(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        path = SCRATCH / 'modes-policy.json'
        self.addCleanup(lambda: path.unlink(missing_ok=True))
        base = {'schema_version': 1, 'policy_id': 'p1', 'world_id': 'fixture:well-street',
                'objective': 'One bounded evidence-backed repair for the trial well.'}
        for mode in ('offline_fixture', 'local_trial', 'production'):
            gm_runner.save_json(path, dict(base, mode=mode))
            self.assertEqual(gm_runner.read_autonomy_policy(path)['mode'], mode)
        gm_runner.save_json(path, dict(base, mode='scripted_fake'))
        with self.assertRaises(ValueError):
            gm_runner.read_autonomy_policy(path)

    def test_every_mode_has_a_truthful_provenance_note(self):
        self.assertEqual(set(gm_autonomy.PROVENANCE_NOTES), set(gm_runner.AUTONOMY_MODES))
        self.assertIn('scripted fakes', gm_autonomy.PROVENANCE_NOTES['offline_fixture'])
        trial = gm_autonomy.PROVENANCE_NOTES['local_trial']
        self.assertIn('real provider route', trial)
        self.assertIn('fresh fixture genesis', trial)
        self.assertNotIn('scripted fake', trial)

    def test_production_still_refuses_missing_canonical_inputs(self):
        missing = gm_autonomy.missing_requirements({
            'mode': 'production', 'paths': {'evidence': 'tmp/does-not-exist.json'},
            'deployment': {}, 'runtime': {}}, 'production')
        self.assertTrue(missing, 'production must refuse missing canonical inputs')
        self.assertTrue(any('state_dir' in item for item in missing), missing)


class PresetAndProvisioningTests(unittest.TestCase):
    def test_watch_preset_budgets_the_initial_batch_plus_coding_and_a_continuation(self):
        paths = helper.paths_for(Path('tmp/x'))
        watch = helper.commands_for(paths)['watch']
        preset = {watch[i]: watch[i + 1] for i, token in enumerate(watch)
                  if token.startswith('--') and i + 1 < len(watch)}
        self.assertEqual(preset['--max-calls'], '32')
        self.assertEqual(preset['--max-iterations'], '4')
        self.assertEqual(preset['--max-seconds'], '900')
        initial_observe_batch = 10   # one native GM turn per identity, ten identities
        needed = initial_observe_batch + 10 + 10 + 1   # turns: initial + coding + feedback + queued
        self.assertGreaterEqual(int(preset['--max-calls']), needed,
                                'max-calls counts native GM turns (not HTTP requests) and must '
                                'cover the initial batch plus coding/feedback and a continuation')

    def test_local_trial_provisioning_has_no_fake_artifacts_and_a_carried_ledger(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        label = scratch_label(self._testMethodName.replace('_', '-'))
        root = SCRATCH / label
        self.addCleanup(shutil.rmtree, root, True)
        paths = va.provision(label, 'no_action', mode='local_trial', root_dir=SCRATCH,
                             unique=False, record_latest=False)
        self.assertEqual(paths['root'], root)
        self.assertFalse((root / 'fake_codex.py').exists(), 'no fake transport for local_trial')
        self.assertFalse((root / 'deepseek-key.txt').exists(), 'no fake key for local_trial')
        ledger = gm_runner.load_json(paths['ledger'])
        self.assertEqual(ledger['kind'], 'carried_accounting_reference_ledger')
        self.assertNotIn('fixture_prior_ledger', json.dumps(ledger))
        self.assertEqual(ledger['interrupted_unknown_tail']['status'], 'unknown')
        self.assertTrue(ledger['measured_history_references'])
        for reference in ledger['measured_history_references']:
            self.assertTrue(reference['present'], reference)
            self.assertTrue((ROOT / reference['path']).is_file(), reference)
        policy = gm_runner.load_json(paths['policy'])
        self.assertEqual(policy['limits']['max_gms'], 10, 'ten planned GM identities')
        preflight = helper.commands_for(paths)['preflight']
        self.assertEqual(preflight[preflight.index('--prior-ledger') + 1], str(paths['ledger']),
                         'the exact generated command points at the non-fake ledger')


class LabelSafetyTests(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        self.original = helper.LABEL_ROOT
        helper.LABEL_ROOT = SCRATCH
        self.addCleanup(lambda: setattr(helper, 'LABEL_ROOT', self.original))
        self.outside = SCRATCH.parent / 'escaped-trial-outside'
        self.addCleanup(shutil.rmtree, self.outside, True)

    def test_traversal_separator_and_invalid_labels_are_refused_without_writes(self):
        before = sorted(p.name for p in SCRATCH.iterdir())
        for label in ('local-trial/../escaped-trial-outside', 'local-trial-..-x',
                      '..\\local-trial-x', 'local-trial-x/y', 'local-trial x',
                      'local-trial.', '../local-trial-x', 'local-trial-\u202e', ''):
            code, result = helper.prepare(label, run_preflight=False)
            self.assertEqual(code, 2, (label, result))
            self.assertEqual(result['status'], 'refused_label', (label, result))
        self.assertEqual(sorted(p.name for p in SCRATCH.iterdir()), before,
                         'a refused label must not create a fixture directory')
        self.assertFalse(self.outside.exists(), 'a refused label must not escape the root')

    def test_existing_valid_labels_still_resolve_inside_the_root(self):
        for label in ('local-trial', 'local-trial-1', 'local-trial-h47-r2-20260913'):
            root, error = helper.resolve_fixture_root(label)
            self.assertIsNone(error, (label, error))
            self.assertEqual(root.parent, SCRATCH.resolve(), label)
            self.assertEqual(root.name, label)


class PreflightReuseTests(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        self.original_label_root = helper.LABEL_ROOT
        helper.LABEL_ROOT = SCRATCH
        self.addCleanup(lambda: setattr(helper, 'LABEL_ROOT', self.original_label_root))
        self.original_preflight = helper.run_route_preflight
        self.addCleanup(lambda: setattr(helper, 'run_route_preflight', self.original_preflight))
        self.label = scratch_label(self._testMethodName.replace('_', '-'))
        self.addCleanup(shutil.rmtree, SCRATCH / self.label, True)

    def _stub_preflight(self, code, checks):
        helper.run_route_preflight = lambda paths, policy: (code, checks)

    def test_reuse_reruns_preflight_and_propagates_failure(self):
        paths = seed_local_trial(self.label)
        gm_runner.save_json(paths['marker'], {'schema_version': 1})
        save_before = paths['save'].read_bytes()
        marker_before = paths['marker'].read_bytes()
        self._stub_preflight(2, {'ok': False})
        code, result = helper.prepare(self.label, run_preflight=True)
        self.assertEqual(code, 2)
        self.assertEqual(result['status'], 'already_prepared_preflight_failed')
        self.assertFalse(result['preflight']['ok'], 'the fresh preflight failure is propagated')
        self.assertEqual(paths['save'].read_bytes(), save_before)
        self.assertEqual(paths['marker'].read_bytes(), marker_before)

    def test_reuse_reports_already_prepared_with_a_fresh_successful_preflight(self):
        paths = seed_local_trial(self.label)
        gm_runner.save_json(paths['marker'], {'schema_version': 1})
        save_before = paths['save'].read_bytes()
        self._stub_preflight(0, {'ok': True})
        code, result = helper.prepare(self.label, run_preflight=True)
        self.assertEqual(code, 0)
        self.assertEqual(result['status'], 'already_prepared')
        self.assertTrue(result['preflight']['ok'])
        self.assertEqual(paths['save'].read_bytes(), save_before)

    def test_missing_required_input_is_refused_not_reported_prepared(self):
        paths = helper.paths_for(helper.fixture_root(self.label))
        paths['root'].mkdir(parents=True, exist_ok=True)
        (paths['root'] / 'runtime').mkdir(parents=True, exist_ok=True)
        paths['save'].write_bytes(b'{}\n')
        gm_runner.save_json(paths['policy'], {'schema_version': 1, 'mode': 'local_trial',
                                              'paths': {'evidence': 'tmp/does-not-exist.json'},
                                              'deployment': {}, 'runtime': {}})
        gm_runner.save_json(paths['marker'], {'schema_version': 1})
        code, result = helper.prepare(self.label, run_preflight=False)
        self.assertEqual(code, 4)
        self.assertEqual(result['status'], 'refused_missing_requirements')
        self.assertTrue(result['required_paths_missing'])

    def test_fake_prior_ledger_is_rejected_in_real_local_mode(self):
        paths = seed_local_trial(self.label, ledger_kind='fixture_prior_ledger')
        gm_runner.save_json(paths['marker'], {'schema_version': 1})
        save_before = paths['save'].read_bytes()
        code, result = helper.prepare(self.label, run_preflight=False)
        self.assertEqual(code, 4)
        self.assertEqual(result['status'], 'refused_fake_prior_ledger')
        self.assertEqual(result['prior_ledger_kind'], 'fixture_prior_ledger')
        self.assertEqual(paths['save'].read_bytes(), save_before)


if __name__ == '__main__':
    unittest.main()
