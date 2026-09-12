"""Run one bounded, owned Godot process and retain stdout, stderr, PID and exit code.

Example: python tools/run_godot.py --godot C:/path/Godot.exe --name core --
         --headless --script res://tests/core_acceptance.gd
No shell, no model calls, no global process cleanup.
"""
import argparse
from contextlib import nullcontext
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import sys
import time

if os.name == 'nt':
    from owned_windows_job import WindowsProcessTree

# Windows shells may still select a legacy console codec. Engine logs and
# evidence are UTF-8; printing a Chinese result must not turn engine exit 0 into
# a failed wrapper after the owned process already completed successfully.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

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

def note_tree(state):
    previous = [item['pid'] for item in record.get('process_tree', {}).get('observed_members', [])]
    record['process_tree'] = state
    if previous != [item['pid'] for item in state['observed_members']]:
        record_state()


with output_path.open('w', encoding='utf-8') as stdout, error_path.open('w', encoding='utf-8') as stderr:
    # Windows console launchers can have a distinct, longer-lived engine child.
    # A job is assigned before the suspended launcher can create descendants.
    context = WindowsProcessTree(command, cwd=ROOT, stdout=stdout, stderr=stderr) if os.name == 'nt' else nullcontext(None)
    with context as tree:
        child = tree.process if tree else subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr)
        record.update(pid=child.pid, status='running')
        if tree:
            record['process_tree'] = tree.snapshot()
        record_state()
        try:
            result = tree.wait(args.timeout, on_poll=note_tree) if tree else child.wait(timeout=args.timeout)
            exit_code_source = 'wrapper'
            if tree and result == 0 and tree.snapshot()['observed_nonzero_exits']:
                # A successful console wrapper cannot hide a recorded engine
                # failure. Unobserved short-lived members remain explicitly unknown.
                result = 1
                exit_code_source = 'observed_member_failure'
            record.update(status='exited', exit_code=result, exit_code_source=exit_code_source)
        except subprocess.TimeoutExpired:
            if tree:
                tree.terminate(124)
            else:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
            result = 124
            record.update(status='terminated_owned_process_after_timeout', exit_code=result, exit_code_source='runner_timeout')
        except BaseException:
            record.update(status='terminated_owned_process_on_interrupt', exit_code=130, exit_code_source='runner_interrupt')
            try:
                if tree:
                    tree.terminate(130)
                else:
                    child.terminate()
                    child.wait(timeout=5)
            except BaseException:
                record['cleanup_error'] = 'owned_process_cleanup_failed; job close still requested'
            raise
        finally:
            original_error = sys.exc_info()[0] is not None
            try:
                record.update(wrapper_exit_code=child.poll(),
                              elapsed_seconds=round(time.monotonic()-start, 3),
                              finished_at_utc=dt.datetime.now(dt.timezone.utc).isoformat())
                if tree:
                    record['process_tree'] = tree.snapshot()
                record_state()
            except BaseException:
                if not original_error:
                    raise  # Metadata failure must not hide the original callback/interrupt.
print(json.dumps(record, ensure_ascii=False))
for path in (output_path, error_path):
    content = path.read_text(encoding='utf-8', errors='replace')
    if content:
        print(path.name + ':\n' + content[-14000:])
sys.exit(result)
