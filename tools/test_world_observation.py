"""Offline evidence integrity checks; never a live resident simulation."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from create_trade_fixture import shared_world_seed
from world_observation import checkpoint, decode, observe, validate_world


def world_with_reply(action='wait', delivered=False):
    world = shared_world_seed('shared:observation-test')
    actor = world['residents'][0]['stable_id']
    request = 'turn:shared:well-keeper:0:1'
    event = {'seq': 1, 'actor_id': actor, 'operation_id': request, 'text': 'Good morning.',
             'type': 'ask_help', 'recipient_ids': ['shared:baker']}
    world['life'].update(seq=1, events=[event])
    reply = {'ok': True, 'decision': {'action': 'a0', 'reason': 'I want to share a useful observation.', 'speech': 'Good morning.'}}
    delivery = {'delivered': delivered, 'code': 'speech_delivered' if delivered else 'speech_not_supported_for_action'}
    if delivered:
        delivery.update(text=event['text'], event_seq=1)
    entry = {'request_id': request, 'world_id': world['world_id'], 'resident_id': actor,
             'provider_id': 'opengameagent_fixture', 'model_returned': True, 'original_reply': reply,
             'reason': reply['decision']['reason'], 'speech': reply['decision']['speech'],
             'application': {'status': 'settled', 'code': 'started', 'speech_delivery': delivery}}
    world['godot']['resident_archive'] = {'world_id': world['world_id'], 'order': [request], 'entries': {request: entry}}
    world['godot']['resident_turns'] = {actor: {'status': 'settled', 'history': [{'command_id': request, 'action': action}]}}
    return world, actor, request


class ObservationTests(unittest.TestCase):
    def test_zero_is_not_ten_invented_decisions(self):
        result = observe(shared_world_seed('shared:empty'))
        self.assertEqual(result['decision_count'], 0)
        self.assertEqual(len(result['residents']), 10)
        self.assertTrue(all(r['controller_status'] == 'not_started' and not r['decisions'] for r in result['residents']))

    def test_private_reason_is_not_public_speech(self):
        world, actor, request = world_with_reply(delivered=False)
        row = observe(world)['residents'][0]['decisions'][0]
        self.assertIsNone(row['actually_spoken'])
        self.assertEqual(row['proposed_speech'], 'Good morning.')
        self.assertTrue(row['stated_reason'])

    def test_speech_requires_matching_authoritative_event(self):
        world, actor, request = world_with_reply(delivered=True)
        self.assertEqual(observe(world)['residents'][0]['decisions'][0]['actually_spoken'], 'Good morning.')
        world['life']['events'][0]['operation_id'] = 'different-request'
        self.assertIsNone(observe(world)['residents'][0]['decisions'][0]['actually_spoken'])

    def test_false_delivery_receipt_cannot_be_reported_as_speech(self):
        world, actor, request = world_with_reply(delivered=True)
        world['godot']['resident_archive']['entries'][request]['application']['speech_delivery']['delivered'] = False
        self.assertIsNone(observe(world)['residents'][0]['decisions'][0]['actually_spoken'])

    def test_existing_publisher_lock_refuses_without_removing_other_owner(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root / 'live.json'; out = root / 'checkpoints'
            source.write_text(json.dumps(shared_world_seed('shared:locked')), encoding='utf-8')
            out.mkdir(); lock = out / '.checkpoint.lock'; lock.write_text('other owner')
            with self.assertRaises(ValueError): checkpoint(source, out)
            self.assertEqual(lock.read_text(), 'other owner')
            self.assertFalse((out / 'manifest.json').exists())

    def test_pending_action_not_reported_as_completed(self):
        world, actor, request = world_with_reply(action='life:harvest_ration')
        world['godot']['commands'][request] = {'status': 'pending'}
        world['godot']['pending'][actor] = {'command_id': request, 'action': 'harvest_ration', 'elapsed': 2}
        result = observe(world)
        self.assertEqual(result['residents'][0]['decisions'][0]['current_command_status'], 'pending')
        self.assertEqual(result['residents'][0]['pending_job']['elapsed'], 2)
        self.assertNotIn('completed', result['residents'][0]['decisions'][0])

    def test_shared_plan_reports_admission_and_current_outcome_separately(self):
        world, actor, request = world_with_reply()
        world['godot']['capabilities'] = {'commands': {request: {'status': 'pending'}},
            'plans': {'invite': {'id': 'invite', 'accepted_command': request,
                                 'participants': [actor, 'shared:baker'], 'status': 'running'}}}
        row = observe(world)['residents'][0]['decisions'][0]
        self.assertEqual(row['module_command_status']['capabilities'], 'pending')
        self.assertEqual(row['shared_plans'][0]['status'], 'running')
        world['godot']['capabilities']['commands'][request]['status'] = 'completed'
        world['godot']['capabilities']['plans']['invite']['status'] = 'completed'
        row = observe(world)['residents'][0]['decisions'][0]
        self.assertEqual(row['module_command_status']['capabilities'], 'completed')
        self.assertEqual(row['shared_plans'][0]['status'], 'completed')

    def test_rejected_reply_and_unresolved_controller_remain_visible(self):
        world, actor, request = world_with_reply()
        world['godot']['resident_archive']['entries'][request]['application']['status'] = 'rule_rejection'
        world['godot']['resident_turns']['shared:baker'] = {'status': 'pending'}
        result = observe(world)
        self.assertEqual(result['decision_count'], 1)
        self.assertEqual(result['residents'][0]['decisions'][0]['application']['status'], 'rule_rejection')
        self.assertEqual(result['residents'][1]['controller_status'], 'pending')
        self.assertFalse(result['residents'][1]['decisions'])

    def test_baseline_omits_old_replies_but_preserves_new_events(self):
        world, actor, request = world_with_reply()
        result = observe(world, deepcopy(world))
        self.assertEqual(result['decision_count'], 0)
        self.assertEqual(result['new_world_events'], [])

    def test_missing_history_and_archive_order_are_errors(self):
        world, actor, request = world_with_reply()
        broken = deepcopy(world); broken['life']['events'] = []
        with self.assertRaises(ValueError): validate_world(broken)
        broken = deepcopy(world); broken['godot']['resident_archive']['order'] = []
        with self.assertRaises(ValueError): validate_world(broken)

    def test_duplicate_json_fields_are_rejected(self):
        with self.assertRaises(ValueError): decode(b'{"world_id":"one","world_id":"two"}')

    def test_checkpoint_preserves_bytes_and_same_seq_different_state(self):
        world, actor, request = world_with_reply()
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root / 'live.json'; out = root / 'checkpoints'
            raw = json.dumps(world, indent=2).encode(); source.write_bytes(raw)
            first = checkpoint(source, out)
            saved = out / first['checkpoints'][0]['file']
            self.assertEqual(saved.read_bytes(), raw)
            self.assertEqual(checkpoint(source, out), first)
            world['godot']['elapsed_seconds'] += 1
            source.write_text(json.dumps(world), encoding='utf-8')
            second = checkpoint(source, out)
            self.assertEqual(len(second['checkpoints']), 2)
            self.assertEqual(saved.read_bytes(), raw)

    def test_changed_history_world_or_reply_cannot_replace_checkpoint(self):
        world, actor, request = world_with_reply()
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root / 'live.json'; out = root / 'checkpoints'
            source.write_text(json.dumps(world), encoding='utf-8'); checkpoint(source, out)
            index = (out / 'manifest.json').read_bytes()
            variants = []
            bad = deepcopy(world); bad['life']['events'][0]['text'] = 'Changed past'; variants.append(bad)
            bad = deepcopy(world); bad['world_id'] = 'different'; variants.append(bad)
            bad = deepcopy(world); bad['godot']['resident_archive']['entries'][request]['reason'] = 'Changed reason'; variants.append(bad)
            for bad in variants:
                source.write_text(json.dumps(bad), encoding='utf-8')
                with self.assertRaises(ValueError): checkpoint(source, out)
                self.assertEqual((out / 'manifest.json').read_bytes(), index)

    def test_append_replay_evidence_without_changing_original(self):
        world, actor, request = world_with_reply()
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root / 'live.json'; out = root / 'checkpoints'
            source.write_text(json.dumps(world), encoding='utf-8'); checkpoint(source, out)
            world['godot']['resident_archive']['entries'][request]['replays'] = [{'reason': 'A conflicting received reply'}]
            source.write_text(json.dumps(world), encoding='utf-8')
            self.assertEqual(len(checkpoint(source, out)['checkpoints']), 2)

    def test_credential_field_stops_publication(self):
        world = shared_world_seed('shared:credentials-test')
        world['godot']['config'] = {'api_key': 'dummy-fixture-value'}
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root / 'live.json'; out = root / 'checkpoints'
            source.write_text(json.dumps(world), encoding='utf-8')
            with self.assertRaises(ValueError): checkpoint(source, out)
            self.assertFalse((out / 'manifest.json').exists())


if __name__ == '__main__':
    unittest.main()
