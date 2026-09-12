"""Offline adversarial checks for the integration verifier; no engines/providers."""
import copy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

import run_ten_world_chain_validation as chain
from create_trade_fixture import shared_world_seed


class CandidateEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.world = shared_world_seed('shared:offline-verifier-test')
        self.need = {'capability_id': 'finite_iron_supply', 'reason': 'I have no iron and need a finite source.'}
        self.world['godot']['resident_turns'] = {'shared:smith': {'history': [{
            'need_request_id': 'turn:shared:smith:0:1', 'command_id': 'turn:shared:smith:0:1',
            'need_source_sequence': 0, 'need_controller_epoch': 0, 'need': self.need,
            'status': 'settled', 'result': {'ok': True, 'code': 'wait'}, 'provenance': 'opengameagent_fixture',
            'action': 'wait', 'model_choice': 'a0', 'reason': 'Explicit offline test choice; no model inference.'}]}}
        self.evidence = {'world_id': self.world['world_id'], 'proposals': [{
            'resident_id': 'shared:smith', 'capability_id': 'finite_iron_supply', 'first': {'request_id': 'turn:shared:smith:0:1',
            'source_sequence': 0, 'controller_epoch': 0, 'reason': self.need['reason']}}]}
        point = self.world['godot']['positions']['shared:smith']
        self.manifest = {'schema_version': 1, 'provenance': chain.PROVENANCE,
            'delivery_kind': 'existing_finite_source_configuration', 'world_id': self.world['world_id'],
            'owner_gm': 'gm-05', 'issue_id': 'issue-runtime', 'source_resident_id': 'shared:smith',
            'source_request_id': 'turn:shared:smith:0:1', 'source_seq': 0, 'evidence_refs': ['/proposals/0'],
            'spec': {'id': 'offline-chain:iron-offcuts', 'label': 'Public finite iron offcuts',
            'material': 'iron', 'initial_stock': 3, 'position': [point[0], point[1], point[2] + .2], 'access': 'public'}}

    def verify(self):
        return chain.validate_candidate(self.manifest, self.evidence, self.world, issue_id='issue-runtime')

    def test_valid_candidate_requires_real_need_and_finite_grant(self):
        self.assertTrue(self.verify())

    def test_untrusted_success_flags_do_not_override_world_owner_or_source(self):
        for key, value in [('world_id', 'shared:other'), ('owner_gm', 'gm-06'),
                           ('issue_id', 'different-issue'), ('source_resident_id', 'shared:healer'),
                           ('source_request_id', 'invented-request'), ('source_seq', 1), ('source_seq', False), ('schema_version', True),
                           ('delivery_kind', 'new_gameplay_code'), ('provenance', 'real_model')]:
            with self.subTest(key=key):
                original = copy.deepcopy(self.manifest)
                self.manifest.update({key: value, 'approved': True, 'verified_in_world': True, 'test_passed': True})
                with self.assertRaises(ValueError):
                    self.verify()
                self.manifest = original

    def test_aggregate_proposal_cannot_replace_canonical_accepted_private_need(self):
        self.world['godot']['resident_turns']['shared:smith']['history'] = []
        with self.assertRaisesRegex(ValueError, 'canonical private need'):
            self.verify()

    def test_ambiguous_duplicate_private_request_rejected(self):
        history = self.world['godot']['resident_turns']['shared:smith']['history']
        history.append(copy.deepcopy(history[0]))
        with self.assertRaisesRegex(ValueError, 'canonical private need'):
            self.verify()

    def test_changed_original_need_not_replaced_by_latest_proposal(self):
        self.evidence['proposals'][0]['first']['reason'] = 'Unrelated request to own a castle.'
        with self.assertRaisesRegex(ValueError, 'canonical private need'):
            self.verify()

    def test_manifest_and_projection_agreement_cannot_hide_changed_canonical_provenance(self):
        history = self.world['godot']['resident_turns']['shared:smith']['history']
        for key, value in [('command_id', 'other'), ('need_controller_epoch', 1), ('need_source_sequence', 999),
                           ('status', 'provider_error'), ('result', {'ok': False}), ('provenance', 'opengameagent_live'),
                           ('action', 'invented_action'), ('model_choice', None), ('reason', None),
                           ('need', dict(self.need, capability_id='unrelated'))]:
            with self.subTest(key=key):
                original = copy.deepcopy(history[0])
                history[0][key] = value
                with self.assertRaises(ValueError):
                    self.verify()
                history[0] = original

    def test_resource_gift_position_and_spec_widening_rejected(self):
        for key, value in [('initial_stock', 4), ('initial_stock', True), ('material', 'wood'),
                           ('position', [50, 0, 50]), ('access', 'private'), ('regenerate', True), ('label', 3)]:
            with self.subTest(key=key, value=value):
                original = copy.deepcopy(self.manifest['spec'])
                self.manifest['spec'][key] = value
                with self.assertRaises(ValueError):
                    self.verify()
                self.manifest['spec'] = original

    def test_changed_genesis_property_cannot_be_approved_as_unchanged_world(self):
        self.world['life']['accounts'][0]['iron'] = 1
        with self.assertRaisesRegex(ValueError, 'zero-iron genesis'):
            self.verify()

    def test_candidate_cli_rejects_wrong_evidence_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.manifest['evidence_sha256'] = '0' * 64
            for name, value in [('manifest', self.manifest), ('evidence', self.evidence), ('save', self.world)]:
                chain.write(root / (name + '.json'), value)
            with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                chain.main(['--verify-candidate', str(root / 'manifest.json'), '--evidence',
                            str(root / 'evidence.json'), '--save', str(root / 'save.json')])

    def test_stale_failure_file_cannot_replay_successful_resident_prepare(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            chain.write(root / 'failure.json', {'phase': 'prepare'})
            chain.write(root / 'prepare.json', {'failure_count': 0})
            with self.assertRaisesRegex(ValueError, 'prepare already completed'):
                chain.prepare(SimpleNamespace(out=root))

    def test_later_same_world_progress_cannot_be_overwritten_by_old_checkpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            chain.write(root / 'world.json', self.world)
            chain.write(root / 'result.json', {'status': 'offline_integration_passed', 'final_save_sha256': '0' * 64})
            before = (root / 'world.json').read_bytes()
            with self.assertRaisesRegex(ValueError, 'world continued after headless checkpoint'):
                chain.finish(SimpleNamespace(out=root))
            self.assertEqual((root / 'world.json').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
