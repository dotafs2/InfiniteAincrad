"""Persistence regressions using the authorized backup, never the running world."""
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from migrate_living_quarter import ROOT, migrate, activate, terrain_height, LAYOUT


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.source = ROOT/'private/living-quarter-20260916/original-seq129.json'
        if not self.source.exists():
            self.skipTest('Private authorized test backup is not available on this machine')
        self.raw = self.source.read_bytes()
        self.before = json.loads(self.raw)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.out = Path(self.temp.name)/'world.json'

    def run_migration(self, source=None):
        with contextlib.redirect_stdout(io.StringIO()):
            migrate(source or self.source, self.out)
        return json.loads(self.out.read_text(encoding='utf-8'))

    def test_all_history_property_contracts_and_identities_survive_exactly(self):
        after = self.run_migration()
        for field in self.before:
            if field != 'godot':
                self.assertEqual(self.before[field], after[field], field)
        for field in self.before['godot']:
            if field not in ['positions','homes','berry_position','foraging_work_spots']:
                self.assertEqual(self.before['godot'][field], after['godot'][field], field)
        self.assertEqual(self.source.read_bytes(), self.raw)

    def test_each_raised_spawn_matches_triangle_surface(self):
        after = self.run_migration()
        layout = json.loads(LAYOUT.read_text())
        for x,y,z in after['godot']['positions'].values():
            self.assertAlmostEqual(y-terrain_height(layout,x,z), .06)
        for x,y,z in after['godot']['foraging_work_spots']['positions'].values():
            self.assertAlmostEqual(y-terrain_height(layout,x,z), .005)

    def test_refuses_active_journeys_in_each_job_store(self):
        for path in [('pending',),('trade','jobs'),('places','jobs')]:
            with self.subTest(path=path):
                state = copy.deepcopy(self.before)
                node = state['godot']
                for key in path[:-1]:
                    node = node[key]
                node[path[-1]] = {'resident':{'command_id':'in_flight'}}
                source = Path(self.temp.name)/'source.json'
                source.write_text(json.dumps(state), encoding='utf-8')
                with self.assertRaisesRegex(ValueError,'Active journeys'):
                    self.run_migration(source)
                self.assertFalse(self.out.exists())

    def test_refuses_overwrite_and_relocation_twice(self):
        after = self.run_migration()
        with self.assertRaises(FileExistsError):
            self.run_migration()
        migrated = Path(self.temp.name)/'migrated.json'
        migrated.write_text(json.dumps(after), encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'Already migrated'):
            self.run_migration(migrated)

    def test_activation_preserves_backup_and_uses_world_writer_lock(self):
        canonical=Path(self.temp.name)/'canonical.json'
        canonical.write_bytes(self.raw)
        self.run_migration(canonical)
        lock=canonical.with_name(canonical.name+'.writer-lock')
        lock.mkdir()
        with self.assertRaises(FileExistsError):
            activate(canonical,self.out)
        self.assertTrue(lock.exists())
        lock.rmdir()
        with contextlib.redirect_stdout(io.StringIO()):
            activate(canonical,self.out)
        self.assertEqual(canonical.read_bytes(),self.out.read_bytes())
        self.assertEqual(self.out.with_name('world.pre-activation.json').read_bytes(),self.raw)
        self.assertFalse(lock.exists())

    def test_activation_refuses_a_world_changed_after_review(self):
        canonical=Path(self.temp.name)/'canonical.json'
        canonical.write_bytes(self.raw)
        self.run_migration(canonical)
        changed=self.raw+b'\n'
        canonical.write_bytes(changed)
        with self.assertRaisesRegex(ValueError,'World changed'):
            activate(canonical,self.out)
        self.assertEqual(canonical.read_bytes(),changed)
        self.assertFalse(canonical.with_name(canonical.name+'.writer-lock').exists())


if __name__ == '__main__':
    unittest.main()
