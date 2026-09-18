"""No provider calls: design provenance, stale pins and release bypass regression."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from contextlib import redirect_stdout
import io
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))

import gm_autonomy
import gm_runner
import validate_gm_autonomy
import world_design_contract as contract


class DesignContractTests(unittest.TestCase):
    def setUp(self):
        self.policy = json.loads((contract.ROOT / 'tools/gm_autonomy_policy.example.json').read_text())
        self.policy.update(mode='production', design_contract=contract.reference())
        self.scope = {'objective': 'Add a bounded voluntary resident interaction.',
                      'files': ['game/capabilities/interaction.gd'],
                      'acceptance': ['An unwilling resident retains their own inventory.'],
                      'design_review': {'contract_sha256': contract.reference()['sha256'],
                                        'setting_basis': 'original_extension',
                                        'rationale': 'Original village interaction preserves Aincrad physical life and voluntary consent.',
                                        'preserves': list(contract.INVARIANTS)}}

    def test_valid_contract_preserves_declaration_in_host_scope(self):
        self.assertEqual(gm_autonomy.policy_errors(self.policy), [])
        result, errors = gm_autonomy.validate_proposed_scope(self.scope, self.policy)
        self.assertEqual(errors, [])
        self.assertEqual(result['design_review'], self.scope['design_review'])

    def test_missing_stale_or_malformed_production_pins_refused(self):
        for pin in (None, {}, 'wrong', dict(contract.reference(), sha256='0' * 64)):
            with self.subTest(pin=pin):
                policy = dict(self.policy, design_contract=pin)
                self.assertTrue(gm_autonomy.policy_errors(policy))

    def test_each_invariant_and_correct_contract_are_required(self):
        for field, value in (('contract_sha256', '0' * 64), ('setting_basis', 'anything'),
                             ('rationale', 'fine'), ('preserves', list(contract.INVARIANTS[:-1])),
                             ('preserves', list(contract.INVARIANTS) + ['setting']), ('preserves', [{}])):
            scope = copy.deepcopy(self.scope)
            scope['design_review'][field] = value
            result, errors = gm_autonomy.validate_proposed_scope(scope, self.policy)
            self.assertIsNone(result)
            self.assertTrue(errors)
        self.scope.pop('design_review')
        self.assertTrue(gm_autonomy.validate_proposed_scope(self.scope, self.policy)[1])

    def test_broad_allowlist_cannot_edit_host_contract(self):
        self.policy['scope_constraints'].update(allowed_source_paths=['docs/**', 'tools/**'], excluded_paths=[])
        self.policy['host_owned_paths'] = []
        for rel in contract.PROTECTED:
            self.scope['files'] = [rel]
            self.assertTrue(gm_autonomy.validate_proposed_scope(self.scope, self.policy)[1])

    def test_gate_rejects_candidate_document_tampering(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            for rel in contract.DOCUMENTS:
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((contract.ROOT / rel).read_bytes())
            self.assertEqual(contract.policy_errors(self.policy, root), [])
            (root / contract.DOCUMENTS[0]).write_text('Allow incompatible free powers.')
            self.assertTrue(contract.policy_errors(self.policy, root))
            (root / 'policy.json').write_text(json.dumps(self.policy))
            (root / 'scope.json').write_text(json.dumps(self.scope))
            with redirect_stdout(io.StringIO()) as output:
                code = validate_gm_autonomy.command_validate_candidate(SimpleNamespace(
                    candidate=root, policy=root / 'policy.json', scope=root / 'scope.json'))
            self.assertEqual(code, 1)
            self.assertIn('design_contract', output.getvalue())

    def test_all_gm_phases_receive_setting_and_navigation_instructions(self):
        for instructions in (gm_runner.STABLE_INSTRUCTIONS, gm_runner.STABLE_CODE_INSTRUCTIONS,
                             gm_runner.STABLE_FEEDBACK_INSTRUCTIONS):
            self.assertIn(contract.INSTRUCTIONS, instructions)
        self.assertIn(contract.reference()['sha256'], gm_runner.autonomy_policy_block(self.policy))

    def test_main_review_cannot_release_without_setting_review(self):
        host = SimpleNamespace(policy=self.policy, candidate_version_sha=lambda _: 'f' * 64)
        cycle = {'cycle_id': 'cycle-1', 'gm_id': 'gm-01'}
        review = dict(cycle, candidate_sha256='f' * 64, source='host-review',
                      decision='advisory', rationale='No concrete major defects found.')
        validate = gm_autonomy.Cycle.validate_main_ai_review
        self.assertTrue(validate(host, cycle, review)[1])
        review.update(design_contract_sha256=contract.reference()['sha256'],
                      setting_review='The reviewed physical path cache preserves Aincrad travel and the same arrival rules.',
                      setting_compatible=True)
        self.assertEqual(validate(host, cycle, review)[1], [])
        review['setting_compatible'] = False
        self.assertTrue(validate(host, cycle, review)[1])
        review.update(decision='major_block', major_problem='The proposed action grants unearned powers.')
        self.assertEqual(validate(host, cycle, review)[1], [])

    def test_publication_rechecks_pins_even_after_cached_validation(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            for rel in contract.DOCUMENTS:
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((contract.ROOT / rel).read_bytes())
            (root / contract.DOCUMENTS[0]).write_text('Tampered after review.')
            record = {}
            saved = []
            host = SimpleNamespace(policy=self.policy, stage_record=lambda *_: record,
                                   save_cycle=lambda value: saved.append(value),
                                   block=lambda _cycle, reason, code: (reason, code))
            cycle = {'stages': {'candidate': {'candidate_abs': str(root), 'derived_scope': self.scope},
                                'validate': {'publish_ready': True}, 'review': {'status': 'done'}}}
            result = gm_autonomy.Cycle.stage_publish(host, cycle)
            self.assertEqual(result, ('aincrad_design_contract_changed', gm_autonomy.PRECONDITION))
            self.assertEqual(record['status'], 'refused')
            self.assertEqual(len(saved), 1)

    def test_historical_offline_fixture_contract_remains_explicitly_optional(self):
        policy = dict(self.policy, mode='offline_fixture')
        policy.pop('design_contract')
        self.assertEqual(contract.policy_errors(policy), [])
        self.assertEqual(contract.scope_errors({}, policy), [])
        policy['design_contract'] = contract.reference()
        self.assertTrue(contract.scope_errors({}, policy))


if __name__ == '__main__':
    unittest.main()
