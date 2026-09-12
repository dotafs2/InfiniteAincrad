"""Offline creation regressions. Never reads/writes the maintained trial world."""
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from create_trade_fixture import fixture, shared_world_seed

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools' / 'create_trade_fixture.py'


class TenWorldCreationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ten-world-')
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'world.json'

    def run_cli(self, *args, output=None):
        return subprocess.run([sys.executable, str(SCRIPT), '--output', str(output or self.path),
                               *args], capture_output=True, text=True, encoding='utf-8')

    def test_default_fixture_is_still_three_person_trade(self):
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.path.read_text(encoding='utf-8')), fixture())
        self.assertEqual(fixture()['world_id'], 'fixture:town-trade-validation')
        self.assertEqual(len(fixture()['residents']), 3)

    def test_old_online_join_remains_two_residents(self):
        result = self.run_cli('--online-join')
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads(self.path.read_text(encoding='utf-8'))
        self.assertEqual(len(state['residents']), 2)
        self.assertNotIn('fixture:carpenter', state['godot']['positions'])
        self.assertEqual(state['residents'][0]['needs']['hunger'], 60)

    def test_new_seed_declares_independent_genesis(self):
        world = shared_world_seed('shared:creation-unit-test')
        self.assertFalse(world['fixture'])
        self.assertEqual(world['origin']['kind'], 'new_world_seed')
        self.assertTrue(world['origin']['genesis'])
        self.assertIsNone(world['origin']['migrated_from'])
        self.assertEqual(world['life']['seq'], 0)
        for field in ('events', 'contracts', 'applied', 'relations', 'inboxes'):
            self.assertEqual(world['life'][field], [])
        self.assertFalse(world['origin']['live_model_demand'])

    def test_identity_is_fixed_at_creation(self):
        first = shared_world_seed('shared:creation-unit-test')
        second = shared_world_seed('shared:creation-unit-test')
        ids = [person['stable_id'] for person in first['residents']]
        self.assertEqual(len(ids), 10)
        self.assertEqual(len(set(ids)), 10)
        self.assertEqual(first['residents'], second['residents'])
        self.assertEqual(set(ids), set(first['godot']['positions']))
        self.assertEqual(set(ids), set(first['godot']['homes']))
        self.assertEqual(set(ids), {a['resident_id'] for a in first['life']['accounts']})
        self.assertEqual(set(ids), {a['resident_id'] for a in first['survival']['accounts']})

    def test_genesis_resources_match_already_created_allocation(self):
        world = shared_world_seed('shared:creation-unit-test')
        self.assertEqual(sum(p['coins_col'] for p in world['residents']), 95)
        for account in world['life']['accounts']:
            self.assertEqual({k: v for k, v in account.items() if k != 'resident_id'},
                             dict(wood=1, iron=0, kindling=0, reserved_col=0))
        for account in world['survival']['accounts']:
            self.assertEqual(account['food'], 1)
            self.assertEqual(account['energy'], 60)
        self.assertEqual(world['foraging']['initial_stock'], 6)
        self.assertEqual(world['foraging']['harvested_total'], 0)

    def test_background_does_not_grant_occupation_capabilities(self):
        world = shared_world_seed('shared:creation-unit-test')
        self.assertEqual(world['life']['skills'], [
            {'resident_id': 'shared:smith', 'skill_id': 'metal_repair'},
            {'resident_id': 'shared:carpenter', 'skill_id': 'wood_repair'}])
        for person in world['residents']:
            self.assertIn('capability_note', person['runtime'])
            self.assertTrue(person['role'].startswith(('interest_', 'repair_')))
        item = world['life']['items'][0]
        self.assertEqual(item['source'], 'explicit_genesis_fact_not_earned_not_migrated')

    def test_existing_save_is_never_overwritten(self):
        self.path.write_bytes(b'preserve unfinished and failed history\n')
        before = hashlib.sha256(self.path.read_bytes()).hexdigest()
        result = self.run_cli('--preset', 'shared-world-seed', '--world-id', 'shared:new')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), before)

    def test_normalization_cannot_bypass_fixture_id_rejection(self):
        for identity in ('fixture:town-trade-validation', ' fixture:town-trade-validation ', '   '):
            with self.subTest(identity=identity):
                result = self.run_cli('--preset', 'shared-world-seed', '--world-id', identity)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(self.path.exists())

    def test_new_world_incompatible_arguments_fail_before_creation(self):
        for args in [('--preset', 'shared-world-seed'),
                     ('--preset', 'shared-world-seed', '--world-id', 'shared:new', '--online-join'),
                     ('--world-id', 'shared:new')]:
            with self.subTest(args=args):
                result = self.run_cli(*args)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(self.path.exists())

    def test_game_directory_is_rejected_without_creating_file(self):
        destination = ROOT / 'game' / 'ten_world_creation_test_forbidden.json'
        self.assertFalse(destination.exists())
        result = self.run_cli(output=destination)
        self.assertEqual(result.returncode, 2)
        self.assertFalse(destination.exists())

    def test_two_creators_cannot_reset_each_other(self):
        command = [sys.executable, str(SCRIPT), '--output', str(self.path),
                   '--preset', 'shared-world-seed', '--world-id', 'shared:race-test']
        children = [subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(2)]
        for child in children:
            child.communicate(timeout=15)
        self.assertEqual(sorted(child.returncode for child in children), [0, 2])
        created = json.loads(self.path.read_text(encoding='utf-8'))
        self.assertEqual(created['world_id'], 'shared:race-test')
        self.assertEqual(len(created['residents']), 10)


if __name__ == '__main__':
    unittest.main(verbosity=2)
