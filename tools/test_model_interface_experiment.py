import unittest
import tempfile
from pathlib import Path
from model_interface_experiment import resolve_step, personal_payload, finished, freeze_manifest, Providers


class InterfaceIsolationTests(unittest.TestCase):
    def test_identical_frozen_plan_can_reopen_after_json_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'manifest.json'
            manifest={'model':'original','order':[('kimi','menu','meal_rest',1)]}
            freeze_manifest(path,manifest)
            before=path.read_bytes()
            freeze_manifest(path,manifest)
            self.assertEqual(before,path.read_bytes())

    def test_reopening_does_not_allow_a_changed_model(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'manifest.json'
            freeze_manifest(path,{'model':'original'})
            before=path.read_bytes()
            with self.assertRaisesRegex(AssertionError,'manifest differs'):
                freeze_manifest(path,{'model':'replacement'})
            self.assertEqual(before,path.read_bytes())

    def test_existing_request_is_not_replayed_even_without_a_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory)/'calls'/'reserved').mkdir(parents=True)
            with self.assertRaisesRegex(RuntimeError,'no_automatic_replay'):
                Providers(directory).call('kimi','menu',{},'reserved')

    def test_home_rest_does_not_silently_select_public_rest(self):
        observation={'options':[{'id':'place:rest:park','action':'rest','place_id':'park'}]}
        self.assertEqual(resolve_step({'action':'rest'},observation),(None,'unavailable_or_ambiguous_action'))

    def test_ambiguous_social_target_is_returned_for_replanning(self):
        observation={'options':[{'id':'approach:a','action':'approach','counterparty':'a'},
                                {'id':'approach:b','action':'approach','counterparty':'b'}]}
        self.assertIsNone(resolve_step({'action':'approach'},observation)[0])
        self.assertEqual(resolve_step({'action':'approach','counterparty':'b'},observation)[0]['id'],'approach:b')

    def test_nonexistent_capability_never_becomes_an_existing_action(self):
        self.assertIsNone(resolve_step({'action':'cook_fish_soup'},{'options':[{'id':'wait','action':'wait'}]})[0])

    def test_payload_does_not_mutate_or_leak_global_archive(self):
        source={'view':{'needs':{'hunger':55},'experiences':list(range(20)),'observations':[]},
                'options':[{'id':'wait','action':'wait'}],'position':[0,0,0],'home':[1,0,0],
                'global_archive':{'someone_else':'private'}}
        result=personal_payload(source,'meal_rest',[])
        self.assertEqual(result['personal_observation']['needs'],{'satiety':55})
        self.assertEqual(source['view']['needs'],{'hunger':55})
        self.assertNotIn('global_archive',result)
        self.assertEqual(len(result['personal_observation']['experiences']),8)

    def test_planned_or_started_action_is_not_completion(self):
        observation={'distance_home':0,'view':{'needs':{'hunger':90},'inventory':{'food':0}}}
        events=[{'actor_id':'shared:well-keeper','type':'action_started'},
                {'actor_id':'someone_else','type':'eat_ration'}, {'actor_id':'someone_else','type':'rest'}]
        self.assertFalse(finished('meal_rest',observation,events))
        self.assertFalse(finished('meal_reserve',observation,events))


if __name__=='__main__':
    unittest.main()
