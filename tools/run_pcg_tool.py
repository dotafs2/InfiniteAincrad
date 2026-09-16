"""Run one explicitly requested PCG experiment tool in an owned Windows job."""
import argparse
import json
from pathlib import Path
import subprocess
import time
from owned_windows_job import WindowsProcessTree

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--timeout', type=int, default=240)
    p.add_argument('command', nargs=argparse.REMAINDER)
    a = p.parse_args()
    command = a.command[1:] if a.command[:1] == ['--'] else a.command
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    with (out/'tool.log').open('w', encoding='utf-8') as log:
        with WindowsProcessTree(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT) as job:
            print(json.dumps({'pid':job.process.pid, 'log':str(out/'tool.log')}), flush=True)
            (out/'process.json').write_text(json.dumps(job.snapshot(), indent=2))
            offset, last = 0, 0.0
            def inspect(state):
                nonlocal offset, last
                if time.monotonic()-last < 1: return
                last = time.monotonic()
                (out/'process.json').write_text(json.dumps(state, indent=2))
                with (out/'tool.log').open(encoding='utf-8', errors='replace') as reader:
                    reader.seek(offset)
                    chunk = reader.read(131072)
                    offset = reader.tell()
                if 'SCRIPT ERROR:' in chunk or '\nERROR:' in chunk or '"event": "stopped"' in chunk:
                    raise RuntimeError('Tool error: stop and ask the user; see tool.log')
            try:
                code = job.wait(a.timeout, on_poll=inspect)
            except (subprocess.TimeoutExpired, RuntimeError) as error:
                print(str(error), flush=True)
                job.terminate()
                code = 1
            state = job.snapshot()
            (out/'process.json').write_text(json.dumps(state, indent=2))
    print(json.dumps({'exit_code':code, 'seconds':round(time.monotonic()-started,1),
                     'owned_active_processes':state['active_processes']}), flush=True)
    return code

if __name__ == '__main__':
    raise SystemExit(main())
