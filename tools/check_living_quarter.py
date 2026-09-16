"""Bounded Godot check with an owned, kill-on-close process tree and logs on disk."""
import argparse
import json
import subprocess
import time
from pathlib import Path
from owned_windows_job import WindowsProcessTree

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path.home()/'.cache/level0-tools/godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--save', type=Path)
    p.add_argument('--import-only', action='store_true')
    p.add_argument('--headless', action='store_true')
    p.add_argument('--probe', action='store_true')
    p.add_argument('--state-check', action='store_true')
    p.add_argument('--baseline', type=Path)
    p.add_argument('--timeout', type=int, default=180)
    args = p.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    cmd = [str(GODOT), '--path', str(ROOT/'game')]
    if args.headless or args.import_only or args.state_check:
        cmd += ['--headless']
    if args.import_only:
        cmd += ['--editor', '--import']
    elif args.state_check:
        if not args.save or not args.baseline:
            p.error('--state-check requires --save and --baseline')
        cmd += ['--script','res://tests/living_quarter_state_check.gd','--',
                '--town-save='+str(args.save.resolve()), '--baseline='+str(args.baseline.resolve()),
                '--quarter-report='+str(out)]
    else:
        if not args.save:
            p.error('--save is required for a scene check')
        cmd += ['--resolution', '1920x1080', '--', '--town-restore',
                '--town-save='+str(args.save.resolve()), '--quarter-report='+str(out)]
        cmd.insert(cmd.index('--resolution'), 'res://scenes/town_street.tscn')
        if args.probe:
            cmd += ['--quarter-probe']
    with (out/'engine.log').open('w', encoding='utf-8') as log:
        with WindowsProcessTree(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT) as job:
            print(json.dumps({'started_pid':job.process.pid,'log':str(out/'engine.log')}), flush=True)
            (out/'process.json').write_text(json.dumps(job.snapshot(), indent=2))
            last_check, offset = 0.0, 0
            def stop_on_script_error(_state):
                nonlocal last_check, offset
                if time.monotonic()-last_check < 1:
                    return
                last_check = time.monotonic()
                with (out/'engine.log').open('r',encoding='utf-8',errors='replace') as reader:
                    reader.seek(offset)
                    chunk = reader.read(65536)
                    offset = reader.tell()
                if 'SCRIPT ERROR:' in chunk or '\nERROR:' in chunk:
                    raise RuntimeError('Godot reported an error; stop the owned check immediately')
            try:
                exit_code = job.wait(args.timeout, on_poll=stop_on_script_error)
            except subprocess.TimeoutExpired:
                job.terminate()
                exit_code = 124
            except RuntimeError:
                job.terminate()
                exit_code = 1
            state = job.snapshot()
            (out/'process.json').write_text(json.dumps(state, indent=2))
    lines = (out/'engine.log').read_text(encoding='utf-8', errors='replace').splitlines()
    errors = [line for line in lines if any(s in line for s in ['ERROR:', 'Error:', 'SCRIPT ERROR', 'LIVING_QUARTER_REPORT'])]
    print(json.dumps({'exit_code':exit_code, 'errors':errors[:35], 'owned_active_processes':state['active_processes']}, ensure_ascii=False))
    return exit_code


if __name__ == '__main__':
    raise SystemExit(main())
