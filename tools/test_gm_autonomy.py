#!/usr/bin/env python3
"""Offline unit and negative-gate tests for the opt-in autonomous GM cycle.

Nothing here calls a model. These tests pin the host-side refusals that must hold before any paid
work or publication: standing-policy validation, GM-proposed scope rejection, host-owned file
protection, deployment mapping, host-derived required commands, missing-input preflight, the
explicit observation origin and durable cycle identity. Scripted end-to-end plumbing (real Godot
runtime, restart, publication) lives in tools/validate_gm_autonomy.py.
"""
import json
import contextlib
import io
import os
import shutil
import subprocess
import sys
import unittest
from unittest import mock
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gm_autonomy  # noqa: E402
import gm_runner  # noqa: E402
import validate_gm_autonomy as validate  # noqa: E402

EXAMPLE = ROOT / 'tools' / 'gm_autonomy_policy.example.json'
ACCEPTED_EVIDENCE = ROOT / 'docs' / 'validation' / 'town_gm_evidence_2026-09-12' / 'evidence-final.json'
WORK = ROOT / 'tmp' / 'gm-autonomy-20260913' / 'unit'
WORLD = 'fixture:well-street'


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding='utf-8')
    return path


def example_policy():
    return json.loads(EXAMPLE.read_text(encoding='utf-8'))


def observe_guards(before_files=None, after_files=None, changed=None, git_head='f' * 40):
    """The real gm_runner.guard_snapshot pair: identical content, two different taken_utc stamps.

    The two snapshots are never byte-equal because each carries its own clock reading, so equality
    of the two dicts is never the right question - gm_runner.guard_diff over files/git_head/
    git_status_sha256 is, plus the record's own `changed` list.
    """
    before_files = ({'game/spatial/town_street.gd': 'a' * 64}
                    if before_files is None else before_files)
    after_files = dict(before_files) if after_files is None else after_files

    def snapshot(files, taken):
        return {'files': files, 'git_head': git_head, 'git_status_sha256': 'b' * 64,
                'taken_utc': taken}

    return {'before': snapshot(before_files, '2026-09-14T03:44:17.990815+00:00'),
            'after': snapshot(after_files, '2026-09-14T03:46:00.350046+00:00'),
            'changed': [] if changed is None else changed}


def observe_receipt_fixture(cycle, run_id='run-1', dispatched=10, **overrides):
    """The durable gm_observe run.json shape gm_runner writes, as an offline fixture."""
    results = [{'gm_id': 'gm-%02d' % (index + 1), 'status': 'ok', 'exit_code': 0,
                'usage_measured': True, 'cost': 'measured', 'dispatched': True,
                'usage': {'turns': 1}}
               for index in range(dispatched)]
    receipt = {'status': 'ok', 'kind': 'gm_observe', 'run_id': run_id,
               'run_dir': 'runs/' + run_id, 'route': {'kind': 'codex'}, 'world_binding': WORLD,
               'evidence': {'path': gm_runner.relative(cycle.evidence),
                            'sha256': cycle.evidence_sha256, 'world_id': WORLD,
                            'source_revision': {'life_seq': 1}},
               'import': {'created': dispatched}, 'issue_total': dispatched,
               'dispatched': dispatched, 'aborted_by': None, 'results': results,
               'guards': observe_guards(),
               'credential_leak_in_run_dir': [], 'recovered_in_flight': [], 'prior_ledger': None,
               'review_state': 'unapproved', 'deployed': False,
               'currency_billing': 'not derived from token counters'}
    receipt.update(overrides)
    write_json(cycle.state_dir / 'runs' / run_id / 'run.json', receipt)
    return receipt


class PolicyTests(unittest.TestCase):
    def test_example_policy_loads_and_satisfies_the_host_constraints(self):
        policy = gm_runner.read_autonomy_policy(EXAMPLE)
        self.assertEqual(gm_autonomy.policy_errors(policy), [])

    def test_read_autonomy_policy_refuses_a_bad_shape(self):
        for field, value in (('schema_version', 2), ('mode', 'live'), ('policy_id', ''),
                             ('world_id', ''), ('objective', 'too short')):
            with self.subTest(field=field):
                path = write_json(WORK / ('bad-' + field + '.json'),
                                  dict(example_policy(), **{field: value}))
                with self.assertRaises(ValueError):
                    gm_runner.read_autonomy_policy(path)

    def test_policy_errors_keep_refusing_absent_constraints(self):
        for removed in ('allowed_source_paths',):
            with self.subTest(removed=removed):
                document = example_policy()
                document['scope_constraints'].pop(removed, None)
                document.pop(removed, None)
                self.assertTrue(gm_autonomy.policy_errors(document))
        document = example_policy()
        document.pop('host_owned_paths', None)
        self.assertEqual(gm_autonomy.policy_errors(document), [])
        document = example_policy()
        document.pop('required_test_commands', None)
        self.assertEqual(gm_autonomy.policy_errors(document), [])
        document = example_policy()
        document['scope_constraints']['max_changed_files'] = 99
        self.assertTrue(gm_autonomy.policy_errors(document))
        document = example_policy()
        document['limits']['max_attempts_per_issue'] = 0
        self.assertTrue(gm_autonomy.policy_errors(document))
class ScopeGateTests(unittest.TestCase):
    def setUp(self):
        self.policy = gm_runner.read_autonomy_policy(EXAMPLE)

    def validate(self, scope):
        return gm_autonomy.validate_proposed_scope(scope, self.policy)

    def test_accepts_a_bounded_in_policy_scope(self):
        scope, errors = self.validate({'objective': 'Restore the bounded well capability.',
                                       'files': ['game/capabilities/well.v1.json'],
                                       'acceptance': ['the resident draws water']})
        self.assertEqual(errors, [])
        self.assertEqual(scope['files'], ['game/capabilities/well.v1.json'])

    def test_never_returns_coder_supplied_test_commands(self):
        scope, errors = self.validate({'objective': 'Restore the bounded well capability.',
                                       'files': ['game/capabilities/well.v1.json'],
                                       'acceptance': ['the resident draws water'],
                                       'test_commands': [['echo', 'pass']]})
        self.assertEqual(errors, [])
        self.assertEqual(sorted(scope), ['acceptance', 'files', 'objective'])

    def test_refuses_each_out_of_policy_path(self):
        cases = {'excluded': 'game/project.godot',
                 'outside_allowed': 'game/scenes/street.tscn',
                 'host_owned': 'tools/gm_runner.py',
                 'absolute': 'C:/Windows/system32/x.json',
                 'traversal': '../outside.json'}
        for label, target in cases.items():
            with self.subTest(label=label):
                scope, errors = self.validate({'objective': 'Touch something forbidden.',
                                               'files': [target], 'acceptance': ['refused']})
                self.assertIsNone(scope)
                self.assertTrue(errors)

    def test_refuses_more_files_than_the_policy_allows(self):
        scope, errors = self.validate({'objective': 'Too many files at once.',
                                       'files': ['game/capabilities/a.json',
                                                 'game/capabilities/b.json'],
                                       'acceptance': ['refused']})
        self.assertIsNone(scope)
        self.assertTrue(any('max_changed_files' in error for error in errors))

    def test_refuses_empty_acceptance_and_short_objective(self):
        for scope in ({'objective': 'nope', 'files': ['game/capabilities/a.json'],
                       'acceptance': ['x']},
                      {'objective': 'A perfectly reasonable sentence.',
                       'files': ['game/capabilities/a.json'], 'acceptance': []}):
            with self.subTest(scope=scope):
                self.assertTrue(self.validate(scope)[1])


class ProductionRuntimePolicyTests(unittest.TestCase):
    def test_production_host_contract_is_explicit_and_inference_free(self):
        policy = example_policy()
        policy['mode'] = 'production'
        policy['runtime'] = {
            'kind': 'production_host_contract', 'godot': 'C:/godot.exe',
            'save_path': 'tmp/world.json', 'timeout_seconds': 120,
            'host_command': ['python', 'host_check.py', '--save={save_copy}', '--out={out}'],
            'supported_issue_prefixes': ['journey_stall:'],
            'required_release_paths': ['game/spatial/**']}
        self.assertEqual(gm_autonomy.policy_errors(policy), [])
        policy['mode'] = 'offline_fixture'
        self.assertEqual(gm_autonomy.policy_errors(policy), [])


class MappingTests(unittest.TestCase):
    def test_path_matches_globs(self):
        self.assertTrue(gm_autonomy.path_matches('game/capabilities/a.json', 'game/**'))
        self.assertTrue(gm_autonomy.path_matches('game/capabilities/a.json',
                                                 'game/capabilities/*'))
        self.assertFalse(gm_autonomy.path_matches('game/capabilities/nested/a.json',
                                                  'game/capabilities/*'))
        self.assertFalse(gm_autonomy.path_matches('tools/gm_runner.py', 'game/**'))
        self.assertTrue(gm_autonomy.path_matches('game/capabilities/a.json',
                                                 'game/capabilities/a.json'))

    def test_deployment_target_maps_repo_prefixes(self):
        self.assertEqual(
            gm_autonomy.deployment_target('game/capabilities/a.json', {'game/': ''}),
            'capabilities/a.json')
        self.assertEqual(
            gm_autonomy.deployment_target('game/capabilities/a.json',
                                          {'game/capabilities/': 'res/data/'}),
            'res/data/a.json')
        self.assertIsNone(gm_autonomy.deployment_target('tools/x.py', {'game/': ''}))

    def test_resolve_command_replaces_placeholders_and_refuses_leftovers(self):
        resolved, errors = gm_autonomy.resolve_command(
            ['python', '{root}/tools/x.py', '--scope', '{scope_file}'],
            {'root': 'C:/repo', 'scope_file': 'C:/repo/s.json'})
        self.assertEqual(errors, [])
        self.assertEqual(resolved,
                         ['python', 'C:/repo/tools/x.py', '--scope', 'C:/repo/s.json'])
        _, errors = gm_autonomy.resolve_command(['x', '{unknown}'], {'root': 'r'})
        self.assertTrue(errors)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        shutil.rmtree(WORK / 'preflight', ignore_errors=True)
        self.root = WORK / 'preflight'
        write_json(self.root / 'evidence.json', {'kind': 'x'})
        write_json(self.root / 'prior-ledger.json', {'entries': []})
        (self.root / 'checkout').mkdir(parents=True)
        write_json(self.root / 'checkout' / 'deployment-base.json', {'files': {}})
        (self.root / 'godot.exe').write_bytes(b'')
        (self.root / 'runtime').mkdir()
        self.policy = example_policy()
        self.policy['paths'] = {'evidence': str(self.root / 'evidence.json'),
                                'state_dir': str(self.root / 'state'),
                                'prior_ledger': str(self.root / 'prior-ledger.json')}
        self.policy['deployment'] = {'checkout': str(self.root / 'checkout'),
                                     'base_manifest': str(self.root / 'checkout' /
                                                          'deployment-base.json'),
                                     'path_map': {'game/': ''}}
        self.policy['runtime'] = {'godot': str(self.root / 'godot.exe'), 'script': 'res://x.gd',
                                  'save_path': str(self.root / 'runtime' / 'save.json')}

    def test_offline_fixture_needs_no_carried_state(self):
        self.assertEqual(gm_autonomy.missing_requirements(self.policy, 'offline_fixture'), [])

    def test_production_refuses_before_dispatch_when_carried_state_is_absent(self):
        missing = gm_autonomy.missing_requirements(self.policy, 'production')
        self.assertTrue(any('state' in item for item in missing), missing)

    def test_every_declared_input_is_reported_when_absent(self):
        empty = dict(self.policy,
                     paths={'evidence': str(self.root / 'nope.json'),
                            'state_dir': str(self.root / 'state'),
                            'prior_ledger': str(self.root / 'nope-ledger.json')},
                     deployment={'checkout': str(self.root / 'nope-checkout'),
                                 'base_manifest': str(self.root / 'nope.json'),
                                 'path_map': {'game/': ''}},
                     runtime={'godot': str(self.root / 'nope.exe'), 'script': 'res://x.gd',
                              'save_path': str(self.root / 'nope' / 'save.json')})
        missing = gm_autonomy.missing_requirements(empty, 'production')
        self.assertGreaterEqual(len(missing), 5, missing)
class OriginAndStateTests(unittest.TestCase):
    def setUp(self):
        shutil.rmtree(WORK / 'state', ignore_errors=True)
        self.root = WORK / 'state'
        self.policy_path = write_json(self.root / 'policy.json', example_policy())
        self.policy = gm_runner.read_autonomy_policy(self.policy_path)
        self.evidence = write_json(self.root / 'evidence.json',
                                   {'world_id': WORLD, 'counts': {},
                                    'evidence': [{'issue_id': 'a'}],
                                    'proposals': [{'proposal_id': 'b'}]})
        self.policy['paths']['evidence'] = str(self.evidence)
        self.policy['paths']['state_dir'] = str(self.root / 'gm')
        self.policy['paths']['prior_ledger'] = str(self.root / 'ledger.json')
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)

    def test_observation_origin_is_explicit_and_bounded(self):
        document = gm_runner.load_json(self.evidence)
        investigation = gm_runner.autonomy_investigation(document, 'sha', self.policy)
        self.assertEqual(investigation['origin'], 'autonomous_observation')
        self.assertLessEqual(len(investigation['evidence_refs']), 8)
        self.assertIn('/counts', investigation['evidence_refs'])
        self.assertEqual(investigation['objective'], self.policy['objective'].strip())

    def test_cycle_identity_is_stable_for_the_same_policy_and_evidence(self):
        other = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        self.assertEqual(self.cycle.cycle_dir(), other.cycle_dir())

    def test_changed_evidence_is_a_new_cycle(self):
        before = self.cycle.cycle_dir()
        write_json(self.evidence, {'world_id': WORLD, 'counts': {}, 'evidence': [],
                                   'proposals': []})
        # The running cycle keeps its pinned evidence; a freshly constructed one sees the new
        # bytes as a new cycle instead of silently moving under the running process.
        self.assertEqual(before, self.cycle.cycle_dir())
        self.assertNotEqual(before, gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
                            .cycle_dir())

    def test_resume_refuses_a_cycle_started_under_another_policy(self):
        directory = self.cycle.cycle_dir()
        directory.mkdir(parents=True, exist_ok=True)
        write_json(directory / 'cycle.json', {'schema_version': 1, 'policy_sha256': 'stale'})
        with self.assertRaises(ValueError):
            self.cycle.load_cycle()

    def test_a_stage_already_done_is_not_replayed(self):
        cycle = self.cycle.load_cycle()
        cycle['stages']['publish'] = {'status': 'done',
                                      'published_utc': '2026-01-01T00:00:00+00:00'}
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        self.assertEqual(cycle['stages']['publish']['published_utc'],
                         '2026-01-01T00:00:00+00:00')


class AcknowledgementTests(unittest.TestCase):
    def test_acknowledge_dispatch_carries_no_provider_route(self):
        command = gm_autonomy.runner_command({'config': 'c.json', 'key_file': 'k.txt'},
                                             'acknowledge', '--state-dir', 's', '--gm', 'gm-02',
                                             '--note', 'measured retry')
        self.assertIn('acknowledge', command)
        for flag in ('--config', '--key-file', '--codex', '--codex-home'):
            self.assertNotIn(flag, command)


class ObserveCliTests(unittest.TestCase):
    def test_autonomy_policy_and_investigation_file_are_mutually_exclusive(self):
        if not ACCEPTED_EVIDENCE.is_file():
            self.skipTest('accepted evidence fixture is absent')
        finished = subprocess.run(
            [sys.executable, str(ROOT / 'tools' / 'gm_runner.py'), 'observe',
             '--evidence', str(ACCEPTED_EVIDENCE), '--state-dir', str(WORK / 'observe-cli'),
             '--investigation-file', str(ACCEPTED_EVIDENCE), '--autonomy-policy', str(EXAMPLE),
             '--dry-run'],
            cwd=str(ROOT), capture_output=True, text=True, encoding='utf-8', errors='replace')
        self.assertEqual(finished.returncode, 2, finished.stdout[-400:] + finished.stderr[-400:])


def pid_alive(pid: int) -> bool:
    if os.name != 'nt':
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        return True
    import ctypes
    from ctypes import wintypes
    kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
    handle = kernel32.OpenProcess(0x1000, False, pid)
    if not handle:
        return False
    try:
        code = wintypes.DWORD()
        if not kernel32.GetExitCodeProcess(handle, ctypes.byref(code)):
            return False
        return code.value == 259
    finally:
        kernel32.CloseHandle(handle)


class CorrectionBase(unittest.TestCase):
    def setUp(self):
        self.root = WORK / 'correction'
        shutil.rmtree(self.root, ignore_errors=True)
        self.root.mkdir(parents=True)
        self.policy_path = write_json(self.root / 'policy.json', example_policy())
        self.policy = gm_runner.read_autonomy_policy(self.policy_path)
        self.checkout = self.root / 'trial'
        self.candidate = self.root / 'candidate'
        (self.checkout / 'capabilities').mkdir(parents=True)
        (self.candidate / 'game' / 'capabilities').mkdir(parents=True)
        (self.root / 'runtime').mkdir(parents=True)
        self.rel = 'game/capabilities/well.v1.json'
        self.target = 'capabilities/well.v1.json'
        write_json(self.candidate / self.rel, {'ok': True})
        write_json(self.root / 'base.json', {'schema_version': 1, 'files': {self.target: None}})
        self.policy['paths']['evidence'] = str(write_json(
            self.root / 'evidence.json',
            {'world_id': WORLD, 'counts': {}, 'evidence': [], 'proposals': []}))
        self.policy['paths']['state_dir'] = str(self.root / 'state')
        self.policy['paths']['prior_ledger'] = str(self.root / 'ledger.json')
        self.policy['deployment']['checkout'] = str(self.checkout)
        self.policy['deployment']['base_manifest'] = str(self.root / 'base.json')
        self.policy['runtime']['save_path'] = str(self.root / 'runtime' / 'save.json')
        # Keep the on-disk policy consistent with the in-memory copy: the cycle identity is
        # bound to the policy bytes, so a test must not rewrite the file after construction.
        write_json(self.root / 'ledger.json', {'kind': 'fixture', 'calls': []})
        write_json(self.root / 'godot.exe', {'stub': True})
        self.policy['runtime']['godot'] = str(self.root / 'godot.exe')
        write_json(self.policy_path, self.policy)
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        self.cycle.autonomy_dir().mkdir(parents=True, exist_ok=True)
        self.digest = gm_runner.sha256_file(self.candidate / self.rel)

    def publish_ready_cycle(self) -> dict:
        cycle = self.cycle.load_cycle()
        cycle['gm_id'] = 'gm-02'
        cycle['issue_id'] = 'issue-1'
        cycle['stages']['candidate'] = {'status': 'done', 'candidate_abs': str(self.candidate),
                                       'base_revision': 'base-rev',
                                       'host_owned_before': self.cycle.host_owned_hashes()}
        cycle['stages']['validate'] = {'status': 'done', 'ok': True,
                                      'publish_ready': True,
                                      'file_hashes': {self.rel: self.digest}}
        cycle['stages']['review'] = {'status': 'done', 'review_state': 'advisory',
                                     'candidate_sha256': self.cycle.candidate_version_sha(cycle)}
        cycle['main_ai_review'] = {'cycle_id': cycle['cycle_id'], 'gm_id': 'gm-02',
                                   'candidate_sha256': self.cycle.candidate_version_sha(cycle),
                                   'source': 'main-ai:legacy-fixture', 'decision': 'advisory',
                                   'suggestions': ['Fixture review recorded.']}
        return cycle


class PublicationSafetyTests(CorrectionBase):
    def test_changed_candidate_bytes_are_refused_before_any_target_write(self):
        cycle = self.publish_ready_cycle()
        write_json(self.candidate / self.rel, {'ok': True, 'tampered': True})
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.UNACCEPTABLE)
        self.assertEqual(cycle['blocked_reason'], 'candidate_bytes_changed_after_gate')
        self.assertFalse((self.checkout / self.target).exists())

    def test_a_bounded_multi_file_release_policy_is_accepted(self):
        document = example_policy()
        document['deployment']['max_files_per_release'] = 2
        document['scope_constraints']['max_changed_files'] = 2
        self.assertEqual(gm_autonomy.policy_errors(document), [])

    def test_a_traversing_path_map_is_refused_up_front(self):
        document = example_policy()
        document['deployment']['path_map'] = {'game/': '../../escape'}
        self.assertTrue(gm_autonomy.policy_errors(document))

    def test_a_single_file_release_installs_the_validated_bytes_once(self):
        cycle = self.publish_ready_cycle()
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        installed = (self.checkout / self.target).read_bytes()
        self.assertEqual(gm_runner.sha256_bytes(installed), self.digest)
        record = cycle['stages']['publish']
        self.assertTrue(record.get('publish_receipt'))
        self.assertFalse(self.cycle.publish_journal_path().exists())

    def test_a_second_release_replaces_owned_prior_bytes_but_refuses_third_party_drift(self):
        self.cycle.limits['max_publishes'] = 2
        cycle = self.publish_ready_cycle()
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        owned = (self.checkout / self.target).read_bytes()
        (self.checkout / self.target).write_bytes(b'third party bytes')
        cycle['stages']['publish'] = {'status': 'pending'}
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.PRECONDITION)
        self.assertEqual(cycle['blocked_reason'], 'release_conflict')
        self.assertEqual((self.checkout / self.target).read_bytes(), b'third party bytes')
        (self.checkout / self.target).write_bytes(owned)
        write_json(self.candidate / self.rel, {'ok': True, 'v': 2})
        cycle['stages']['validate'] = {
            'status': 'done', 'ok': True,
            'file_hashes': {self.rel: gm_runner.sha256_file(self.candidate / self.rel)}}
        cycle['stages']['publish'] = {'status': 'pending'}
        cycle['blocked_reason'] = None
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        self.assertEqual((self.checkout / self.target).read_bytes(),
                         (self.candidate / self.rel).read_bytes())

    def test_a_crash_after_replace_is_recovered_idempotently(self):
        cycle = self.publish_ready_cycle()
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        installed = (self.checkout / self.target).read_bytes()
        record = cycle['stages']['publish']
        digest = record['release_digest']
        record.pop('publish_receipt')
        record['status'] = 'pending'
        gm_runner.save_json(self.cycle.publish_journal_path(), {
            'schema_version': 1, 'cycle_id': cycle['cycle_id'], 'release_digest': digest,
            'binding': {}, 'files': [{'source': self.rel, 'target': self.target,
                                      'sha256': self.digest, 'previous_sha256': None}],
            'written_utc': gm_runner.utc_iso()})
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        self.assertEqual((self.checkout / self.target).read_bytes(), installed)
        self.assertTrue(cycle['stages']['publish'].get('publish_receipt'))

    def test_partial_resume_failure_preserves_file_already_installed_by_prior_attempt(self):
        files = [f'game/capabilities/resume-{index}.json' for index in range(2)]
        targets = [f'capabilities/resume-{index}.json' for index in range(2)]
        for index, rel in enumerate(files):
            write_json(self.candidate / rel, {'index': index})
        base_payload = b'original-base-two'
        target_two = self.checkout / targets[1]
        target_two.parent.mkdir(parents=True, exist_ok=True)
        target_two.write_bytes(base_payload)
        write_json(self.root / 'base.json', {'schema_version': 1,
                                             'files': {targets[0]: None,
                                                       targets[1]: gm_runner.sha256_bytes(
                                                           base_payload)}})
        self.policy['scope_constraints']['max_changed_files'] = 2
        self.policy['deployment']['max_files_per_release'] = 2
        write_json(self.policy_path, self.policy)
        self.policy = gm_runner.read_autonomy_policy(self.policy_path)
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        cycle = self.cycle.load_cycle()
        cycle.update({'gm_id': 'gm-02', 'issue_id': 'issue-1'})
        hashes = {rel: gm_runner.sha256_file(self.candidate / rel) for rel in files}
        cycle['stages']['candidate'] = {'status': 'done', 'candidate_abs': str(self.candidate),
                                       'base_revision': 'base-rev',
                                       'host_owned_before': self.cycle.host_owned_hashes()}
        cycle['stages']['validate'] = {'status': 'done', 'ok': True, 'publish_ready': True,
                                      'file_hashes': hashes}
        cycle['stages']['review'] = {'status': 'done', 'review_state': 'advisory'}
        cycle['main_ai_review'] = {'cycle_id': cycle['cycle_id'], 'gm_id': 'gm-02',
                                   'candidate_sha256': self.cycle.candidate_version_sha(cycle),
                                   'source': 'main-ai:test', 'decision': 'advisory',
                                   'suggestions': ['Resume recovery checked.']}
        target_one = self.checkout / targets[0]
        target_one.parent.mkdir(parents=True, exist_ok=True)
        target_one.write_bytes((self.candidate / files[0]).read_bytes())
        release_digest = gm_runner.sha256_bytes(json.dumps(
            sorted([[targets[index], hashes[files[index]]] for index in range(2)]),
            sort_keys=True).encode())
        gm_runner.save_json(self.cycle.publish_journal_path(), {
            'schema_version': 1, 'cycle_id': cycle['cycle_id'],
            'release_digest': release_digest, 'binding': {},
            'files': [{'source': rel, 'target': target, 'sha256': hashes[rel],
                       'previous_sha256': None} for rel, target in zip(files, targets)],
            'written_utc': gm_runner.utc_iso()})
        real_replace = gm_autonomy.os.replace
        failed = {'value': False}

        def replace_then_fail(source, destination):
            real_replace(source, destination)
            if Path(destination) == target_two and not failed['value']:
                failed['value'] = True
                raise OSError('simulated resume failure after replace')

        with mock.patch.object(gm_autonomy.os, 'replace', side_effect=replace_then_fail):
            self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.RUNTIME)
        self.assertEqual(target_one.read_bytes(), (self.candidate / files[0]).read_bytes())
        self.assertEqual(target_two.read_bytes(), base_payload,
                         'failed second-attempt write must restore its original base backup')

    def test_recovery_refuses_bytes_from_neither_base_nor_release(self):
        cycle = self.publish_ready_cycle()
        prepared = [{'source': self.rel, 'target': self.target, 'sha256': self.digest,
                     'payload': (self.candidate / self.rel).read_bytes(),
                     'absolute': self.checkout / self.target}]
        digest = gm_runner.sha256_bytes(
            json.dumps(sorted([[self.target, self.digest]]), sort_keys=True).encode())
        (self.checkout / self.target).write_bytes(b'some other writer bytes')
        gm_runner.save_json(self.cycle.publish_journal_path(), {
            'schema_version': 1, 'cycle_id': cycle['cycle_id'], 'release_digest': digest,
            'binding': {}, 'files': [{'source': self.rel, 'target': self.target,
                                      'sha256': self.digest, 'previous_sha256': None}],
            'written_utc': gm_runner.utc_iso()})
        result = self.cycle.recover_publish(cycle, cycle['stages'].setdefault('publish', {}),
                                            self.checkout, prepared, {self.target: None},
                                            digest, {})
        self.assertEqual(result, gm_autonomy.PRECONDITION)
        self.assertEqual((self.checkout / self.target).read_bytes(), b'some other writer bytes')


    def _refuse_stale_binding(self, cycle):
        """A stale pinned binding must refuse BEFORE any deployment target is touched."""
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.UNACCEPTABLE)
        self.assertEqual(cycle['blocked_reason'], 'release_binding_stale')
        self.assertFalse((self.checkout / self.target).exists())

    def test_an_edited_policy_on_disk_is_refused_before_any_target_write(self):
        cycle = self.publish_ready_cycle()
        edited = json.loads(self.policy_path.read_text(encoding='utf-8'))
        edited['objective'] = edited['objective'] + ' Edited on disk after the host gate.'
        write_json(self.policy_path, edited)
        self._refuse_stale_binding(cycle)

    def test_an_edited_base_manifest_is_refused_before_any_target_write(self):
        cycle = self.publish_ready_cycle()
        write_json(self.root / 'base.json', {'schema_version': 1,
                                             'files': {self.target: 'rewritten after the gate'}})
        self._refuse_stale_binding(cycle)

    def test_an_edited_host_owned_script_is_refused_before_any_target_write(self):
        # The real policy pins this repository's own tools and tests, which a test must never
        # rewrite, so this case pins a local host-owned file instead.
        host_script = self.root / 'host_check.py'
        host_script.write_text('print("host check")' + chr(10), encoding='utf-8')
        document = json.loads(self.policy_path.read_text(encoding='utf-8'))
        document['host_owned_paths'] = [str(host_script)]
        write_json(self.policy_path, document)
        self.policy = gm_runner.read_autonomy_policy(self.policy_path)
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        cycle = self.publish_ready_cycle()
        host_script.write_text('print("host check, edited")' + chr(10), encoding='utf-8')
        self._refuse_stale_binding(cycle)

    def test_a_reopened_cycle_without_a_pinned_base_manifest_is_never_rebound(self):
        cycle = self.publish_ready_cycle()
        cycle.pop('base_manifest_sha256')
        self._refuse_stale_binding(cycle)

    def test_a_reopened_cycle_without_pinned_host_hashes_is_never_rebound(self):
        cycle = self.publish_ready_cycle()
        cycle.pop('host_owned_pinned')
        self._refuse_stale_binding(cycle)


class CapabilityModuleGateTests(unittest.TestCase):
    """The bounded Python interface guard on its own.

    It bounds bytes, decodes UTF-8, balances delimiters and filters tokens. It is not a compiler
    and not a sandbox: a delimiter-balanced source that cannot parse still passes it, and the
    real compile/interface check is the host-owned Godot smoke in ModuleCompileSmokeTests.
    """

    def test_the_module_gate_accepts_both_versions_and_rejects_unsafe_or_wrong_interface(self):
        NL = chr(10)
        root = WORK / 'module-gate'
        shutil.rmtree(root, ignore_errors=True)
        root.mkdir(parents=True)
        version = 'static func lookup_well_stock(s):' + NL + '    return {"ok": %s}' + NL
        bad = root / 'bad.gd'
        bad.write_text(version % 'false', encoding='utf-8')
        good = root / 'good.gd'
        good.write_text(version % 'true', encoding='utf-8')
        self.assertEqual(validate.validate_capability_module(bad, 'bad.gd'), [])
        self.assertEqual(validate.validate_capability_module(good, 'good.gd'), [])
        unsafe = root / 'unsafe.gd'
        unsafe.write_text('static func lookup_well_stock(s):' + NL + '    return OS.get_name()' + NL,
                          encoding='utf-8')
        self.assertTrue(validate.validate_capability_module(unsafe, 'unsafe.gd'))
        missing = root / 'missing.gd'
        missing.write_text('static func other():' + NL + '    pass' + NL, encoding='utf-8')
        self.assertTrue(validate.validate_capability_module(missing, 'missing.gd'))

class ModuleCompileSmokeTests(unittest.TestCase):
    """The real Godot compile/interface smoke, which the bounded Python guard cannot replace."""

    def setUp(self):
        self.root = WORK / 'module-compile-smoke'
        shutil.rmtree(self.root, ignore_errors=True)
        self.root.mkdir(parents=True)
        self.godot = validate.find_godot()
        if not self.godot:
            self.skipTest('no Godot executable is available for the compile smoke')
        namespace = {}
        exec(validate.FAKE_CODEX, namespace)
        self.version_modules = {'bad': namespace['CAUSAL_BAD_MODULE'],
                                'good': namespace['CAUSAL_GOOD_MODULE']}
        self.rel = 'game/capabilities/well_stock_lookup.gd'
        self.syntax_invalid = chr(10).join([
            'extends RefCounted',
            'static func lookup_well_stock(s: Dictionary) -> Dictionary:',
            chr(9) + 'if:',
            chr(9) + chr(9) + 'pass',
            chr(9) + 'return {}', ''])

    def write_module(self, name, document, candidate=None):
        module = (candidate or self.root) / (name + '.gd')
        module.parent.mkdir(parents=True, exist_ok=True)
        module.write_text(document, encoding='utf-8')
        return module

    def smoke(self, module):
        return validate.godot_module_smoke(module, module.name, self.godot, self.root, 60)

    def test_both_lookup_versions_compile_and_return_a_valid_missing_stock_error(self):
        for label, document in self.version_modules.items():
            with self.subTest(version=label):
                report = self.smoke(self.write_module(label, document))
                self.assertTrue(report['ok'], report['errors'])
                self.assertTrue(report['compiled'])
                self.assertEqual(report['code'], 'runtime_mechanism_error')
        self.assertEqual(sorted(self.root.glob('gm-module-smoke-*')), [],
                         'the scratch project must stay task-owned and be removed')

    def test_a_delimiter_balanced_module_that_cannot_parse_is_refused(self):
        module = self.write_module('syntax', self.syntax_invalid)
        # The bounded Python interface guard alone cannot see this: balanced delimiters are not
        # syntax, so the compile smoke is what refuses it.
        self.assertEqual(validate.validate_capability_module(module, 'syntax.gd'), [])
        report = self.smoke(module)
        self.assertFalse(report['ok'])
        self.assertFalse(report['compiled'])
        self.assertTrue(report['errors'])

    def test_a_compiling_module_without_the_declared_interface_is_refused(self):
        module = self.write_module('nofunc', chr(10).join(['extends RefCounted',
                                                          'static func other() -> void:',
                                                          chr(9) + 'pass', '']))
        report = self.smoke(module)
        self.assertFalse(report['ok'])
        self.assertTrue(report['compiled'])
        self.assertIn('lookup_well_stock', report['failures'][0])

    def test_a_module_that_is_not_schema_valid_on_empty_input_is_refused(self):
        module = self.write_module('wrongshape', chr(10).join([
            'extends RefCounted',
            'static func lookup_well_stock(s: Dictionary) -> Dictionary:',
            chr(9) + 'return {"ok": true}', '']))
        report = self.smoke(module)
        self.assertFalse(report['ok'])
        self.assertTrue(report['compiled'])

    def test_the_host_gate_cli_refuses_a_module_only_the_compiler_can_reject(self):
        candidate = self.root / 'candidate'
        module = self.write_module('well_stock_lookup', self.syntax_invalid,
                                   candidate / 'game' / 'capabilities')
        scope = write_json(self.root / 'scope.json', {'objective': 'Compile one module.',
                                                     'files': [self.rel],
                                                     'acceptance': ['refused']})
        document = example_policy()
        document['runtime']['godot'] = self.godot
        document['paths']['state_dir'] = str(self.root / 'state')
        policy = write_json(self.root / 'policy.json', document)

        def run_gate():
            outcome = subprocess.run(
                [sys.executable, str(ROOT / 'tools' / 'validate_gm_autonomy.py'),
                 'validate-candidate', '--candidate', str(candidate), '--scope', str(scope),
                 '--policy', str(policy)],
                capture_output=True, text=True, encoding='utf-8', cwd=str(ROOT))
            return outcome, json.loads(outcome.stdout.strip().splitlines()[-1])

        outcome, payload = run_gate()
        self.assertEqual(outcome.returncode, 1, payload)
        self.assertFalse(payload['ok'])
        self.assertFalse(payload['module_smoke'][0]['compiled'])
        module.write_text(self.version_modules['good'], encoding='utf-8')
        outcome, payload = run_gate()
        self.assertEqual(outcome.returncode, 0, payload['errors'])
        self.assertTrue(payload['module_smoke'][0]['compiled'])


class CycleIdentityTests(CorrectionBase):
    def test_changed_evidence_does_not_abandon_an_unfinished_cycle(self):
        first = self.cycle.load_cycle()
        self.cycle.save_cycle(first)
        write_json(self.cycle.evidence, {'world_id': WORLD, 'counts': {'x': 1},
                                         'evidence': [], 'proposals': []})
        newer = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        self.assertNotEqual(newer.cycle_dir(), self.cycle.cycle_dir())
        adopted = newer.unfinished_cycle()
        self.assertIsNotNone(adopted)
        newer.adopt(adopted)
        self.assertEqual(newer.cycle_dir(), self.cycle.cycle_dir())

    def test_a_blocked_cycle_is_not_replayed_or_re_dispatched(self):
        cycle = self.cycle.load_cycle()
        cycle['status'] = 'blocked'
        cycle['exit_code'] = 5
        self.cycle.save_cycle(cycle)
        self.assertEqual(self.cycle.run(), 5)

    def test_an_unfinished_in_flight_call_stops_with_unknown_cost(self):
        cycle = self.cycle.load_cycle()
        cycle['stages']['observe'] = {'status': 'pending', 'in_flight': {
            'stage': 'observe', 'model_calls_reserved': 10, 'reserved_utc': 'x'}}
        self.assertEqual(self.cycle.stage_observe(cycle), gm_autonomy.ACCOUNTING)
        self.assertTrue(cycle['blocked_reason'].startswith('interrupted_inflight_observe'))
        self.assertTrue(cycle['unknown'])
        self.assertTrue(cycle['stages']['observe']['unknown_evidence'])

    def test_deadline_and_evidence_are_pinned_and_resumed(self):
        first = self.cycle.load_cycle()
        self.cycle.save_cycle(first)
        document = gm_runner.load_json(self.cycle.cycle_dir() / 'cycle.json')
        self.assertEqual(document['evidence_sha256'], self.cycle.evidence_sha256)
        self.assertIn('deadline_epoch', document)
        restarted = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        restarted.load_cycle()
        self.assertEqual(restarted.deadline, first['deadline_epoch'])
        self.assertEqual(restarted.evidence_sha256, first['evidence_sha256'])
        self.assertEqual(restarted.cycle_dir(), self.cycle.cycle_dir())


class OwnerLockTests(CorrectionBase):
    def test_an_active_owner_lock_is_never_displaced(self):
        with self.cycle.cycle_lock():
            rival = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
            with self.assertRaises(RuntimeError):
                with rival.cycle_lock():
                    pass

    def test_a_dead_owners_lock_metadata_is_recovered_with_its_identity(self):
        directory = self.cycle.autonomy_dir() / 'cycle-owner'
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'lock.json').write_text(json.dumps(
            {'pid': 424242, 'acquired_utc': '2026-01-01T00:00:00+00:00'}), encoding='utf-8')
        with self.cycle.cycle_lock() as lock:
            self.assertEqual(lock.recovered.get('pid'), 424242)


class ScopeSelectionTests(CorrectionBase):
    def test_an_existing_evidence_issue_scope_can_be_selected(self):
        state = gm_runner.load_state(self.cycle.state_dir)
        state['world_id'] = WORLD
        state['issues']['issue-1'] = {
            'issue_id': 'issue-1', 'world_id': WORLD, 'lifecycle': 'current',
            'source_status': 'open', 'content_digest': 'd', 'settled': {}, 'outcomes': [],
            'owner_gm': 'gm-02', 'owner_run_id': 'run-1',
            'proposed_scope': {'objective': 'Restore the bounded well capability.',
                               'files': ['game/capabilities/well.v1.json'],
                               'acceptance': ['the resident draws water']}}
        gm_runner.store_state(self.cycle.state_dir, state)
        cycle = self.publish_ready_cycle()
        record = {'run_id': 'run-1'}
        self.cycle.select_claim(cycle, record)
        self.assertEqual(record.get('issue_id'), 'issue-1')
        self.assertEqual(record.get('gm_id'), 'gm-02')
        self.assertFalse(record.get('no_action'))

    def test_a_newly_proposed_issue_scope_can_be_selected(self):
        state = gm_runner.load_state(self.cycle.state_dir)
        state['world_id'] = WORLD
        state['issues']['proposal-1'] = {
            'issue_id': 'proposal-1', 'world_id': WORLD, 'lifecycle': 'current',
            'source_status': 'proposed', 'content_digest': 'd', 'settled': {}, 'outcomes': [],
            'owner_gm': 'gm-07', 'owner_run_id': 'run-1', 'provenance': {'origin': 'gm_proposed'},
            'proposed_scope': {'objective': 'Restore the bounded well capability.',
                               'files': ['game/capabilities/well.v1.json'],
                               'acceptance': ['the resident draws water']}}
        gm_runner.store_state(self.cycle.state_dir, state)
        cycle = self.publish_ready_cycle()
        record = {'run_id': 'run-1'}
        self.cycle.select_claim(cycle, record)
        self.assertEqual(record.get('issue_id'), 'proposal-1')


class OwnedProcessTests(unittest.TestCase):
    def test_child_and_grandchild_are_cleaned_up_on_timeout(self):
        if os.name != 'nt':
            self.skipTest('windows job containment')
        script = WORK / 'spawn_tree.py'
        script.parent.mkdir(parents=True, exist_ok=True)
        script.write_text('import subprocess, sys, time\n'
                          'child = subprocess.Popen([sys.executable, "-c", '
                          '"import time; time.sleep(300)"])\n'
                          'print(child.pid, flush=True)\n'
                          'time.sleep(300)\n', encoding='utf-8')
        outcome = gm_autonomy.run_process([sys.executable, str(script)], 4)
        self.assertTrue(outcome['timed_out'])
        owned = outcome['owned']
        self.assertTrue(owned['all_members_exited'])
        self.assertGreaterEqual(len(owned['observed_members']), 2, owned)
        grandchild = int((outcome['stdout'] or '0').split()[0])
        self.assertTrue(grandchild)
        self.assertFalse(pid_alive(grandchild), grandchild)
        for member in owned['observed_members']:
            self.assertFalse(pid_alive(member['pid']), member)


class ObserveExitProvenanceTests(CorrectionBase):
    """The observe dispatch is ONE gm_runner command: only the wrapper this host started carries
    the authoritative exit, and only the durable receipt may certify a completed observation."""

    def _summary(self, run_id='run-1', dispatched=10, **overrides):
        summary = {'status': 'ok', 'kind': 'gm_observe', 'run_id': run_id,
                   'run_dir': 'runs/' + run_id, 'world_binding': WORLD,
                   'evidence': {'sha256': self.cycle.evidence_sha256, 'world_id': WORLD},
                   'dispatched': dispatched,
                   'results': [{'gm_id': 'gm-%02d' % (index + 1)} for index in range(dispatched)]}
        summary.update(overrides)
        return summary

    def _result(self, exit_code=1, wrapper_exit=0, timed_out=False, owned=None):
        # The real run_process shape after the provenance change: the wrapper's own exit, the
        # reconciled exit, and the nested nonzero members kept as evidence.
        if owned is None:
            owned = {'containment': 'windows_kill_on_close_job', 'wrapper_pid': 4242,
                     'observed_members': [{'pid': 4242, 'running': False, 'exit_code': wrapper_exit},
                                          {'pid': 4243, 'running': False, 'exit_code': exit_code}],
                     'total_assigned_processes': 2, 'active_processes': 0,
                     'all_members_exited': True, 'member_identity_list_complete': True,
                     'observed_nonzero_exits': ([] if exit_code == 0
                                                else [{'pid': 4243, 'exit_code': exit_code}])}
        return {'exit_code': exit_code, 'wrapper_exit_code': wrapper_exit,
                'exit_reconciled_from_member': bool(exit_code and not wrapper_exit),
                'observed_nonzero_member_exits': owned.get('observed_nonzero_exits') or [],
                'timed_out': timed_out, 'seconds': 0.2, 'stderr': '',
                'stdout': 'diagnostic\n' + json.dumps(self._summary()) + '\n', 'owned': owned}

    def _observe(self, result):
        shutil.rmtree(self.cycle.autonomy_dir(), ignore_errors=True)
        self.cycle.autonomy_dir().mkdir(parents=True, exist_ok=True)
        cycle = self.cycle.load_cycle()
        original = gm_autonomy.run_process
        gm_autonomy.run_process = lambda *args, **kwargs: result
        try:
            return cycle, self.cycle.stage_observe(cycle)
        finally:
            gm_autonomy.run_process = original

    def test_a_completed_runner_receipt_survives_nested_probe_failures(self):
        observe_receipt_fixture(self.cycle)
        cycle, status = self._observe(self._result())
        self.assertEqual(status, gm_autonomy.OK)
        record = cycle['stages']['observe']
        self.assertEqual(record['exit_code'], 1, 'the reconciled exit stays visible, not hidden')
        self.assertEqual(record['wrapper_exit_code'], 0)
        self.assertEqual(record['owned']['wrapper_pid'], 4242)
        self.assertEqual(record['observed_nonzero_member_exits'], [{'pid': 4243, 'exit_code': 1}])
        self.assertEqual(record['carried_receipt']['run_id'], 'run-1')
        self.assertEqual(record['carried_receipt']['dispatched'], 10)
        self.assertEqual(len(record['carried_receipt']['gm_ids']), 10)
        self.assertEqual(record['model_calls_observed'], 10)
        self.assertEqual(record['status'], 'no_action', 'this fixture has no claimed scope')
        self.assertIsNone(cycle.get('blocked_reason'))

    def test_a_nonzero_authoritative_runner_exit_still_fails(self):
        observe_receipt_fixture(self.cycle)
        cycle, status = self._observe(self._result(exit_code=1, wrapper_exit=1))
        self.assertEqual(status, gm_autonomy.RUNTIME)
        self.assertEqual(cycle['blocked_reason'], 'observe_failed')
        self.assertIsNone(cycle['stages']['observe'].get('carried_receipt'))

    def test_a_missing_or_mismatched_receipt_still_fails(self):
        cases = {
            'absent receipt': lambda: None,
            'another run id': lambda: observe_receipt_fixture(self.cycle, run_id='run-2'),
            'wrong evidence': lambda: observe_receipt_fixture(
                self.cycle, evidence={'world_id': WORLD, 'sha256': '0' * 64}),
            'wrong world': lambda: observe_receipt_fixture(self.cycle, world_binding='shared:other'),
            'incomplete status': lambda: observe_receipt_fixture(self.cycle, status='incomplete'),
            'short dispatch list': lambda: observe_receipt_fixture(self.cycle, dispatched=9),
        }
        for name, setup in cases.items():
            with self.subTest(case=name):
                path = self.cycle.state_dir / 'runs' / 'run-1' / 'run.json'
                if path.is_file():
                    path.unlink()
                setup()
                cycle, status = self._observe(self._result())
                self.assertEqual(status, gm_autonomy.RUNTIME, name)
                self.assertEqual(cycle['blocked_reason'], 'observe_failed', name)
                self.assertIsNone(cycle['stages']['observe'].get('carried_receipt'), name)

    def test_dirty_guards_or_unknown_usage_still_fail(self):
        observe_receipt_fixture(
            self.cycle, guards={'before': {'f': '1'}, 'after': {'f': '2'}, 'changed': ['f']})
        cycle, status = self._observe(self._result())
        self.assertEqual(status, gm_autonomy.RUNTIME)
        self.assertEqual(cycle['blocked_reason'], 'observe_failed')
        receipt = observe_receipt_fixture(self.cycle)
        receipt['results'][0].update({'cost': 'unknown', 'usage_measured': False})
        write_json(self.cycle.state_dir / 'runs' / 'run-1' / 'run.json', receipt)
        cycle, status = self._observe(self._result())
        self.assertEqual(status, gm_autonomy.RUNTIME)

    def test_guard_evidence_uses_the_real_snapshot_schema(self):
        # A timestamp-only difference between the two snapshots is not a change; a changed file
        # digest, a moved HEAD, a non-empty claimed change list or a truncated snapshot is.
        observe_receipt_fixture(self.cycle)
        cycle, status = self._observe(self._result())
        self.assertEqual(status, gm_autonomy.OK, 'a later taken_utc alone is not a guard change')
        moved_head = observe_guards()
        moved_head['after'] = dict(moved_head['after'], git_head='0' * 40)
        cases = {
            'changed file digest': observe_guards(
                after_files={'game/spatial/town_street.gd': '9' * 64}),
            'git head moved': moved_head,
            'claimed change list': observe_guards(changed=['file:game/spatial/town_street.gd']),
            'snapshot without the digests': {'before': {'files': {}}, 'after': {'files': {}},
                                             'changed': []},
        }
        for name, guards in cases.items():
            with self.subTest(case=name):
                observe_receipt_fixture(self.cycle, guards=guards)
                cycle, status = self._observe(self._result())
                self.assertEqual(status, gm_autonomy.RUNTIME, name)
                self.assertEqual(cycle['blocked_reason'], 'observe_failed', name)
                self.assertIsNone(cycle['stages']['observe'].get('carried_receipt'), name)

    def test_a_live_child_or_a_timeout_still_fails(self):
        observe_receipt_fixture(self.cycle)
        live = self._result()['owned']
        live.update({'all_members_exited': False, 'active_processes': 1,
                     'observed_members': [{'pid': 4242, 'running': True, 'exit_code': None}]})
        cycle, status = self._observe(self._result(owned=live))
        self.assertEqual(status, gm_autonomy.RUNTIME)
        observe_receipt_fixture(self.cycle)
        cycle, status = self._observe(self._result(timed_out=True))
        self.assertEqual(status, gm_autonomy.RUNTIME)

    def test_a_contradictory_result_or_an_expired_deadline_still_fails(self):
        # A status of "ok" is not enough: the durable result must be a settled, measured, zero-exit
        # dispatch, and an expired pinned deadline is never a completed observation.
        receipt = observe_receipt_fixture(self.cycle)
        receipt['results'][0]['exit_code'] = 1
        write_json(self.cycle.state_dir / 'runs' / 'run-1' / 'run.json', receipt)
        cycle, status = self._observe(self._result())
        self.assertEqual(status, gm_autonomy.RUNTIME)
        self.assertEqual(cycle['blocked_reason'], 'observe_failed')

        receipt = observe_receipt_fixture(self.cycle)
        receipt['results'][0]['cost'] = 'none'
        write_json(self.cycle.state_dir / 'runs' / 'run-1' / 'run.json', receipt)
        cycle, status = self._observe(self._result())
        self.assertEqual(status, gm_autonomy.RUNTIME)
        self.assertEqual(cycle['blocked_reason'], 'observe_failed')

        observe_receipt_fixture(self.cycle)
        expired = self._result()
        expired['deadline_exceeded'] = True
        cycle, status = self._observe(expired)
        self.assertEqual(status, gm_autonomy.RUNTIME)
        self.assertEqual(cycle['blocked_reason'], 'observe_failed')

    def test_a_host_test_command_still_fails_on_its_hidden_child(self):
        script = self.root / 'hidden_failure.py'
        script.write_text('import subprocess, sys, time\n'
                          'child = subprocess.Popen([sys.executable, "-c", '
                          '"raise SystemExit(3)"])\n'
                          'assert child.wait() == 3\n'
                          'time.sleep(0.2)\n'
                          'print("wrapper ok", flush=True)\n', encoding='utf-8')
        outcome = gm_autonomy.run_process([sys.executable, str(script)], 60)
        self.assertEqual(outcome['wrapper_exit_code'], 0, outcome['owned'])
        self.assertNotEqual(outcome['exit_code'], 0,
                            'a host test command still fails on its own hidden child failure')
        self.assertTrue(outcome['observed_nonzero_member_exits'], outcome['owned'])
        self.assertTrue(outcome['owned']['all_members_exited'])


class ObserveCarriedRecoveryTests(CorrectionBase):
    """Offline recovery: carry one completed observe receipt forward with NO new model call."""

    def _source_cycle(self, record=None):
        cycle = self.cycle.load_cycle()
        record = record or {
            'status': 'failed', 'exit_code': 1, 'wrapper_exit_code': 0,
            'exit_reconciled_from_member': True,
            'observed_nonzero_member_exits': [{'pid': 4243, 'exit_code': 1}],
            'timed_out': False, 'seconds': 0.2, 'stderr_tail': '',
            'run_id': 'run-1', 'dispatched': 10, 'model_calls_observed': 10,
            'owned': {'containment': 'windows_kill_on_close_job', 'wrapper_pid': 4242,
                      'observed_members': [{'pid': 4242, 'running': False, 'exit_code': 0},
                                           {'pid': 4243, 'running': False, 'exit_code': 1}],
                      'active_processes': 0, 'all_members_exited': True,
                      'member_identity_list_complete': False},
            'blocked_reason': 'gm_runner observe failed'}
        cycle['status'] = 'blocked'
        cycle['blocked_reason'] = 'observe_failed'
        cycle['stage'] = 'observe'
        cycle['model_calls'] = 10
        cycle['stages'] = {'observe': record}
        self.cycle.save_cycle(cycle)
        write_json(self.cycle.cycle_dir() / 'report.json',
                   {'status': 'blocked', 'blocked_reason': 'observe_failed',
                    'cycle_id': cycle['cycle_id'], 'policy': {'world_id': WORLD}})
        return cycle

    def _call(self, argv):
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            return gm_autonomy.main(argv)

    def _recover(self, cycle_id):
        return self._recover_text(cycle_id)[0]

    def _recover_text(self, cycle_id):
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            code = gm_autonomy.main(['recover-observe', '--policy', str(self.policy_path),
                                     '--cycle', str(cycle_id)])
        return code, stream.getvalue()

    def test_offline_recovery_carries_the_completed_observe_without_a_new_call(self):
        observe_receipt_fixture(self.cycle)
        cycle = self._source_cycle()
        source_dir = self.cycle.cycle_dir()
        before = {name: gm_runner.sha256_file(source_dir / name)
                  for name in ('cycle.json', 'report.json')}
        dispatch = []
        original = gm_autonomy.run_process
        gm_autonomy.run_process = lambda *args, **kwargs: dispatch.append(args)
        try:
            code = self._recover(source_dir.name)
            after = {name: gm_runner.sha256_file(source_dir / name)
                     for name in ('cycle.json', 'report.json')}
            again = self._call(['cycle', '--policy', str(self.policy_path)])
        finally:
            gm_autonomy.run_process = original
        self.assertEqual(code, 0)
        self.assertEqual(before, after, 'the failed cycle and its report stay untouched history')
        self.assertFalse(dispatch, 'recovery and the next cycle call dispatch no command')
        pointer = json.loads((self.cycle.autonomy_dir() / 'current.json').read_text())
        self.assertNotEqual(pointer['cycle_id'], source_dir.name)
        new_dir = self.cycle.autonomy_dir() / pointer['cycle_id']
        recovery = json.loads((new_dir / 'carried-receipt-recovery.json').read_text())
        self.assertEqual(recovery['kind'], 'gm_observe_carried_receipt_recovery')
        self.assertTrue(recovery['no_new_model_call'])
        self.assertEqual(recovery['source_cycle_id'], source_dir.name)
        self.assertEqual(recovery['carried_model_calls'], 10)
        self.assertEqual(recovery['carried_status'], 'no_action')
        self.assertEqual(recovery['receipt']['run_id'], 'run-1')
        document = json.loads((new_dir / 'cycle.json').read_text())
        self.assertEqual(document['status'], 'no_action')
        self.assertEqual(document['model_calls'], 0)
        self.assertEqual(document['stages']['observe']['carried_from_cycle'], source_dir.name)
        self.assertTrue(document['stages']['observe']['no_new_model_call'])
        self.assertEqual(again, 0, 'the next cycle closes as no_action with no dispatch')

    def test_recovery_refuses_a_record_whose_receipt_does_not_prove_completion(self):
        observe_receipt_fixture(self.cycle, evidence={'world_id': WORLD, 'sha256': '0' * 64})
        cycle = self._source_cycle()
        code = self._recover(cycle['cycle_id'])
        self.assertNotEqual(code, 0)
        self.assertEqual([path.name for path in self.cycle.autonomy_dir().iterdir()
                          if path.is_dir() and path.name.startswith('auto-')], [cycle['cycle_id']],
                         'a refused recovery writes no new cycle')

    def test_recovery_refuses_a_record_without_a_nested_child_failure(self):
        observe_receipt_fixture(self.cycle)
        record = {'status': 'failed', 'exit_code': 0, 'wrapper_exit_code': 0,
                  'observed_nonzero_member_exits': [], 'timed_out': False, 'seconds': 0.1,
                  'run_id': 'run-1', 'dispatched': 10,
                  'owned': {'wrapper_pid': 4242, 'active_processes': 0, 'all_members_exited': True,
                            'observed_members': [{'pid': 4242, 'running': False, 'exit_code': 0}]}}
        cycle = self._source_cycle(record)
        self.assertNotEqual(self._recover(cycle['cycle_id']), 0)

    def test_recovery_uses_the_real_retained_record_shape(self):
        # The retained record from the real blocked run carries no top-level wrapper_exit_code and
        # no observed_nonzero_member_exits: the wrapper's own exit is only in owned.observed_members
        # (keyed by owned.wrapper_pid) and the nested failures only in owned.observed_nonzero_exits.
        observe_receipt_fixture(self.cycle)
        members = [{'pid': 603976, 'running': False, 'exit_code': 0},
                   {'pid': 593108, 'running': False, 'exit_code': 1},
                   {'pid': 589796, 'running': False, 'exit_code': 1}]
        record = {'status': 'failed', 'exit_code': 1, 'timed_out': False, 'seconds': 102.8,
                  'stderr_tail': '', 'run_id': 'run-1', 'dispatched': 10,
                  'model_calls_observed': 10, 'unknown_cost_gms': None,
                  'in_flight': {'stage': 'observe', 'model_calls_reserved': 10,
                                'reserved_utc': '2026-09-14T03:44:17.589397+00:00'},
                  'blocked_reason': 'gm_runner observe failed',
                  'owned': {'containment': 'windows_kill_on_close_job', 'wrapper_pid': 603976,
                            'observed_members': members, 'total_assigned_processes': 293,
                            'active_processes': 0, 'all_members_exited': True,
                            'all_member_exit_codes_known': False,
                            'member_identity_list_complete': False,
                            'observed_nonzero_exits': [dict(item) for item in members
                                                       if item['exit_code']]}}
        cycle = self._source_cycle(record)
        dispatch = []
        original = gm_autonomy.run_process
        gm_autonomy.run_process = lambda *args, **kwargs: dispatch.append(args)
        try:
            code = self._recover(cycle['cycle_id'])
        finally:
            gm_autonomy.run_process = original
        self.assertEqual(code, 0, 'the real retained shape is a carried receipt')
        self.assertFalse(dispatch, 'carrying a receipt never dispatches a command')
        pointer = json.loads((self.cycle.autonomy_dir() / 'current.json').read_text())
        document = json.loads((self.cycle.autonomy_dir() / pointer['cycle_id'] /
                               'cycle.json').read_text())
        self.assertEqual(document['status'], 'no_action')
        self.assertEqual(document['stages']['observe']['carried_receipt']['dispatched'], 10)
        self.assertNotIn('in_flight', document['stages']['observe'],
                         'the settled stale reservation is not carried as pending work')
        # ... but a wrapper that itself exited nonzero is never carried, however many children failed.
        observe_receipt_fixture(self.cycle, run_id='run-2')
        bad = dict(record, run_id='run-2')
        bad['owned'] = dict(record['owned'], observed_members=[
            dict(item, exit_code=1) if item['pid'] == 603976 else item
            for item in record['owned']['observed_members']])
        refused = self._source_cycle(bad)
        self.assertNotEqual(self._recover(refused['cycle_id']), 0)

    def test_a_second_recovery_returns_the_same_one_and_keeps_the_source_history(self):
        observe_receipt_fixture(self.cycle)
        cycle = self._source_cycle()
        source_dir = self.cycle.cycle_dir()
        before = {name: gm_runner.sha256_file(source_dir / name)
                  for name in ('cycle.json', 'report.json')}
        first = self._recover(cycle['cycle_id'])
        pointer = gm_runner.sha256_file(self.cycle.autonomy_dir() / 'current.json')
        markers = sorted(path.name for path in (self.cycle.autonomy_dir() / 'recoveries').iterdir())
        recorded = json.loads((self.cycle.autonomy_dir() / 'recoveries' /
                               markers[0]).read_text(encoding='utf-8'))
        second, text = self._recover_text(cycle['cycle_id'])
        self.assertEqual((first, second), (0, 0))
        self.assertNotIn('refused', text, 'the repeat is the recorded recovery, not a new one')
        self.assertEqual(len(markers), 1, 'one stable source-cycle + receipt identity')
        self.assertTrue(markers[0].startswith('rec-') and markers[0].endswith('.json')
                        and len(markers[0]) == len('rec-') + 16 + len('.json'))
        self.assertEqual(gm_runner.sha256_file(self.cycle.autonomy_dir() / 'current.json'),
                         pointer, 'the second call moves no pointer')
        self.assertEqual(sorted(path.name for path in self.cycle.autonomy_dir().iterdir()
                                if path.is_dir() and path.name.startswith('auto-')),
                         sorted([source_dir.name, recorded['new_cycle_id']]),
                         'exactly one recovery cycle exists')
        self.assertEqual({name: gm_runner.sha256_file(source_dir / name)
                          for name in ('cycle.json', 'report.json')}, before,
                         'the failed cycle and its report stay untouched history')

    def test_a_competing_owner_refuses_through_the_existing_lock(self):
        observe_receipt_fixture(self.cycle)
        cycle = self._source_cycle()
        with self.cycle.cycle_lock():
            code, text = self._recover_text(cycle['cycle_id'])
        self.assertEqual(code, gm_autonomy.LOCK)
        self.assertIn('lock_held', text)
        self.assertFalse((self.cycle.autonomy_dir() / 'recoveries').exists(),
                         'a refused recovery records nothing')
        self.assertEqual([path.name for path in self.cycle.autonomy_dir().iterdir()
                          if path.is_dir()], sorted(['cycle-owner', cycle['cycle_id']]))

    def test_recovery_refuses_a_timed_out_deadline_or_unknown_record(self):
        observe_receipt_fixture(self.cycle)
        cases = {'timed out': {'timed_out': True},
                 'deadline expired': {'deadline_exceeded': True},
                 'ambiguous: no timed_out flag': {'timed_out': None},
                 'unknown cost GMs': {'unknown_cost_gms': ['gm-01']}}
        for name, change in cases.items():
            with self.subTest(case=name):
                record = dict(self._source_cycle()['stages']['observe'])
                record.update(change)
                if change.get('timed_out') is None and 'timed_out' in change:
                    record.pop('timed_out')
                cycle = self._source_cycle(record)
                code, text = self._recover_text(cycle['cycle_id'])
                self.assertNotEqual(code, 0, name)
                self.assertIn('observe_recovery_refused', text, name)
                self.assertFalse((self.cycle.autonomy_dir() / 'recoveries').exists(), name)

    def test_recovery_refuses_a_contradictory_durable_result(self):
        cases = {'nonzero measured exit': {'exit_code': 1},
                 'unmeasured cost': {'cost': 'none'},
                 'usage not measured': {'usage_measured': False}}
        for name, change in cases.items():
            with self.subTest(case=name):
                receipt = observe_receipt_fixture(self.cycle)
                receipt['results'][0].update(change)
                write_json(self.cycle.state_dir / 'runs' / 'run-1' / 'run.json', receipt)
                cycle = self._source_cycle()
                code, text = self._recover_text(cycle['cycle_id'])
                self.assertNotEqual(code, 0, name)
                self.assertIn('observe_recovery_refused', text, name)

    def test_recovery_refuses_current_unknown_usage(self):
        observe_receipt_fixture(self.cycle)
        cycle = self._source_cycle()
        state = gm_runner.blank_state()
        state['world_id'] = WORLD
        state['sessions'] = {'gm-01': {'unresolved': {'kind': 'unknown_cost', 'run_id': 'run-1'}}}
        gm_runner.store_state(self.cycle.state_dir, state)
        self.assertEqual(gm_runner.global_unknown_gms(state), ['gm-01'])
        code, text = self._recover_text(cycle['cycle_id'])
        self.assertNotEqual(code, 0)
        self.assertIn('unknown-cost', text)
        self.assertFalse((self.cycle.autonomy_dir() / 'recoveries').exists())

    def test_recovery_refuses_a_source_cycle_that_still_carries_unknown_usage(self):
        observe_receipt_fixture(self.cycle)
        cycle = self._source_cycle()
        cycle['unknown'] = {'stage': 'observe', 'exit_code': None}
        self.cycle.save_cycle(cycle)
        code, text = self._recover_text(cycle['cycle_id'])
        self.assertNotEqual(code, 0)
        self.assertIn('unresolved unknown usage', text)
        self.assertFalse((self.cycle.autonomy_dir() / 'recoveries').exists())

    def test_recovery_refuses_a_cycle_that_still_owes_a_claimed_scope(self):
        observe_receipt_fixture(self.cycle)
        cycle = self._source_cycle()
        state = gm_runner.blank_state()
        state['world_id'] = WORLD
        state['issues'] = {'issue-1': {'issue_id': 'issue-1', 'owner_gm': 'gm-01',
                                       'owner_run_id': 'run-1', 'proposed_scope': {'files': []}}}
        gm_runner.store_state(self.cycle.state_dir, state)
        self.assertNotEqual(self._recover(cycle['cycle_id']), 0)


class WatchCoordinatorTests(CorrectionBase):
    def _finished_cycle(self, deferred):
        cycle = self.cycle.load_cycle()
        cycle['status'] = 'completed'
        cycle['exit_code'] = 0
        cycle['deferred_claims'] = deferred
        self.cycle.save_cycle(cycle)
        return cycle

    def _watch_args(self):
        import argparse
        return argparse.Namespace(
            policy=self.policy_path, state_dir=self.cycle.state_dir, max_iterations=3,
            max_seconds=120, max_calls=0, idle_exits=1, interval=0.0,
            reset_watch_budget=True, config=None, key_file=None, codex=None, codex_home=None,
            timeout=60)

    def test_an_unchanged_finished_cycle_makes_no_model_call(self):
        self._finished_cycle([])
        import io
        import contextlib
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = gm_autonomy.command_watch(self._watch_args())
        summary = json.loads(buffer.getvalue().strip().splitlines()[-1])
        self.assertEqual(code, gm_autonomy.OK)
        self.assertTrue(summary['reason'].startswith('idle'))
        self.assertEqual(summary['iterations'], 1)
        self.assertEqual(summary['model_calls'], 0)

    def test_deferred_claims_start_a_later_generation_instead_of_being_swallowed(self):
        finished = self._finished_cycle([{'gm_id': 'gm-07', 'issue_id': 'issue-1'}])
        self.assertEqual(self.cycle.bump_generation(), 1)
        # A plain rerun must stay idempotent: unchanged evidence never costs another call.
        self.assertIsNotNone(self.cycle.unfinished_cycle())
        later = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None,
                                  allow_deferred_advance=True)
        self.assertNotEqual(later.cycle_dir(), self.cycle.cycle_dir())
        self.assertIsNone(later.unfinished_cycle())
        self.assertEqual(gm_runner.load_json(self.cycle.generation_path())['generation'], 1)
        self.assertEqual(finished['status'], 'completed')

    def test_watch_budget_is_preserved_across_resumes(self):
        self._finished_cycle([])
        import argparse
        import io
        import contextlib
        args = self._watch_args()
        args.reset_watch_budget = True
        with contextlib.redirect_stdout(io.StringIO()):
            gm_autonomy.command_watch(args)
        ledger = gm_runner.load_json(self.cycle.autonomy_dir() / 'watch.json')
        self.assertEqual(ledger['iterations'], 1)
        args.reset_watch_budget = False
        args.max_iterations = 5
        with contextlib.redirect_stdout(io.StringIO()):
            code = gm_autonomy.command_watch(args)
        self.assertEqual(code, gm_autonomy.OK)
        resumed = gm_runner.load_json(self.cycle.autonomy_dir() / 'watch.json')
        # The pinned first-run budget (3) is preserved; the later --max-iterations=5 is ignored.
        # Iterations accumulate across resumes instead of resetting to zero.
        self.assertEqual(resumed['max_iterations'], 3)
        self.assertEqual(resumed['iterations'], 2)


class DeadlineAndLockTests(CorrectionBase):
    def test_an_expired_pinned_deadline_starts_no_process(self):
        import time
        outcome = gm_autonomy.run_process([sys.executable, '-c', 'print("should not run")'], 5,
                                          deadline=time.time() - 1)
        self.assertTrue(outcome['deadline_exceeded'])
        self.assertTrue(outcome['timed_out'])
        self.assertEqual(outcome['owned']['containment'], 'not_started_deadline')
        self.assertEqual(outcome['owned']['observed_members'], [])
        self.assertEqual(outcome['stdout'], '')

    def test_the_installation_lock_is_shared_by_deployment_not_state_dir(self):
        second = json.loads(json.dumps(self.policy))
        second['paths']['state_dir'] = str(self.root / 'state2')
        second_path = write_json(self.root / 'policy2.json', second)
        other = gm_autonomy.Cycle(second_path, gm_runner.read_autonomy_policy(second_path), {},
                                  None)
        self.assertNotEqual(other.autonomy_dir(), self.cycle.autonomy_dir())
        self.assertEqual(other.installation_lock().directory,
                         self.cycle.installation_lock().directory)
        with self.cycle.installation_lock():
            with self.assertRaises(RuntimeError):
                other.installation_lock().__enter__()

    @unittest.skipUnless(os.name == 'nt', 'Windows path aliasing')
    def test_equivalent_windows_spellings_share_one_installation_lock(self):
        lower = self.root / 'DeploymentNotYetCreated'
        upper = Path(str(lower).upper())
        first_policy = json.loads(json.dumps(self.policy))
        first_policy['deployment']['checkout'] = str(lower)
        second_policy = json.loads(json.dumps(self.policy))
        second_policy['deployment']['checkout'] = str(upper)
        first_path = write_json(self.root / 'policy-alias-1.json', first_policy)
        second_path = write_json(self.root / 'policy-alias-2.json', second_policy)
        first = gm_autonomy.Cycle(first_path, gm_runner.read_autonomy_policy(first_path), {}, None)
        second = gm_autonomy.Cycle(second_path, gm_runner.read_autonomy_policy(second_path), {},
                                   None)
        self.assertNotEqual(str(first.checkout), str(second.checkout))
        self.assertEqual(first.installation_lock().directory, second.installation_lock().directory)
        other_policy = json.loads(json.dumps(self.policy))
        other_policy['deployment']['checkout'] = str(self.root / 'SomewhereElse')
        other_path = write_json(self.root / 'policy-alias-3.json', other_policy)
        away = gm_autonomy.Cycle(other_path, gm_runner.read_autonomy_policy(other_path), {}, None)
        self.assertNotEqual(away.installation_lock().directory,
                            first.installation_lock().directory)


    def test_settle_keeps_the_reservation_until_the_stage_finishes(self):
        cycle = self.cycle.load_cycle()
        record = {}
        self.cycle.reserve(cycle, record, 'observe', 3)
        self.assertEqual(cycle['model_calls'], 3)
        self.cycle.settle(cycle, record, 2)
        self.assertIn('in_flight', record, 'a crash before the result save must stay in flight')
        self.assertEqual(cycle['model_calls'], 2)
        self.cycle.finish_stage(cycle, 'observe', record)
        self.assertNotIn('in_flight', record)


class FeedbackContractTests(unittest.TestCase):
    def _answer(self, **overrides):
        answer = {'gm_id': 'gm-02', 'acknowledged': True, 'decision': 'accept',
                  'next_work': 'watch the next resident episode', 'receipt_sha256': 'abc123'}
        answer.update(overrides)
        return answer

    def test_a_feedback_acknowledgement_must_echo_the_receipt_digest(self):
        accepted, errors = gm_runner.validate_feedback_output(self._answer(), 'gm-02', 'abc123')
        self.assertEqual(errors, [])
        self.assertEqual(accepted['receipt_sha256'], 'abc123')
        for bad in ('missing', 'stale', None):
            answer = self._answer()
            if bad == 'missing':
                answer.pop('receipt_sha256')
            else:
                answer['receipt_sha256'] = bad
            with self.subTest(bad=bad):
                _, errors = gm_runner.validate_feedback_output(answer, 'gm-02', 'abc123')
                self.assertTrue(errors)


class RepairLoopTests(CorrectionBase):
    """The reopened-repair-round contract: a truthful, owned failure may advance once; guard
    refusals, unknown accounting and installed-but-unused never do, and no counter is reset."""

    def repair_ready_cycle(self, blocked_reason='runtime_verification_failed', stage='verify',
                           checks=None, feedback_status='done', unknown=None, attempts=None,
                           installed_but_unused=False):
        cycle = self.cycle.load_cycle()
        cycle['gm_id'] = 'gm-02'
        cycle['issue_id'] = 'issue-1'
        cycle['status'] = 'blocked'
        cycle['blocked_reason'] = blocked_reason
        cycle['feedback_attempts_total'] = 0
        cycle['stages']['candidate'] = {
            'status': 'done',
            'attempts': list(attempts) if attempts is not None else [{'attempt': 1, 'status': 'ok'}]}
        cycle['stages']['validate'] = {'status': 'done', 'ok': True}
        cycle['stages']['publish'] = {'status': 'done', 'release_digest': 'digest-1'}
        if stage == 'verify':
            cycle['stages']['verify'] = {
                'status': 'failed', 'ok': False, 'installed': True,
                'used': not installed_but_unused, 'installed_but_unused': installed_but_unused,
                'reason': blocked_reason,
                'checks': list(checks) if checks is not None else [
                    {'check': 'runtime_reports_ok', 'ok': False},
                    {'check': 'used_not_invented', 'ok': True}]}
        feedback = {'status': feedback_status}
        if feedback_status == 'done':
            feedback['acknowledgement'] = {'acknowledged': True, 'decision': 'repair',
                                           'next_work': 'repair the reported defect'}
        elif feedback_status == 'failed':
            feedback['reason'] = 'the owning GM did not return a structured acknowledgement'
        cycle['stages']['feedback'] = feedback
        if unknown:
            cycle['unknown'] = unknown
        return cycle

    def test_a_truthful_runtime_defect_with_an_accepted_repair_reopens_the_round(self):
        cycle = self.repair_ready_cycle()
        self.assertTrue(self.cycle.advance_repair(cycle))
        self.assertEqual(cycle['status'], 'running')
        self.assertIsNone(cycle['blocked_reason'])
        self.assertEqual(cycle['repair_rounds'], 1)
        self.assertEqual({name: stub['status'] for name, stub in cycle['stages'].items()
                          if name in ('candidate', 'validate', 'publish', 'verify', 'feedback')},
                         {'candidate': 'pending', 'validate': 'pending', 'publish': 'pending',
                          'verify': 'pending', 'feedback': 'pending'})
        history = cycle['repair_history'][0]
        self.assertEqual(history['failed_stage'], 'verify')
        self.assertEqual(history['blocked_reason'], 'runtime_verification_failed')
        self.assertEqual(history['decision'], 'repair')
        self.assertEqual(history['failed_checks'], ['runtime_reports_ok'])
        self.assertEqual(history['previous_stages']['verify']['checks'][0]['ok'], False)
        self.assertEqual(history['previous_stages']['publish']['release_digest'], 'digest-1')
        self.assertEqual(cycle['carried_attempts'], {'issue-1': 1})

    def test_installed_but_unused_is_never_forced_into_a_repair(self):
        cycle = self.repair_ready_cycle(blocked_reason='installed_but_unused',
                                        installed_but_unused=True,
                                        checks=[{'check': 'used_not_invented', 'ok': False}])
        self.assertFalse(self.cycle.advance_repair(cycle))
        self.assertNotIn('repair_rounds', cycle)

    def test_guard_scope_conflict_and_drift_refusals_never_retry(self):
        for stage, reason in (('publish', 'release_conflict'),
                              ('publish', 'candidate_bytes_changed_after_gate'),
                              ('publish', 'publish_journal_conflict'),
                              ('candidate', 'scope_rejected_by_policy'),
                              ('candidate', 'host_test_command_invalid'),
                              ('validate', 'deployment_checkout_inside_dev_checkout'),
                              ('verify', 'installed_but_unused')):
            for status in ('refused', 'failed'):
                with self.subTest(stage=stage, reason=reason, status=status):
                    self.assertFalse(self.cycle.repairable_failure(
                        {'stage': stage, 'status': status, 'blocked_reason': reason,
                         'failed_checks': []}))

    def test_candidate_test_exhaustion_and_missing_facts_never_retry(self):
        self.assertFalse(self.cycle.repairable_failure(
            {'stage': 'candidate', 'status': 'failed', 'failed_checks': [],
             'blocked_reason': 'max_attempts_per_issue reached without passing host tests'}))
        self.assertFalse(self.cycle.repairable_failure({}))
        self.assertFalse(self.cycle.repairable_failure(
            {'stage': 'verify', 'status': 'unknown', 'blocked_reason': 'runtime_verification_failed',
             'failed_checks': []}))
        self.assertTrue(self.cycle.repairable_failure(
            {'stage': 'validate', 'status': 'failed', 'blocked_reason': 'host_gate_refused_candidate',
             'failed_checks': ['host_test_commands_pass']}))
        self.assertFalse(self.cycle.repairable_failure(
            {'stage': 'validate', 'status': 'failed', 'blocked_reason': 'host_gate_refused_candidate',
             'failed_checks': ['host_test_commands_pass', 'candidate_changes_within_scope']}))

    def test_inconclusive_runtime_evidence_never_reopens_a_repair_round(self):
        conclusive = {'stage': 'verify', 'status': 'failed',
                      'blocked_reason': 'runtime_verification_failed',
                      'failed_checks': ['every_phase_reported_ok', 'runtime_reports_ok',
                                        'installed', 'used_not_invented']}
        self.assertTrue(self.cycle.repairable_failure(conclusive))
        # Same declared reason, one integrity check failing: a timeout, missing/stale output, a
        # foreign nonce/world/release/issue or a child process that has not exited.
        for check in ('every_phase_bound_to_this_release', 'no_phase_timed_out',
                      'owned_processes_exited', 'fresh_output_for_this_nonce',
                      'release_digest_matches', 'world_id_matches', 'issue_id_matches'):
            with self.subTest(check=check):
                self.assertFalse(self.cycle.repairable_failure(
                    dict(conclusive, failed_checks=['runtime_reports_ok', check])))
        self.assertFalse(self.cycle.repairable_failure(
            {'stage': 'verify', 'status': 'failed',
             'blocked_reason': 'runtime_verification_inconclusive',
             'failed_checks': ['no_phase_timed_out']}))
        self.assertFalse(self.cycle.repairable_failure(
            {'stage': 'verify', 'status': 'failed',
             'blocked_reason': 'runtime_verification_failed',
             'failed_checks': ['runtime_reports_ok', 'unexpected_new_check']}))
        self.assertFalse(self.cycle.repairable_failure(
            {'stage': 'verify', 'status': 'failed',
             'blocked_reason': 'runtime_verification_failed', 'failed_checks': []}))

    def test_unknown_in_flight_and_failed_feedback_never_reopen_work(self):
        for cycle in (self.repair_ready_cycle(unknown={'stage': 'feedback'}),
                      self.repair_ready_cycle(feedback_status='unknown'),
                      self.repair_ready_cycle(feedback_status='failed'),
                      self.repair_ready_cycle(feedback_status='refused')):
            with self.subTest(unknown=cycle.get('unknown'),
                              feedback=cycle['stages']['feedback']['status']):
                self.assertFalse(self.cycle.advance_repair(cycle))
                self.assertNotIn('repair_rounds', cycle)
        blocked = self.repair_ready_cycle()
        blocked['repair_blocked'] = 'already reopened once'
        self.assertFalse(self.cycle.advance_repair(blocked))

    def test_the_round_bound_and_attempt_carry_hold_across_two_rounds(self):
        self.cycle.limits['max_repair_rounds'] = 2
        cycle = self.repair_ready_cycle()
        cycle['feedback_attempts_total'] = 1
        self.assertTrue(self.cycle.advance_repair(cycle))
        self.assertEqual(cycle['carried_attempts'], {'issue-1': 1})
        self.assertEqual(cycle['feedback_attempts_total'], 1)
        cycle['status'] = 'blocked'
        cycle['blocked_reason'] = 'runtime_verification_failed'
        cycle['stages']['candidate'] = {'status': 'done',
                                        'attempts': [{'attempt': 2, 'status': 'ok'}]}
        cycle['stages']['verify'] = {'status': 'failed', 'ok': False,
                                     'checks': [{'check': 'runtime_reports_ok', 'ok': False}]}
        cycle['stages']['feedback'] = {'status': 'done', 'acknowledgement': {
            'acknowledged': True, 'decision': 'repair', 'next_work': 'repair again'}}
        self.assertTrue(self.cycle.advance_repair(cycle))
        self.assertEqual(cycle['repair_rounds'], 2)
        self.assertEqual(cycle['carried_attempts'], {'issue-1': 2})
        cycle['stages']['candidate']['attempts'] = [{'attempt': 3, 'status': 'ok'}]
        self.assertFalse(self.cycle.advance_repair(cycle))
        self.assertEqual(cycle['repair_rounds'], 2)
        self.assertEqual(len(cycle['repair_history']), 2)

    def test_a_reopened_round_resumes_instead_of_being_reported_terminal(self):
        cycle = self.repair_ready_cycle()
        self.assertTrue(self.cycle.advance_repair(cycle))
        reopened_id = self.cycle.cycle_dir().name
        restarted = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        restarted.autonomy_dir().mkdir(parents=True, exist_ok=True)
        self.assertIsNone(restarted.unfinished_cycle())
        resumed = restarted.load_cycle()
        self.assertEqual(resumed['cycle_id'], reopened_id)
        self.assertEqual(resumed['status'], 'running')
        self.assertEqual(resumed['repair_rounds'], 1)
        self.assertEqual(resumed['carried_attempts'], {'issue-1': 1})
        self.assertEqual(resumed['stages']['verify']['status'], 'pending')
        self.assertEqual(resumed['repair_history'][0]['previous_stages']['verify']['status'],
                         'failed')

    def stage_feedback_with(self, cycle, mutate=None, exit_code=0, timeout=False):
        # These cases test the host's evaluation of one transport answer, so the feedback stage
        # starts pending even when the caller built a cycle that already carries an acknowledgement.
        cycle['stages']['feedback'] = {'status': 'pending'}

        def fake(command, limit, cwd=None, deadline=None):
            index = list(command).index('--receipt-file')
            summary = {'status': 'ok', 'gm_id': 'gm-02', 'acknowledged': True,
                       'decision': 'repair', 'next_work': 'repair the reported defect',
                       'usage_measured': True,
                       'receipt_sha256': gm_runner.sha256_file(Path(command[index + 1]))}
            if mutate:
                mutate(summary)
            return {'exit_code': exit_code, 'timed_out': timeout, 'seconds': 0.01,
                    'owned': {'all_members_exited': True}, 'stdout': json.dumps(summary) + '\n',
                    'stderr': ''}
        original = gm_autonomy.run_process
        gm_autonomy.run_process = fake
        try:
            return self.cycle.stage_feedback(cycle)
        finally:
            gm_autonomy.run_process = original

    def test_an_absent_or_stale_receipt_digest_is_not_an_acknowledgement(self):
        cases = {'absent': lambda summary: summary.pop('receipt_sha256'),
                 'none': lambda summary: summary.update({'receipt_sha256': None}),
                 'stale': lambda summary: summary.update({'receipt_sha256': 'deadbeef'})}
        for name, mutate in cases.items():
            with self.subTest(case=name):
                cycle = self.repair_ready_cycle()
                self.assertEqual(self.stage_feedback_with(cycle, mutate), gm_autonomy.RUNTIME)
                self.assertEqual(cycle['blocked_reason'], 'feedback_receipt_binding_mismatch')
                self.assertFalse(self.cycle.advance_repair(cycle))

    def test_unmeasured_foreign_or_failed_feedback_is_not_accepted(self):
        cases = [('unmeasured', lambda summary: summary.update({'usage_measured': False}),
                  'feedback_usage_not_measured', gm_autonomy.ACCOUNTING),
                 ('absent_usage', lambda summary: summary.pop('usage_measured'),
                  'feedback_usage_not_measured', gm_autonomy.ACCOUNTING),
                 ('foreign_owner', lambda summary: summary.update({'gm_id': 'gm-07'}),
                  'feedback_owner_mismatch', gm_autonomy.RUNTIME),
                 ('bad_status', lambda summary: summary.update({'status': 'invalid_output'}),
                  'feedback_transport_failed_not_accepted', gm_autonomy.RUNTIME)]
        for name, mutate, reason, expected in cases:
            with self.subTest(case=name):
                cycle = self.repair_ready_cycle()
                self.assertEqual(self.stage_feedback_with(cycle, mutate), expected)
                self.assertEqual(cycle['blocked_reason'], reason)
                self.assertFalse(self.cycle.advance_repair(cycle))
        cycle = self.repair_ready_cycle()
        self.assertEqual(self.stage_feedback_with(cycle, None, exit_code=1), gm_autonomy.RUNTIME)
        self.assertEqual(cycle['blocked_reason'], 'feedback_transport_failed_not_accepted')

    def test_an_exactly_bound_measured_repair_acknowledgement_advances_the_round(self):
        cycle = self.repair_ready_cycle()
        self.assertEqual(self.stage_feedback_with(cycle), gm_autonomy.OK)
        record = cycle['stages']['feedback']
        self.assertEqual(record['status'], 'done')
        self.assertEqual(record['acknowledgement']['decision'], 'repair')
        self.assertEqual(cycle['feedback_attempts_total'], 1)
        self.assertTrue(self.cycle.advance_repair(cycle))
        self.assertEqual(cycle['repair_rounds'], 1)

    def test_the_feedback_attempt_bound_is_cumulative_not_per_round(self):
        self.cycle.limits['max_feedback_attempts'] = 1
        cycle = self.repair_ready_cycle()
        cycle['feedback_attempts_total'] = 1
        self.assertEqual(self.stage_feedback_with(cycle), gm_autonomy.ACCOUNTING)
        self.assertEqual(cycle['blocked_reason'], 'feedback_not_acknowledged_after_max_attempts')


class WatchSafetyTests(CorrectionBase):
    """The bounded watch coordinator's own safety rails, not the stage plumbing again."""

    def _watch_args(self, **overrides):
        import argparse
        values = dict(policy=self.policy_path, state_dir=self.cycle.state_dir, max_iterations=3,
                      max_seconds=120, max_calls=0, idle_exits=1, interval=0.0,
                      reset_watch_budget=False, config=None, key_file=None, codex=None,
                      codex_home=None, timeout=60)
        values.update(overrides)
        return argparse.Namespace(**values)

    def _finished(self, deferred, turns=0, status='completed', exit_code=0, reason=None):
        cycle = self.cycle.load_cycle()
        cycle['status'] = status
        cycle['exit_code'] = exit_code
        cycle['deferred_claims'] = deferred
        cycle['model_calls'] = turns
        cycle['blocked_reason'] = reason
        self.cycle.save_cycle(cycle)
        return cycle

    def _watch(self, **overrides):
        import contextlib
        import io
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = gm_autonomy.command_watch(self._watch_args(**overrides))
        lines = [line for line in buffer.getvalue().strip().splitlines() if line]
        return code, json.loads(lines[-1]) if lines else None

    def _ledger(self):
        return gm_runner.load_json(self.cycle.autonomy_dir() / 'watch.json')

    def test_a_second_concurrent_watch_invocation_cannot_spend_the_same_budget(self):
        self._finished([])
        with self.cycle.watch_lock():
            code, payload = self._watch(reset_watch_budget=True)
        self.assertEqual(code, gm_autonomy.LOCK)
        self.assertEqual(payload['kind'], 'watch_lock_held')
        self.assertFalse((self.cycle.autonomy_dir() / 'watch.json').exists(),
                         'a refused concurrent watch must not create or spend the budget')

    def test_a_blocked_cycle_returns_its_own_nonzero_status_and_stops(self):
        self._finished([], status='blocked', exit_code=5, reason='observe_failed')
        code, summary = self._watch(reset_watch_budget=True)
        self.assertEqual(code, 5)
        self.assertEqual(summary['status'], 'stopped')
        self.assertTrue(summary['reason'].startswith('cycle_blocked'), summary['reason'])
        self.assertEqual(summary['stopped_cycle']['status'], 'blocked')
        self.assertEqual(summary['stopped_cycle']['exit_code'], 5)
        self.assertEqual(summary['iterations'], 1)
        self.assertEqual(summary['gm_turns'], 0)

    def test_an_interrupted_unknown_call_stops_and_is_never_zeroed(self):
        cycle = self.cycle.load_cycle()
        cycle['model_calls'] = 4
        cycle['unknown'] = {'stage': 'observe', 'reserved': {'model_calls_reserved': 4}}
        cycle['stages']['observe'] = {'status': 'unknown', 'in_flight': {
            'stage': 'observe', 'model_calls_reserved': 4, 'reserved_utc': 'x'}}
        self.cycle.save_cycle(cycle)
        code, summary = self._watch(reset_watch_budget=True)
        self.assertEqual(code, gm_autonomy.ACCOUNTING)
        self.assertTrue(summary['reason'].startswith('interrupted_unknown_stop'), summary)
        self.assertEqual(summary['gm_turns'], 4,
                         'the in-flight reservation stays counted, never zeroed')
        ledger = self._ledger()
        self.assertEqual(ledger['unresolved_usage'][0]['cycle_id'], cycle['cycle_id'])
        self.assertEqual(ledger['stop_reason'], 'interrupted_unknown_stop')

    def test_a_crash_before_the_watch_ledger_save_does_not_overspend(self):
        import time
        self._finished([], turns=4)
        write_json(self.cycle.autonomy_dir() / 'watch.json', {
            'schema_version': 2, 'started_utc': '2026-09-13T00:00:00+00:00',
            'started_epoch': time.time(), 'max_iterations': 5, 'max_seconds': 120,
            'max_calls': 4, 'iterations': 0, 'idle_exits': 0, 'cycle_gm_turns': {},
            'cycle_dispatch_batches': {}, 'stopped_cycles': [], 'unresolved_usage': [],
            'history': [], 'stop_reason': None})
        code, summary = self._watch(reset_watch_budget=False)
        self.assertEqual(code, gm_autonomy.OK)
        self.assertEqual(summary['reason'], 'max_calls=4 native GM turns reached')
        self.assertEqual(summary['iterations'], 0,
                         'the stale ledger must not authorise another iteration')
        self.assertEqual(summary['gm_turns'], 4, 'the durable cycle counter is authoritative')

    def test_a_state_dir_that_disagrees_with_the_policy_is_refused(self):
        elsewhere = self.root / 'somewhere-else'
        code, payload = self._watch(reset_watch_budget=True, state_dir=elsewhere)
        self.assertEqual(code, gm_autonomy.USAGE)
        self.assertEqual(payload['kind'], 'state_dir_mismatch')
        self.assertFalse((elsewhere / 'autonomy' / 'watch.json').exists())
        self.assertFalse((self.cycle.autonomy_dir() / 'watch.json').exists())

    def test_negative_or_nonsensical_watch_limits_are_refused(self):
        cases = ({'max_iterations': -1}, {'max_seconds': -1}, {'max_calls': -1},
                 {'idle_exits': 0}, {'interval': -1.0})
        for overrides in cases:
            code, payload = self._watch(reset_watch_budget=True, **overrides)
            self.assertEqual(code, gm_autonomy.USAGE, overrides)
            self.assertEqual(payload['kind'], 'watch_limits_invalid', overrides)
        self.assertFalse((self.cycle.autonomy_dir() / 'watch.json').exists())

    def test_an_explicit_reset_preserves_history_and_unresolved_usage(self):
        import time
        write_json(self.cycle.autonomy_dir() / 'watch.json', {
            'schema_version': 2, 'started_utc': '2026-09-13T00:00:00+00:00',
            'started_epoch': time.time(), 'max_iterations': 3, 'max_seconds': 120,
            'max_calls': None, 'iterations': 7, 'idle_exits': 2, 'gm_turns_total': 4,
            'dispatch_batches_total': 2, 'cycle_gm_turns': {}, 'cycle_dispatch_batches': {},
            'stopped_cycles': [], 'stop_reason': 'interrupted_unknown_stop', 'history': [],
            'unresolved_usage': [{'cycle_id': 'auto-old', 'stage': 'observe',
                                  'in_flight': ['observe']}]})
        self._finished([])
        code, summary = self._watch(reset_watch_budget=True)
        # The carried fact's own cycle file is gone, so it can no longer be reconciled from disk:
        # a reset restarts the bound but must not silently drop it, so the watch stays stopped.
        self.assertEqual(code, gm_autonomy.ACCOUNTING)
        self.assertTrue(summary['reason'].startswith('interrupted_unknown_stop'), summary)
        ledger = self._ledger()
        self.assertEqual(ledger['history'][-1]['iterations'], 7)
        self.assertEqual(ledger['history'][-1]['stop_reason'], 'interrupted_unknown_stop')
        self.assertEqual(ledger['unresolved_usage'][0]['cycle_id'], 'auto-old',
                         'an explicit reset must not erase an unresolved usage fact')

    def test_a_missing_charged_cycle_file_stops_and_never_frees_its_allowance(self):
        import time
        cycle = self._finished([], turns=4)
        cid = cycle["cycle_id"]
        write_json(self.cycle.autonomy_dir() / "watch.json", {
            "schema_version": 2, "started_utc": "2026-09-13T00:00:00+00:00",
            "started_epoch": time.time(), "max_iterations": 3, "max_seconds": 120,
            "max_calls": None, "iterations": 0, "idle_exits": 0, "cycle_gm_turns": {cid: 4},
            "cycle_dispatch_batches": {cid: 1}, "stopped_cycles": [], "unresolved_usage": [],
            "history": [], "stop_reason": None})
        (self.cycle.cycle_dir() / "cycle.json").unlink()
        code, summary = self._watch(reset_watch_budget=False)
        self.assertEqual(code, gm_autonomy.ACCOUNTING, summary)
        self.assertTrue(summary["reason"].startswith("cycle_counter_unreadable_stop"), summary)
        self.assertEqual(summary["gm_turns"], 4, "a lost file must not free spent turns")
        self.assertEqual(summary["lost_counters"][0]["cycle_id"], cid)
        ledger = self._ledger()
        self.assertEqual(ledger["cycle_gm_turns"][cid], 4, "the recorded counter is retained")

    def test_a_corrupt_charged_cycle_file_is_reported_instead_of_skipped(self):
        import time
        cycle = self._finished([], turns=4)
        cid = cycle["cycle_id"]
        write_json(self.cycle.autonomy_dir() / "watch.json", {
            "schema_version": 2, "started_utc": "2026-09-13T00:00:00+00:00",
            "started_epoch": time.time(), "max_iterations": 3, "max_seconds": 120,
            "max_calls": None, "iterations": 0, "idle_exits": 0, "cycle_gm_turns": {cid: 4},
            "cycle_dispatch_batches": {cid: 1}, "stopped_cycles": [], "unresolved_usage": [],
            "history": [], "stop_reason": None})
        (self.cycle.cycle_dir() / "cycle.json").write_text("{not json", encoding="utf-8")
        code, summary = self._watch(reset_watch_budget=False)
        self.assertEqual(code, gm_autonomy.ACCOUNTING, summary)
        self.assertTrue(summary["reason"].startswith("cycle_counter_unreadable_stop"), summary)
        self.assertEqual(summary["gm_turns"], 4)
        self.assertTrue(summary["lost_counters"])

    def test_a_carried_unresolved_usage_stays_a_stop_when_its_cycle_file_disappears(self):
        import time
        write_json(self.cycle.autonomy_dir() / "watch.json", {
            "schema_version": 2, "started_utc": "2026-09-13T00:00:00+00:00",
            "started_epoch": time.time(), "max_iterations": 3, "max_seconds": 120,
            "max_calls": None, "iterations": 1, "idle_exits": 0, "gm_turns_total": 4,
            "dispatch_batches_total": 1, "cycle_gm_turns": {}, "cycle_dispatch_batches": {},
            "stopped_cycles": [], "stop_reason": "interrupted_unknown_stop", "history": [],
            "unresolved_usage": [{"cycle_id": "auto-gone", "stage": "observe",
                                  "in_flight": ["observe"]}]})
        self._finished([])
        code, summary = self._watch(reset_watch_budget=False)
        self.assertEqual(code, gm_autonomy.ACCOUNTING, summary)
        self.assertTrue(summary["reason"].startswith("interrupted_unknown_stop"), summary)
        ledger = self._ledger()
        carried = [item for item in ledger["unresolved_usage"]
                   if item.get("cycle_id") == "auto-gone"]
        self.assertEqual(len(carried), 1, "the carried unknown fact is preserved, never settled")
        code, summary = self._watch(reset_watch_budget=True)
        self.assertEqual(code, gm_autonomy.ACCOUNTING, summary)
        ledger = self._ledger()
        self.assertTrue(any(item.get("cycle_id") == "auto-gone"
                            for item in ledger["unresolved_usage"]),
                        "--reset-watch-budget preserves the unresolved usage fact")
        self.assertEqual(ledger["history"][-1]["stop_reason"], "interrupted_unknown_stop")

    def test_a_blocked_payload_with_exit_code_zero_is_normalized_before_the_summary(self):
        self._finished([], status="blocked", exit_code=0, reason="observe_failed")
        code, summary = self._watch(reset_watch_budget=True)
        self.assertEqual(code, gm_autonomy.RUNTIME, summary)
        self.assertEqual(summary["status"], "stopped")
        self.assertEqual(summary["last_exit_code"], gm_autonomy.RUNTIME,
                         "the JSON must not report ok/last_exit_code 0 while the command fails")
        self.assertEqual(summary["stopped_cycle"]["exit_code"], gm_autonomy.RUNTIME)
        self.assertTrue(summary["reason"].startswith("cycle_blocked"), summary["reason"])


class QueuedClaimTests(CorrectionBase):
    """A later generation consumes the queued GM-owned claim instead of re-observing."""

    def _state_with(self, owner, issue_id='proposal-2', status='proposed'):
        state = gm_runner.load_state(self.cycle.state_dir)
        state['world_id'] = WORLD
        state['issues'][issue_id] = {
            'issue_id': issue_id, 'world_id': WORLD, 'lifecycle': 'current',
            'source_status': status, 'content_digest': 'd', 'settled': {}, 'outcomes': [],
            'owner_gm': owner, 'owner_run_id': 'run-1',
            'provenance': {'observation_origin': 'autonomous_observation'},
            'proposed_scope': {'objective': 'Add correct empty-well handling for the trial well.',
                               'files': ['game/capabilities/well_stock_lookup.gd'],
                               'acceptance': ['a depleted stock returns well_stock_empty']}}
        gm_runner.store_state(self.cycle.state_dir, state)

    def _queued_cycle(self, deferred):
        cycle = self.cycle.load_cycle()
        cycle['status'] = 'completed'
        cycle['exit_code'] = 0
        cycle['deferred_claims'] = deferred
        cycle['model_calls'] = 3
        self.cycle.save_cycle(cycle)
        self.cycle.bump_generation()
        return cycle

    def _later_cycle(self):
        later = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None,
                                  allow_deferred_advance=True)
        return later, later.load_cycle()

    def _no_dispatch(self, later, cycle):
        def explode(*args, **kwargs):
            raise AssertionError('a queued claim must not pay for another observation')
        original = gm_autonomy.run_process
        gm_autonomy.run_process = explode
        try:
            return later.stage_observe(cycle)
        finally:
            gm_autonomy.run_process = original

    def test_a_queued_claim_is_consumed_without_a_new_observe(self):
        self._state_with('gm-07')
        source = self._queued_cycle([{'gm_id': 'gm-07', 'issue_id': 'proposal-2'}])
        later, cycle = self._later_cycle()
        self.assertEqual(self._no_dispatch(later, cycle), gm_autonomy.OK)
        record = cycle['stages']['observe']
        self.assertEqual(record['status'], 'done')
        self.assertEqual(cycle['issue_id'], 'proposal-2')
        self.assertEqual(cycle['gm_id'], 'gm-07', 'the original owner is preserved')
        self.assertEqual(record['queued_owner_run_id'], 'run-1')
        self.assertEqual(record['queued_from_cycle'], source['cycle_id'])
        self.assertEqual(record['observation_origin'], 'autonomous_observation')
        self.assertEqual(cycle['deferred_claims'], [])
        self.assertEqual(int(cycle.get('model_calls', 0)), 0, 'no new GM turn was spent')
        # The hand-over is durable: the same claim is never consumed twice.
        self.assertIsNone(later.queued_claim_cycle())

    def test_a_queued_claim_is_not_re_attributed_to_a_new_owner(self):
        self._state_with('gm-09')
        self._queued_cycle([{'gm_id': 'gm-07', 'issue_id': 'proposal-2'}])
        later, cycle = self._later_cycle()
        self.assertEqual(self._no_dispatch(later, cycle), gm_autonomy.OK)
        record = cycle['stages']['observe']
        self.assertEqual(record['status'], 'no_action')
        self.assertTrue(record['no_action'])
        self.assertEqual(record['queued_unresolvable'],
                         [{'gm_id': 'gm-07', 'issue_id': 'proposal-2'}])
        self.assertEqual(cycle['deferred_claims'], [],
                         'an unresolvable queue entry is reported, not silently kept forever')


class ModuleSmokeExitCodeTests(unittest.TestCase):
    """The Godot compile smoke must not accept ok=true on a nonzero process exit."""

    def setUp(self):
        self.root = WORK / 'smoke-exit'
        shutil.rmtree(self.root, ignore_errors=True)
        self.root.mkdir(parents=True)
        self.godot = self.root / 'godot.exe'
        self.godot.write_text('stub', encoding='utf-8')
        self.module = self.root / 'well_stock_lookup.gd'
        self.module.write_text('extends RefCounted' + chr(10), encoding='utf-8')

    def test_a_nonzero_godot_exit_refuses_an_ok_report(self):
        from unittest import mock

        def fake_run(command, **kwargs):
            out = [item for item in command if str(item).startswith('--out=')][0]
            Path(str(out)[6:]).write_text(json.dumps(
                {'ok': True, 'compiled': True, 'code': None, 'failures': []}), encoding='utf-8')
            return subprocess.CompletedProcess(command, 1, '', 'boom')

        with mock.patch.object(validate.subprocess, 'run', fake_run):
            report = validate.godot_module_smoke(self.module, 'game/capabilities/x.gd',
                                                 self.godot, self.root, 30)
        self.assertEqual(report['exit_code'], 1)
        self.assertFalse(report['ok'])
        self.assertTrue(any('nonzero-exit' in item for item in report['failures']), report)
        self.assertEqual(report['evidence']['ok'], True)


class VerifyBindingTests(CorrectionBase):
    """Effect observation is deferred to the owning GM's next world turn."""

    def test_a_host_script_edited_after_publication_is_never_executed(self):
        host_script = self.root / 'host_check.py'
        host_script.write_text('print("host check")' + chr(10), encoding='utf-8')
        document = json.loads(self.policy_path.read_text(encoding='utf-8'))
        document['host_owned_paths'] = [str(host_script)]
        write_json(self.policy_path, document)
        self.policy = gm_runner.read_autonomy_policy(self.policy_path)
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        write_json(self.root / 'runtime' / 'save.json', {'world_id': WORLD})
        cycle = self.publish_ready_cycle()
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        host_script.write_text('print("edited after publication")' + chr(10), encoding='utf-8')
        self.assertEqual(self.cycle.stage_verify(cycle), gm_autonomy.OK)
        self.assertTrue(cycle['stages']['verify']['effect_review_pending'])
        self.assertEqual(cycle['stages']['verify']['status'], 'pending')
        self.assertFalse(list(self.cycle.cycle_dir().glob('verify-open-*.json')))


class ProductionHostContractTests(CorrectionBase):
    def setUp(self):
        super().setUp()
        write_json(self.root / 'runtime' / 'save.json',
                   {'world_id': WORLD, 'life': {'seq': 7}, 'private': {'kept': True}})
        self.policy['mode'] = 'production'
        self.policy['runtime'] = {
            'kind': 'production_host_contract', 'godot': str(self.root / 'godot.exe'),
            'save_path': str(self.root / 'runtime' / 'save.json'), 'timeout_seconds': 30,
            'host_command': ['host-check', '--save={save_copy}', '--out={out}',
                             '--release={release_digest}', '--issue={issue_id}',
                             '--identity={issue_identity}', '--target-sha={target_sha256}',
                             '--phase={phase}'],
            'supported_issue_prefixes': ['journey_stall:'],
            'required_release_paths': ['game/spatial/**']}
        write_json(self.policy_path, self.policy)
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        self.cycle.autonomy_dir().mkdir(parents=True, exist_ok=True)

    def ready(self):
        cycle = self.cycle.load_cycle()
        cycle['issue_id'] = 'issue-real'
        cycle['stages']['publish'] = {
            'status': 'done', 'release_digest': 'release-1',
            'files': [{'source': 'game/spatial/town_street.gd',
                       'target': 'spatial/town_street.gd', 'sha256': 'target-sha'}]}
        return cycle

    def test_real_town_contract_uses_a_copy_and_never_claims_resident_adoption(self):
        cycle = self.ready()
        original = (self.root / 'runtime' / 'save.json').read_bytes()
        prior_load, prior_run = gm_runner.load_state, gm_autonomy.run_process
        commands = []
        try:
            gm_runner.load_state = lambda _path: {
                'issues': {'issue-real': {'identity_key': 'journey_stall:19'}}}
            def fake_run(command, _budget, deadline=None):
                commands.append(command)
                values = {token.split('=', 1)[0]: token.split('=', 1)[1]
                          for token in command if '=' in token}
                save_copy = Path(values['--save'])
                self.assertNotEqual(save_copy, self.root / 'runtime' / 'save.json')
                write_json(Path(values['--out']), {
                    'ok': True, 'continuation_ok': True, 'world_id': WORLD,
                    'issue_id': values['--issue'], 'issue_identity': values['--identity'],
                    'release_digest': values['--release'],
                    'source_world_sha256': gm_runner.sha256_bytes(original),
                    'loaded_target_sha256': values['--target-sha'],
                    'causal_checks': {'actual_town_job_progressed': True,
                                      'bound_issue_closed_or_progressed': True}})
                return {'exit_code': 0, 'timed_out': False, 'seconds': 0.1,
                        'stdout': '', 'stderr': '',
                        'owned': {'all_members_exited': True, 'observed_members': []}}
            gm_autonomy.run_process = fake_run
            self.assertEqual(self.cycle.stage_verify_production_host_contract(cycle),
                             gm_autonomy.OK)
        finally:
            gm_runner.load_state, gm_autonomy.run_process = prior_load, prior_run
        verify = cycle['stages']['verify']
        self.assertTrue(verify['ok'])
        self.assertFalse(verify['resident_adoption'])
        self.assertEqual((self.root / 'runtime' / 'save.json').read_bytes(), original)
        self.assertEqual(len(commands), 2)
        self.assertFalse(any('--ledger' in token or '--town-gateway' in token
                             for command in commands for token in command))

    def test_wrong_issue_family_and_inference_command_fail_before_execution(self):
        cycle = self.ready()
        prior_load, prior_run = gm_runner.load_state, gm_autonomy.run_process
        called = []
        try:
            gm_runner.load_state = lambda _path: {
                'issues': {'issue-real': {'identity_key': 'unrelated:1'}}}
            gm_autonomy.run_process = lambda *args, **kwargs: called.append(args)
            self.assertEqual(self.cycle.stage_verify_production_host_contract(cycle),
                             gm_autonomy.PRECONDITION)
            self.assertFalse(called)
            cycle = self.ready()
            gm_runner.load_state = lambda _path: {
                'issues': {'issue-real': {'identity_key': 'journey_stall:19'}}}
            self.cycle.policy['runtime']['host_command'] = [
                'python', 'tools/run_town_model_validation.py', '--out={out}']
            self.assertEqual(self.cycle.stage_verify_production_host_contract(cycle),
                             gm_autonomy.PRECONDITION)
            self.assertFalse(called)
        finally:
            gm_runner.load_state, gm_autonomy.run_process = prior_load, prior_run


class SelectedGmObserveTests(CorrectionBase):
    """`cycle --gm` forwards an explicit roster selector to gm_runner.observe only."""

    def _cycle(self, selected=None):
        return gm_autonomy.Cycle(self.policy_path, self.policy, {}, None, selected_gms=selected)

    @staticmethod
    def _flags(command, name):
        return [command[index + 1] for index, token in enumerate(command) if token == name]

    def _dispatch(self, cycle):
        """Drive one observe dispatch through an offline fake runner and capture its command."""
        seen = {}

        def fake(command, *args, **kwargs):
            seen['command'] = list(command)
            summary = {'run_id': 'run-selected', 'dispatched': 1,
                       'results': [{'gm_id': 'gm-04', 'status': 'ok', 'exit_code': 0,
                                    'usage_measured': True, 'cost': 'measured',
                                    'dispatched': True, 'usage': {'turns': 1}}]}
            return {'exit_code': 0, 'wrapper_exit_code': 0, 'timed_out': False, 'seconds': 0.1,
                    'stdout': json.dumps(summary) + '\n', 'stderr': '',
                    'owned': {'wrapper_pid': 11, 'active_processes': 0,
                              'all_members_exited': True, 'member_identity_list_complete': True,
                              'observed_members': []}}

        original = gm_autonomy.run_process
        gm_autonomy.run_process = fake
        try:
            cycle.stage_observe(cycle.load_cycle())
        finally:
            gm_autonomy.run_process = original
        return seen

    def test_observe_command_carries_only_the_requested_roster_gm(self):
        cycle = self._cycle(['gm-04'])
        seen = self._dispatch(cycle)
        self.assertTrue(seen, 'the observe dispatch reached the runner command')
        self.assertEqual(self._flags(seen['command'], '--gm'), ['gm-04'],
                         'the selector is forwarded verbatim, never expanded to the roster')
        self.assertEqual(self._flags(seen['command'], '--max-gms'), ['1'])

    def test_the_reserved_observation_count_is_one_even_though_the_roster_limit_is_higher(self):
        maximum = int(self.cycle.limits['max_gms'])
        self.assertGreater(maximum, 1)
        cycle = self._cycle(['gm-04'])
        self._dispatch(cycle)
        record = cycle.load_cycle()['stages']['observe']
        self.assertEqual(record['last_reserved']['model_calls_reserved'], 1)
        self.assertEqual(record['model_calls_observed'], 1)

    def test_default_observe_command_is_unchanged_without_a_selector(self):
        maximum = str(int(self.cycle.limits['max_gms']))
        cycle = self._cycle(None)
        seen = self._dispatch(cycle)
        self.assertTrue(seen, 'the default observe dispatch still runs')
        self.assertEqual(self._flags(seen['command'], '--gm'), [])
        self.assertEqual(self._flags(seen['command'], '--max-gms'), [maximum])

    def test_only_the_observe_dispatch_consumes_the_selector(self):
        source = Path(gm_autonomy.__file__).read_text(encoding='utf-8')
        lines = [line.strip() for line in source.splitlines() if 'self.selected_gms' in line]
        self.assertEqual(lines, [
            'self.selected_gms = ([str(item) for item in selected_gms] if selected_gms else None)',
            'if self.selected_gms:',
            'estimate = len(self.selected_gms)',
            'for gm_id in (self.selected_gms or []):'],
            'code and feedback never read the selector; the owning GM is unchanged')

    def test_the_selection_helper_keeps_order_and_the_default_stays_empty(self):
        self.assertEqual(gm_autonomy.selected_gm_selection([], self.policy), (None, None))
        refused, selected = gm_autonomy.selected_gm_selection(['gm-04', 'gm-02'], self.policy)
        self.assertIsNone(refused)
        self.assertEqual(selected, ['gm-04', 'gm-02'])
        self.assertEqual(gm_runner.GM_IDS[:2], ['gm-01', 'gm-02'],
                         'the selector is validated against the real roster')

    def _cli(self, argv):
        stream = io.StringIO()
        dispatch = []
        original = gm_autonomy.run_process
        gm_autonomy.run_process = lambda *args, **kwargs: dispatch.append(args)
        try:
            with contextlib.redirect_stdout(stream):
                code = gm_autonomy.main(argv)
        finally:
            gm_autonomy.run_process = original
        return code, stream.getvalue(), dispatch

    def test_unknown_duplicate_and_over_limit_selections_refuse_before_any_dispatch(self):
        cycles_before = sorted(path.name for path in self.cycle.autonomy_dir().iterdir())
        for extra, reason in ((['--gm', 'gm-99'], 'unknown_gm_selection'),
                              (['--gm', 'gm-04', '--gm', 'gm-04'], 'duplicate_gm_selection')):
            code, text, dispatch = self._cli(['cycle', '--policy', str(self.policy_path)] + extra)
            self.assertNotEqual(code, 0)
            self.assertIn(reason, text)
            self.assertEqual(dispatch, [], 'a refused selection dispatches nothing')
        self.policy['limits']['max_gms'] = 1
        write_json(self.policy_path, self.policy)
        code, text, dispatch = self._cli(['cycle', '--policy', str(self.policy_path),
                                          '--gm', 'gm-04', '--gm', 'gm-05'])
        self.assertNotEqual(code, 0)
        self.assertIn('gm_selection_over_limit', text)
        self.assertEqual(dispatch, [], 'an over-limit selection dispatches nothing')
        self.assertEqual(sorted(path.name for path in self.cycle.autonomy_dir().iterdir()),
                         cycles_before, 'a refused selection creates no cycle')

class MainAiReviewWorkflowTests(CorrectionBase):
    def _review_cycle(self, decision='advisory', suggestions=None, problem=None):
        cycle = self.publish_ready_cycle()
        cycle['stages']['review'] = {'status': 'pending'}
        candidate_sha = self.cycle.candidate_version_sha(cycle)
        review = {'cycle_id': cycle['cycle_id'], 'gm_id': 'gm-02',
                  'candidate_sha256': candidate_sha, 'source': 'main-ai:test',
                  'decision': decision}
        if decision == 'advisory':
            review['suggestions'] = suggestions or ['Keep the bounded acceptance evidence visible.']
        else:
            review['major_problem'] = problem or 'The candidate violates the declared world contract.'
        cycle['main_ai_review'] = review
        return cycle

    def test_missing_review_is_resumable_and_does_not_dispatch(self):
        cycle = self.publish_ready_cycle()
        cycle['stages']['review'] = {'status': 'pending'}
        cycle.pop('main_ai_review', None)
        with mock.patch.object(gm_autonomy, 'run_process', side_effect=AssertionError('no dispatch')):
            self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.OK)
        self.assertEqual(cycle['stages']['review']['status'], 'waiting_review')
        self.assertEqual(cycle['stages']['review']['review_state'], 'pending')

    def test_advisory_review_delivers_even_when_gm_self_test_failed(self):
        cycle = self._review_cycle()
        cycle['stages']['candidate']['gm_self_test'] = {
            'reported': True, 'ok': False, 'result': [{'name': 'gm-check', 'ok': False}]}
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.OK)
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        self.assertEqual(cycle['stages']['review']['review_state'], 'advisory')
        self.assertTrue((self.checkout / self.target).is_file())

    def test_major_block_requires_new_matching_review_before_release(self):
        cycle = self._review_cycle('major_block')
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.PRECONDITION)
        self.assertEqual(cycle['blocked_reason'], 'main_ai_major_block')
        cycle['stages']['review'] = {'status': 'pending'}
        cycle['main_ai_review'] = dict(cycle['main_ai_review'], decision='advisory',
                                       suggestions=['Rechecked the candidate bytes and scope.'])
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.OK)
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)

    def test_major_block_reopen_resets_review_and_creates_a_new_candidate_round(self):
        cycle = self._review_cycle('major_block')
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.PRECONDITION)
        state = gm_runner.load_state(self.cycle.state_dir)
        memory = gm_runner.gm_memory_projection(state, 'gm-02')
        review_events = [item for item in memory['task_history']
                         if item.get('kind') == 'main_ai_review']
        self.assertEqual(review_events[-1]['major_problem'],
                         'The candidate violates the declared world contract.')
        self.assertTrue(review_events[-1]['repair_required'])
        reopened = self.cycle.reopen_after_major_block(cycle)
        self.assertEqual(reopened['status'], 'running')
        self.assertEqual(reopened['repair_rounds'], 1)
        self.assertIsNone(reopened['main_ai_review'])
        self.assertEqual(reopened['stages']['review']['status'], 'pending')
        self.assertEqual(reopened['repair_history'][-1]['blocked_reason'], 'main_ai_major_block')

    def test_record_review_cli_binds_the_current_candidate_without_provider(self):
        cycle = self._review_cycle()
        cycle['main_ai_review'] = None
        cycle['stages']['review'] = {'status': 'pending'}
        self.cycle.save_cycle(cycle)
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            code = gm_autonomy.main([
                'record-review', '--policy', str(self.policy_path), '--decision', 'advisory',
                '--source', 'main-ai:test-cli', '--rationale', 'Candidate evidence was reviewed.'])
        text = stream.getvalue()
        self.assertEqual(code, gm_autonomy.OK, text)
        payload = json.loads(text)
        self.assertEqual(payload['status'], 'recorded')
        self.assertEqual(payload['review_stage'], 'done')
        self.assertFalse(payload['provider_called'])
        review_path = gm_runner.ROOT / payload['review_path']
        self.assertTrue(review_path.is_file())
        saved = gm_runner.load_json(self.cycle.cycle_dir() / 'cycle.json')
        self.assertEqual(saved['main_ai_review']['candidate_sha256'],
                         self.cycle.candidate_version_sha(saved))
        state = gm_runner.load_state(self.cycle.state_dir)
        events = [item for item in gm_runner.gm_memory_projection(state, 'gm-02')['task_history']
                  if item.get('kind') == 'main_ai_review']
        self.assertEqual(events[-1]['decision'], 'advisory')
        self.assertEqual(events[-1]['source'], 'main-ai:test-cli')

    def test_reviewed_candidate_bytes_cannot_change_before_release(self):
        cycle = self._review_cycle()
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.OK)
        write_json(self.candidate / self.rel, {'ok': True, 'tampered': True})
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.UNACCEPTABLE)
        self.assertFalse((self.checkout / self.target).exists())

    def test_four_files_are_installed_as_one_bounded_release(self):
        files = [f'game/capabilities/file-{index}.json' for index in range(4)]
        targets = [f'capabilities/file-{index}.json' for index in range(4)]
        for index, rel in enumerate(files):
            write_json(self.candidate / rel, {'index': index})
        write_json(self.root / 'base.json', {'schema_version': 1,
                                             'files': {target: None for target in targets}})
        self.policy['scope_constraints']['max_changed_files'] = 4
        self.policy['deployment']['max_files_per_release'] = 4
        write_json(self.policy_path, self.policy)
        self.cycle = gm_autonomy.Cycle(self.policy_path, self.policy, {}, None)
        cycle = self.cycle.load_cycle()
        cycle.update({'gm_id': 'gm-02', 'issue_id': 'issue-1'})
        hashes = {rel: gm_runner.sha256_file(self.candidate / rel) for rel in files}
        cycle['stages']['candidate'] = {'status': 'done', 'candidate_abs': str(self.candidate),
                                       'base_revision': 'base-rev',
                                       'host_owned_before': self.cycle.host_owned_hashes()}
        cycle['stages']['validate'] = {'status': 'done', 'ok': True, 'publish_ready': True,
                                      'file_hashes': hashes}
        cycle['stages']['review'] = {'status': 'pending'}
        cycle['main_ai_review'] = {'cycle_id': cycle['cycle_id'], 'gm_id': 'gm-02',
                                   'candidate_sha256': self.cycle.candidate_version_sha(cycle),
                                   'source': 'main-ai:test', 'decision': 'advisory',
                                   'suggestions': ['Four-file bounded delivery checked.']}
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.OK)
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        self.assertEqual([gm_runner.sha256_file(self.checkout / target) for target in targets],
                         [hashes[rel] for rel in files])

    def test_release_receipt_is_memory_feedback_without_provider_call(self):
        cycle = self._review_cycle()
        self.assertEqual(self.cycle.stage_review(cycle), gm_autonomy.OK)
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.OK)
        cycle['stages']['verify'] = {'status': 'pending', 'ok': None, 'installed': True,
                                     'used': None, 'effect_review_pending': True}
        cycle['stages']['feedback'] = {'status': 'pending'}
        with mock.patch.object(gm_autonomy, 'run_process', side_effect=AssertionError('no provider')):
            self.assertEqual(self.cycle.stage_feedback(cycle), gm_autonomy.OK)
        self.assertEqual(cycle['stages']['feedback']['status'], 'pending')
        self.assertTrue(cycle['stages']['feedback']['effect_review_pending'])
        state = gm_runner.load_state(self.cycle.state_dir)
        feedback = state['sessions']['gm-02']['memory']['host_feedback']
        self.assertEqual(len(feedback), 1)
        self.assertEqual(feedback[0]['receipt']['release_digest'],
                         cycle['stages']['publish']['release_digest'])
        self.assertEqual(feedback[0]['receipt']['outcome'], 'published_pending_gm_review')


if __name__ == '__main__':
    unittest.main(verbosity=2)
