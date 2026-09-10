"""Run one bounded, owned Godot process and retain stdout, stderr, PID and exit code.

Example: python tools/run_godot.py --godot C:/path/Godot.exe --name core --
         --headless --script res://tests/core_acceptance.gd
No shell, no model calls, no global process cleanup.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True)
parser.add_argument('--name', required=True)
parser.add_argument('--timeout', type=int, default=45)
parser.add_argument('--out', type=Path, default=ROOT / 'tmp' / 'plugin-validation')
parser.add_argument('engine_args', nargs=argparse.REMAINDER)
args = parser.parse_args()
if not args.name.replace('-', '').replace('_', '').isalnum():
    parser.error('Name must be a simple evidence label')
args.out.mkdir(parents=True, exist_ok=True)
engine_args = args.engine_args[1:] if args.engine_args[:1] == ['--'] else args.engine_args
command = [args.godot, '--path', str(ROOT / 'game')] + engine_args
start = time.monotonic()
record = {'name': args.name, 'started_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
          'command': command, 'working_directory': str(ROOT), 'timeout_seconds': args.timeout}
output_path = args.out / (args.name + '.stdout.log')
error_path = args.out / (args.name + '.stderr.log')
record_path = args.out / (args.name + '.process.json')

def record_state():
    temporary = record_path.with_suffix('.next.json')
    temporary.write_text(json.dumps(record, indent=2), encoding='utf-8')
    os.replace(temporary, record_path)

with output_path.open('w', encoding='utf-8') as stdout, error_path.open('w', encoding='utf-8') as stderr:
    child = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                             creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    record.update(pid=child.pid, status='running')
    record_state()
    try:
        result = child.wait(timeout=args.timeout)
        record.update(status='exited', exit_code=result)
    except subprocess.TimeoutExpired:
        child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=5)
        result = 124
        record.update(status='terminated_owned_process_after_timeout', exit_code=result)
    except BaseException:
        child.terminate()
        child.wait(timeout=5)
        record.update(status='terminated_owned_process_on_interrupt', exit_code=130)
        raise
    finally:
        record.update(elapsed_seconds=round(time.monotonic()-start, 3),
                      finished_at_utc=dt.datetime.now(dt.timezone.utc).isoformat())
        record_state()
print(json.dumps(record, ensure_ascii=False))
for path in (output_path, error_path):
    content = path.read_text(encoding='utf-8', errors='replace')
    if content:
        print(path.name + ':\n' + content[-14000:])
sys.exit(result)
