"""Genesis allocation, rich authoring, validation and exact persistence contracts."""
from copy import deepcopy
import json
import re
import unittest
from character_profiles import catalogue, validate_profile, profile_for_new_resident, CONTRACT
from create_trade_fixture import shared_world_seed, fixture
from export_character_dossiers import render


class ProfileTests(unittest.TestCase):
    def test_all_ten_are_distinct_and_complete(self):
        profiles = catalogue()
        self.assertEqual(len(profiles), 10)
        for key in CONTRACT['core_fields']:
            self.assertEqual(len({p['core'][key] for p in profiles.values()}), 10, key)
        for key in CONTRACT['facet_contexts']:
            self.assertEqual(len({p['facets'][key] for p in profiles.values()}), 10, key)
        for resident_id, p in profiles.items():
            self.assertIs(validate_profile(p, resident_id), p)
            self.assertEqual(set(p['sections']), set(CONTRACT['required_sections']))
            self.assertEqual(len(p['sections']['personality']['dimensions']), 12)
            self.assertFalse(re.search(r'[\u3400-\u9fff]', json.dumps(p, ensure_ascii=False)))
            self.assertEqual(p['sections']['relationships']['entries'], [])
            self.assertEqual(p['sections']['knowledge']['personal_claims'], [])
            self.assertIsNone(p['sections']['aincrad']['level'])
            self.assertEqual(p['sections']['work_and_learning']['unlocked_skills'], [])

    def test_seed_gains_character_without_extra_abilities_or_goods(self):
        world = shared_world_seed('shared:profile-test')
        self.assertEqual(len(world['residents']), 10)
        self.assertEqual(world['life']['skills'], [
            {'resident_id': 'shared:smith', 'skill_id': 'metal_repair'},
            {'resident_id': 'shared:carpenter', 'skill_id': 'wood_repair'}])
        self.assertEqual(len(world['life']['items']), 1)
        for i, p in enumerate(world['residents']):
            self.assertEqual(p['coins_col'], 5+i)
            self.assertEqual(p['needs'], {'hunger': 60.0})
            self.assertEqual(p['personality'], p['character_profile']['core']['temperament'])
            self.assertGreaterEqual(len(p['interests']), 4)
            self.assertEqual(world['survival']['accounts'][i]['food'], 1)
        for key in ('events', 'contracts', 'relations', 'inboxes'):
            self.assertEqual(world['life'][key], [])

    def test_legacy_fixture_and_catalogue_are_not_implicitly_mutated(self):
        self.assertTrue(all('character_profile' not in p for p in fixture()['residents']))
        p = profile_for_new_resident('shared:baker')
        p['core']['flaw'] = 'Changed only in one independent seed.'
        self.assertNotEqual(p, profile_for_new_resident('shared:baker'))
        with self.assertRaises(KeyError):
            profile_for_new_resident('unknown:new-resident')

    def test_malformed_profile_fails_closed(self):
        original = profile_for_new_resident('shared:baker')
        cases = []
        for key, value in [('resident_id', 'shared:smith'), ('schema_version', True),
                           ('schema_version', 1.5), ('schema_version', 2), ('provenance', 'official_SAO_canon'),
                           ('core', []), ('facets', None), ('extensions', []), ('sections', {})]:
            p = deepcopy(original); p[key] = value; cases.append(p)
        p = deepcopy(original); p['core']['flaw'] = 'x' * 181; cases.append(p)
        p = deepcopy(original); p['facets']['social'] = 42; cases.append(p)
        p = deepcopy(original); p['extensions']['large'] = 'x' * CONTRACT['max_profile_bytes']; cases.append(p)
        for p in cases:
            with self.subTest(case=str(p)[:70]), self.assertRaises(ValueError):
                validate_profile(p, 'shared:baker')

    def test_dormant_extensions_survive_json_without_meaning_being_invented(self):
        p = profile_for_new_resident('shared:healer')
        p['extensions']['future_module'] = {'unknown': None, 'precision': 0.12345678901234567, 'private': 'x' * 40000}
        restored = json.loads(json.dumps(p))
        self.assertEqual(validate_profile(restored, 'shared:healer'), p)

    def test_review_document_includes_every_section_and_private_authoring(self):
        document = render()
        self.assertEqual(document.count('### Decision core'), 10)
        self.assertEqual(document.count('### Author notes'), 10)
        self.assertIn('Original resident dossiers', document)
        self.assertIn('self_private_stored_only', document)


if __name__ == '__main__':
    unittest.main()
