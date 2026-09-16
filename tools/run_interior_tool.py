"""Bounded owned process runner for the first-pass comparison; no timed background jobs."""
import argparse
import json
import subprocess
import sys
from pathlib import Path
from owned_windows_job import WindowsProcessTree

p = argparse.ArgumentParser()
p.add_argument('--name', required=True)
p.add_argument('--timeout', type=int, default=180)
p.add_argument('command', nargs=argparse.REMAINDER)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / 'tmp/interior-first-pass-20260916/processes'
out.mkdir(parents=True, exist_ok=True)
if not a.name.replace('-', '').replace('_', '').isalnum():
    raise SystemExit('Invalid log name')
command = a.command[1:] if a.command[:1] == ['--'] else a.command
with (out / (a.name + '.stdout.log')).open('w', encoding='utf-8') as stdout, \
     (out / (a.name + '.stderr.log')).open('w', encoding='utf-8') as stderr:
    with WindowsProcessTree(command, cwd=root, stdout=stdout, stderr=stderr, stdin=subprocess.DEVNULL) as job:
        record = out / (a.name + '.process.json')
        record.write_text(json.dumps(job.snapshot(), indent=2), encoding='utf-8')
        print(json.dumps({'name': a.name, 'pid': job.process.pid}), flush=True)
        try:
            code = job.wait(a.timeout)
        except subprocess.TimeoutExpired:
            job.terminate(124)
            code = 124
        state = job.snapshot()
        record.write_text(json.dumps(state, indent=2), encoding='utf-8')
print(json.dumps({'name': a.name, 'exit_code': code, 'all_exited': state['all_members_exited']}))
if code:
    for suffix in ['stderr', 'stdout']:
        print('\n'.join((out / (a.name + '.' + suffix + '.log')).read_text(encoding='utf-8').splitlines()[-16:]))
raise SystemExit(code)
