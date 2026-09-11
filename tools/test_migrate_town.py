import copy
import json
import unittest
from migrate_town import prepare


class MigrationTests(unittest.TestCase):
    def source(self):
        return {'schema_version': 2, 'world_id': 'test:preservation',
                'residents': [{'stable_id': 'a', 'future_field': {'memory': ['retain me']}}],
                'life': {'seq': 1, 'events': [{'seq': 1}], 'contracts': [{'status': 'accepted'}]},
                'survival': {'accounts': [{'resident_id': 'a'}]},
                'foraging': {'stock': 1, 'capacity': 3, 'initial_stock': 1,
                             'produced_total': 0, 'harvested_total': 0},
                'building_bindings': [{'resident_id': 'a', 'building_id': 'sao_inn_01'}],
                'unknown_future_module': {'opaque_data': [1, 'unchanged']}}

    def convert(self, source):
        return prepare(json.dumps(source).encode())

    def test_lossless_including_unknown_fields_and_commitments(self):
        source = self.source()
        before = copy.deepcopy(source)
        world, report = self.convert(source)
        self.assertEqual(source, before)
        self.assertEqual({k: world[k] for k in source}, source)
        self.assertEqual(world['godot']['commands'], {})
        self.assertEqual(world['godot']['pending'], {})
        self.assertTrue(report['all_original_fields_preserved'])

    def test_rejects_partial_history(self):
        source = self.source()
        source['life']['seq'] = 2
        with self.assertRaises(ValueError):
            self.convert(source)

    def test_rejects_duplicate_identity(self):
        source = self.source()
        source['residents'] *= 2
        with self.assertRaises(ValueError):
            self.convert(source)

    def test_rejects_reimport(self):
        source, _ = self.convert(self.source())
        with self.assertRaises(ValueError):
            self.convert(source)

    def test_rejects_unmapped_active_resident(self):
        source = self.source()
        source['building_bindings'][0]['building_id'] = 'unknown'
        with self.assertRaises(KeyError):
            self.convert(source)

    def test_rejects_invented_berries(self):
        source = self.source()
        source['foraging']['stock'] = 2
        with self.assertRaises(ValueError):
            self.convert(source)


if __name__ == '__main__':
    unittest.main()
