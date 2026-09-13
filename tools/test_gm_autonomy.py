#!/usr/bin/env python3
"""Offline unit and negative-gate tests for the opt-in autonomous GM cycle.

Nothing here calls a model. These tests pin the host-side refusals that must hold before any paid
work or publication: standing-policy validation, GM-proposed scope rejection, host-owned file
protection, deployment mapping, host-derived required commands, missing-input preflight, the
explicit observation origin and durable cycle identity. Scripted end-to-end plumbing (real Godot
runtime, restart, publication) lives in tools/validate_gm_autonomy.py.
"""
import json
import os
import shutil
import subprocess
import sys
import unittest
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
        for removed in ('allowed_source_paths', 'host_owned_paths', 'required_test_commands'):
            with self.subTest(removed=removed):
                document = example_policy()
                document['scope_constraints'].pop(removed, None)
                document.pop(removed, None)
                self.assertTrue(gm_autonomy.policy_errors(document))
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
        self.assertTrue(any('only valid in production' in value
                            for value in gm_autonomy.policy_errors(policy)))


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
                                      'file_hashes': {self.rel: self.digest}}
        return cycle


class PublicationSafetyTests(CorrectionBase):
    def test_changed_candidate_bytes_are_refused_before_any_target_write(self):
        cycle = self.publish_ready_cycle()
        write_json(self.candidate / self.rel, {'ok': True, 'tampered': True})
        self.assertEqual(self.cycle.stage_publish(cycle), gm_autonomy.UNACCEPTABLE)
        self.assertEqual(cycle['blocked_reason'], 'candidate_bytes_changed_after_gate')
        self.assertFalse((self.checkout / self.target).exists())

    def test_a_multi_file_release_policy_is_refused_up_front(self):
        document = example_policy()
        document['deployment']['max_files_per_release'] = 2
        self.assertTrue(gm_autonomy.policy_errors(document))

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
    """The host script is re-bound under the installation lock before it is allowed to run."""

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
        self.assertEqual(self.cycle.stage_verify(cycle), gm_autonomy.UNACCEPTABLE)
        self.assertEqual(cycle['blocked_reason'], 'release_binding_stale_after_publish')
        self.assertEqual(cycle['stages']['verify']['status'], 'refused')
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


if __name__ == '__main__':
    unittest.main(verbosity=2)
