"""A deadline-bound, single-writer live NPC / GM observation window.

This supervisor never installs a proposed change. It preserves proposals for a
separate reviewed coding/release phase and never turns an uncertain call into a retry.
"""
from __future__ import annotations
import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import time

from actor_usage import atomic_text, for_world
from gm_runner import StateLock, global_unknown_gms, load_state
from owned_windows_job import WindowsProcessTree
from world_observation import checkpoint, decode, observe, reject_credentials

ROOT = Path(__file__).resolve().parents[1]
RESERVE_SECONDS = 100


def utc():
    return datetime.now(timezone.utc)


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    atomic_text(path, json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def episode_seconds(deadline, now, maximum=600):
    """Reserve shutdown/receipt time before admitting another engine process."""
    return max(0, min(maximum, int((deadline - now).total_seconds()) - RESERVE_SECONDS))


def life_outcome(result):
    if (result.get('engine_exit') != 0 or result.get('shutdown_incomplete')
            or result.get('model_errors') or result.get('budget_stop_reason')
            or result.get('checkpoint_export', {}).get('status') != 'exported'
            or not result.get('gateway_shutdown', {}).get('drained_complete')):
        return 'blocked'
    if result.get('validation_passed'):
        return 'decisions_completed'
    if result.get('idle_completed') and result.get('world_progress_observed'):
        return 'healthy_idle'
    return 'blocked'


def ledger_totals(path):
    with closing(sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)) as db:
        counts = dict(db.execute('SELECT state,COUNT(*) FROM requests GROUP BY state'))
        charge = db.execute("SELECT COALESCE(SUM(charge),0) FROM requests WHERE state='settled'").fetchone()[0]
    return dict(counts=counts, charge_nano=charge)


def run_owned(command, directory, timeout, environment, update):
    directory.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    last = 0.0
    with (directory / 'host.log').open('w', encoding='utf-8') as output:
        with WindowsProcessTree(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                env=environment) as tree:
            def poll(state):
                nonlocal last
                if time.monotonic() - last < 5:
                    return
                last = time.monotonic()
                save(directory / 'owned-processes.json', state)
                update(state)
            timed_out = False
            try:
                poll(tree.snapshot())
                code = tree.wait(timeout, on_poll=poll)
            except subprocess.TimeoutExpired:
                timed_out = True
                code = 124
            finally:
                # Also retain final containment evidence when a callback raises.
                tree.terminate()
                owned = tree.snapshot()
                save(directory / 'owned-processes.json', owned)
    return dict(exit_code=code, timed_out=timed_out, seconds=round(time.monotonic()-started, 3), owned=owned)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', type=Path, required=True)
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args()
    scope = load(args.scope)
    deadline = datetime.fromisoformat(scope['deadline_utc'].replace('Z', '+00:00'))
    if deadline.tzinfo is None or not 0 < (deadline-utc()).total_seconds() <= 7200:
        parser.error('A future absolute deadline within two hours is required')
    world, out = Path(scope['world']), Path(scope['out'])
    baseline = decode(world.read_bytes())
    if baseline['world_id'] != scope['world_id'] or len(baseline['residents']) != 10:
        parser.error('Expected the existing ten-resident world')
    for_world(world)
    state = load_state(Path(scope['gm_state_dir']))
    if state['world_id'] != scope['world_id']:
        parser.error('GM/world identity mismatch')
    if not 1 <= scope['max_npc_calls'] <= 256 or not 0 <= scope['max_gm_calls'] <= 10:
        parser.error('Window call caps are required')
    gm_offset = scope.get('gm_offset', 0)
    if type(gm_offset) is not int or not 0 <= gm_offset < 10:
        parser.error('GM rotation offset must be 0..9')
    if not 2 <= scope['max_cost_cny'] <= 20:
        parser.error('Window NPC cost cap must be 2..20 CNY within the existing ledger authorization')
    if out.exists():
        parser.error('A window output directory cannot be replayed')
    initial_ledger = ledger_totals(scope['ledger'])
    if any(initial_ledger['counts'].get(k, 0) for k in ('uncertain', 'reserved')):
        parser.error('The NPC ledger has an unresolved provider attempt')
    if args.preflight:
        print(json.dumps(dict(status='ready', deadline_utc=deadline.isoformat(), model_calls=0)))
        return 0
    out.mkdir(parents=True)
    (out / 'baseline.world.json').write_bytes(world.read_bytes())
    report = dict(schema_version=1, world_id=scope['world_id'], status='starting', pid=os.getpid(),
                  started_utc=utc().isoformat(), deadline_utc=deadline.isoformat(),
                  npc_calls=0, gm_calls=0, cycles=[], initial_ledger=initial_ledger,
                  active_processes=0, reason=None, installations=0)
    def persist():
        report['updated_utc'] = utc().isoformat()
        save(out / 'run.json', report)
        control = load(scope['control'])
        control['status'] = report['status']
        control['supervisor'] = {key: report[key] for key in ('pid', 'npc_calls', 'gm_calls', 'reason', 'active_processes')}
        control['supervisor']['report'] = str(out / 'run.json')
        save(scope['control'], control)
    def progress(state):
        report['active_processes'] = state['active_processes']
        persist()
    environment = dict(os.environ, DOTNET_ROLL_FORWARD='LatestMajor')
    try:
        with StateLock(world.parent / 'observation-window-owner', break_lock=False):
            while True:
                now = utc()
                if Path(scope['stop_file']).exists():
                    report['reason'] = 'requested_stop'; break
                seconds = episode_seconds(deadline, now)
                if seconds < 5:
                    report['reason'] = 'deadline_settlement_reserve'; break
                remaining_calls = scope['max_npc_calls'] - report['npc_calls']
                ledger = ledger_totals(scope['ledger'])
                cost = ledger['charge_nano'] - initial_ledger['charge_nano']
                remaining_cny = scope['max_cost_cny'] - cost / 1_000_000_000
                if remaining_calls <= 0 or remaining_cny < 2:
                    report['reason'] = 'window_budget_reached'; break
                index = len(report['cycles']) + 1
                cycle = dict(index=index, status='life', starting_seq=decode(world.read_bytes())['life']['seq'])
                report['cycles'].append(cycle)
                report['status'] = 'running_life'; persist()
                directory = out / f'cycle-{index:02}'
                life = directory / 'life'
                evidence = life / 'gm/evidence.json'
                command = [sys.executable, str(ROOT/'tools/run_town_model_validation.py'),
                    '--godot', scope['godot'], '--ledger', scope['ledger'], '--config', scope['config'],
                    '--save', str(world), '--out', str(life), '--seconds', str(seconds),
                    '--max-requests', str(min(32, remaining_calls)), '--max-cost-cny', str(math.floor(remaining_cny)),
                    '--shutdown-wait', '20', '--checkpoint-dir', scope['checkpoint_dir'],
                    '--gm-export', str(evidence), '--headless']
                cycle['life_process'] = run_owned(command, directory/'life-host', min(seconds+85, (deadline-utc()).total_seconds()), environment, progress)
                report['active_processes'] = 0
                result = load(life/'result.json') if (life/'result.json').is_file() else {}
                report['npc_calls'] += result.get('upstream_requests', 0)
                cycle['life_outcome'] = life_outcome(result)
                cycle['npc_calls'] = result.get('upstream_requests', 0)
                cycle['status'] = 'life_closed'
                current = decode(world.read_bytes())
                snapshot = observe(current, baseline)
                reject_credentials(snapshot)
                save(out/'observation.json', snapshot)
                for_world(world).export()
                persist()
                if cycle['life_outcome'] == 'blocked' or cycle['life_process']['timed_out']:
                    report['reason'] = 'life_result_requires_review'; break
                if report['gm_calls'] < scope['max_gm_calls'] and (deadline-utc()).total_seconds() > 90:
                    if global_unknown_gms(load_state(Path(scope['gm_state_dir']))):
                        cycle['gm_status'] = 'held_unacknowledged_usage'
                    else:
                        report['status'] = 'running_gm'; persist()
                        gm = f'gm-{((gm_offset+index-1)%10)+1:02}'
                        gm_command = [sys.executable, str(ROOT/'tools/gm_runner.py'), 'observe',
                            '--config', scope['gm_config'], '--key-file', scope['gm_key_file'],
                            '--state-dir', scope['gm_state_dir'], '--evidence', str(evidence),
                            '--gm', gm, '--max-gms', '1', '--max-issues-per-gm', '2',
                            '--max-prompt-bytes', '50000', '--timeout', '60',
                            '--autonomy-policy', scope['gm_policy'], '--prior-ledger', scope['gm_accounting_reference']]
                        gm_host = directory/'gm-host'
                        cycle['gm_process'] = run_owned(gm_command, gm_host, 75, environment, progress)
                        report['active_processes'] = 0
                        summaries = []
                        for line in (gm_host/'host.log').read_text(encoding='utf-8').splitlines():
                            try: value = json.loads(line)
                            except json.JSONDecodeError: continue
                            if isinstance(value, dict) and value.get('kind') == 'gm_observe': summaries.append(value)
                        summary = summaries[-1] if summaries else {}
                        calls = summary.get('dispatched')
                        report['gm_calls'] += calls if type(calls) is int else 1
                        cycle['gm_status'] = summary.get('status', 'unknown')
                        cycle['gm_run_id'] = summary.get('run_id')
                        cycle['gm_id'] = gm
                        if cycle['gm_process']['timed_out'] or not summaries:
                            cycle['gm_status'] = 'requires_review'
                cycle['ending_seq'] = decode(world.read_bytes())['life']['seq']
                cycle['status'] = 'closed'
                persist()
    except BaseException as error:
        report['reason'] = 'supervisor_error:' + type(error).__name__
        raise
    finally:
        report['status'] = 'stopped'
        report['active_processes'] = 0
        report['finished_utc'] = utc().isoformat()
        report['final_ledger'] = ledger_totals(scope['ledger'])
        report['final_checkpoint'] = checkpoint(world, Path(scope['checkpoint_dir']))['checkpoints'][-1]
        for_world(world).export()
        persist()
    print(json.dumps({k:report[k] for k in ('status','reason','npc_calls','gm_calls','finished_utc')}))
    return 0 if report['reason'] in ('deadline_settlement_reserve','window_budget_reached','requested_stop') else 1


if __name__ == '__main__': raise SystemExit(main())
