import unittest
import json
import os
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys
from contextlib import redirect_stdout
import io
from unittest.mock import patch, MagicMock
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_observation_window import episode_seconds, life_outcome, run_owned
import run_observation_window as window


class ObservationWindowTests(unittest.TestCase):
    def test_supervisor_saves_real_process_status_and_stops_at_its_call_cap(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            world = root/'world.json'
            document = dict(world_id='fixture:window', residents=[{'stable_id':str(i)} for i in range(10)],
                            life=dict(seq=1))
            world.write_text(json.dumps(document))
            control = root/'control.json'; control.write_text('{}')
            scope = dict(deadline_utc=(datetime.now(timezone.utc)+timedelta(minutes=10)).isoformat(),
                world=str(world), world_id=document['world_id'], out=str(root/'out'), control=str(control),
                gm_state_dir=str(root/'gm'), max_npc_calls=1, max_gm_calls=0, max_cost_cny=2,
                stop_file=str(root/'stop'), ledger='fake-ledger', godot='fake-engine', config='fake-config',
                checkpoint_dir=str(root/'checkpoints'))
            scope_path=root/'scope.json'; scope_path.write_text(json.dumps(scope))
            def fake_process(command, directory, timeout, env, update):
                update({'active_processes': 2})
                self.assertEqual(json.loads(control.read_text())['supervisor']['active_processes'],2)
                destination=Path(command[command.index('--out')+1]); destination.mkdir(parents=True)
                result=dict(engine_exit=0, checkpoint_export=dict(status='exported'),
                    gateway_shutdown=dict(drained_complete=True), validation_passed=True, upstream_requests=1)
                (destination/'result.json').write_text(json.dumps(result))
                return dict(exit_code=0,timed_out=False,owned={'active_processes':0})
            with patch.object(sys,'argv',['window','--scope',str(scope_path)]), \
                    patch.object(window,'decode',return_value=document), \
                    patch.object(window,'load_state',return_value={'world_id':document['world_id']}), \
                    patch.object(window,'for_world',return_value=MagicMock()), \
                    patch.object(window,'ledger_totals',return_value={'counts':{},'charge_nano':0}), \
                    patch.object(window,'run_owned',side_effect=fake_process), \
                    patch.object(window,'observe',return_value={'decision_count':1}), \
                    patch.object(window,'checkpoint',return_value={'checkpoints':[{'seq':1}]}), \
                    redirect_stdout(io.StringIO()):
                self.assertEqual(window.main(),0)
            report=json.loads((root/'out/run.json').read_text())
            self.assertEqual((report['reason'],report['npc_calls'],report['active_processes']),('window_budget_reached',1,0))
            self.assertEqual(report['deadline_utc'],scope['deadline_utc'])

    @unittest.skipUnless(os.name == 'nt', 'Windows containment integration')
    def test_real_child_exits_and_callback_failure_cleans_its_owned_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            seen = []
            out = Path(directory) / 'normal'
            result = run_owned([sys.executable,'-c','print("owned child")'], out, 5, dict(os.environ),
                               lambda state: seen.append(state['active_processes']))
            self.assertEqual(result['exit_code'],0)
            self.assertEqual(result['owned']['active_processes'],0)
            self.assertTrue(seen)
            failed = Path(directory) / 'failed'
            def broken(state): raise ValueError('injected callback failure')
            with self.assertRaises(ValueError):
                run_owned([sys.executable,'-c','import time; time.sleep(10)'], failed, 5, dict(os.environ), broken)
            self.assertEqual(json.loads((failed/'owned-processes.json').read_text())['active_processes'],0)

    def test_deadline_does_not_admit_work_inside_settlement_reserve(self):
        now = datetime(2026,9,18,11,tzinfo=timezone.utc)
        self.assertEqual(episode_seconds(now+timedelta(hours=2), now),600)
        self.assertEqual(episode_seconds(now+timedelta(seconds=200), now),100)
        self.assertEqual(episode_seconds(now+timedelta(seconds=90), now),0)
        self.assertEqual(episode_seconds(now-timedelta(seconds=1), now),0)

    def test_idle_continuation_is_not_reported_as_a_model_decision(self):
        result = dict(engine_exit=0, checkpoint_export=dict(status='exported'),
                      gateway_shutdown=dict(drained_complete=True), idle_completed=True,
                      world_progress_observed=True, validation_passed=False)
        self.assertEqual(life_outcome(result),'healthy_idle')
        self.assertEqual(life_outcome(dict(result,validation_passed=True)),'decisions_completed')
        for changed in [dict(model_errors={'actor':'timeout'}),dict(shutdown_incomplete=True),
                        dict(checkpoint_export=dict(status='failed')),dict(world_progress_observed=False),
                        dict(gateway_shutdown=dict(drained_complete=False))]:
            with self.subTest(changed=changed): self.assertEqual(life_outcome(dict(result,**changed)),'blocked')


if __name__ == '__main__': unittest.main()
