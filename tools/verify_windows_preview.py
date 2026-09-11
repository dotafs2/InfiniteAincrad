"""Exercise an exported package without an editor/source path or model configuration.

Always use a new evidence directory and new isolated save. --rendered additionally
requires actual viewport captures; default headless checks do not prove visual quality.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rendered', action='store_true')
    args = parser.parse_args()
    package, output = args.package.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    checksums = json.loads((package / 'SHA256.json').read_text(encoding='utf-8'))
    for name, expected in checksums.items():
        path = (package / name).resolve()
        if not path.is_relative_to(package):
            raise RuntimeError('Checksum entry escapes package directory.')
        with path.open('rb') as file:
            if hashlib.file_digest(file, 'sha256').hexdigest() != expected:
                raise RuntimeError(f'Checksum mismatch: {name}')
    env = os.environ.copy()
    for name in list(env):
        if name.startswith('AINCRAD_'):
            del env[name]
    env.update(PATH=os.environ.get('SystemRoot', 'C:/Windows') + '/System32',
               APPDATA=str(output / 'appdata'), LOCALAPPDATA=str(output / 'local-appdata'),
               DOTNET_ROOT=str(output / 'no-global-dotnet'), DOTNET_MULTILEVEL_LOOKUP='0',
               COREHOST_TRACE='1')
    for name in ('APPDATA', 'LOCALAPPDATA'):
        Path(env[name]).mkdir()
    save = output / 'world.json'
    results = {}
    for phase in ('first-start', 'cold-restore'):
        capture = output / phase
        capture.mkdir()
        # Fixed render FPS can run simulated _process time ahead of physics and
        # async C# on a headless host. Use a real-time cap for arrival/timeout checks.
        command = [str(package / 'InfiniteAincrad.exe'), '--max-fps', '60']
        if not args.rendered:
            command.append('--headless')
        command += ['--', f'--street-smoke={capture}', f'--save-path={save}']
        if phase == 'cold-restore':
            before = save.read_bytes()
            command.append('--street-expect=resume-stable')
        env['COREHOST_TRACEFILE'] = str(output / f'{phase}.hosttrace.log')
        record = {'command': command, 'cwd': str(package), 'status': 'starting'}
        record_path = output / f'{phase}.process.json'
        started = time.monotonic()
        with (output / f'{phase}.log').open('w', encoding='utf-8') as log:
            child = subprocess.Popen(command, cwd=package, env=env, stdout=log,
                                     stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            record.update(pid=child.pid, status='running')
            record_path.write_text(json.dumps(record, indent=2), encoding='utf-8')
            try:
                code = child.wait(timeout=90)
                record.update(status='exited', exit_code=code)
            except BaseException:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
                record.update(status='terminated_owned_process', exit_code=child.returncode)
                raise
            finally:
                record['elapsed_seconds'] = round(time.monotonic() - started, 3)
                record_path.write_text(json.dumps(record, indent=2), encoding='utf-8')
        text = (output / f'{phase}.log').read_text(encoding='utf-8', errors='replace')
        if code or 'ERROR:' in text:
            raise RuntimeError(f'{phase} failed (exit {code}); {text[-2000:]}')
        result = json.loads((capture / 'evidence.json').read_text(encoding='utf-8'))
        if not result.get('passed'):
            raise RuntimeError(f'{phase} has no passing scenario evidence.')
        if phase == 'cold-restore' and before != save.read_bytes():
            raise RuntimeError('Cold restore changed the save bytes.')
        if args.rendered:
            image = capture / ('complete.png' if phase == 'first-start' else 'restored.png')
            if not image.is_file() or image.stat().st_size == 0:
                raise RuntimeError(f'Rendered capture missing: {image}')
        results[phase] = {'passed': True, 'elapsed_seconds': record['elapsed_seconds'],
                          'checks': result['checks'], 'water': result['water']}
        print(f'{phase}: passed ({record["elapsed_seconds"]}s)', flush=True)
    result = {'passed': True, 'rendered': args.rendered, 'external_testers': 0,
              'paid_calls': 0, 'cold_restore_byte_equal': True, 'scenarios': results}
    (output / 'validation.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'FAILED: {error}', file=sys.stderr)
        sys.exit(1)
