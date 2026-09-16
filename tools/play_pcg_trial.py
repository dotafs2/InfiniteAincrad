"""Open the native vegetation trial on a fresh private copy of the town save."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from check_living_quarter import ROOT, GODOT
from owned_windows_job import WindowsProcessTree
from create_demo_preview import create_preview


def find_godot(explicit=None):
    candidates = [explicit, os.environ.get('GODOT'), str(GODOT), shutil.which('godot'), shutil.which('godot-mono')]
    for candidate in candidates:
        if candidate and Path(candidate).is_file(): return Path(candidate).resolve()
    raise FileNotFoundError('Godot 4.7 .NET is required. Use --godot PATH or set GODOT.')


def prepare_runtime(godot, output):
    # A fresh checkout has neither Godot imports nor the C# bridge. Build once locally.
    dll = ROOT / 'game/.godot/mono/temp/bin/Debug/InfiniteAincrad.dll'
    if not dll.exists():
        dotnet = shutil.which('dotnet')
        if not dotnet: raise FileNotFoundError('.NET 8 SDK is required to build the Godot C# bridge')
        code = subprocess.call([sys.executable, str(ROOT / 'tools/run_pcg_tool.py'),
            '--out', str(output / 'build'), '--timeout', '180', '--', dotnet, 'build',
            str(ROOT / 'game/InfiniteAincrad.csproj')], cwd=ROOT)
        if code: raise RuntimeError('C# build failed; see the private launch build log')
    if not (ROOT / 'game/.godot/imported').exists():
        code = subprocess.call([sys.executable, str(ROOT / 'tools/import_pcg_project.py'),
            '--godot', str(godot), '--out', str(output / 'import')], cwd=ROOT)
        if code: raise RuntimeError('Godot import failed; see the private launch import log')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--save', type=Path, help='An existing migrated save; always opened as a copy')
    parser.add_argument('--demo', action='store_true', help='Open the furnished first demo town')
    parser.add_argument('--godot', type=Path, help='Godot 4.7 .NET executable')
    parser.add_argument('--prepare-only', action='store_true', help='Prepare imports and a private preview, without opening a window')
    args = parser.parse_args()
    source = args.save or ROOT / 'private/pcg-trial-20260916/world.json'
    if not source.exists() and args.save is None:
        source = ROOT / 'private/pcg-trial-20260916/preview-genesis.json'
        if not source.exists(): create_preview(source)
        print('Using a fresh offline preview seed. Original private history is not included.', flush=True)
    state = json.loads(source.read_text(encoding='utf-8'))
    if state.get('godot', {}).get('spatial_layout', {}).get('id') != 'first-floor-market-quarter-v1':
        raise RuntimeError('This preview requires the migrated living-quarter save')
    output = ROOT / 'private/pcg-trial-20260916' / ('visit-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    output.mkdir(parents=True)
    godot = find_godot(args.godot)
    prepare_runtime(godot, output)
    snapshot = output / 'world.json'
    shutil.copy2(source, snapshot)
    if args.prepare_only:
        print(json.dumps({'prepared_save':str(snapshot),'world_id':state['world_id'],'api_calls':0}))
        return 0
    command = [str(godot), '--path', str(ROOT / 'game'),
               'res://scenes/demo_town.tscn' if args.demo else 'res://experiments/pcg/native_trial.tscn', '--',
               '--town-restore', '--town-save=' + str(snapshot)]
    with (output / 'engine.log').open('w', encoding='utf-8') as log:
        with WindowsProcessTree(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT) as job:
            (output / 'process.json').write_text(json.dumps(job.snapshot(), indent=2))
            try:
                code = job.wait(86400)
            finally:
                if job.process.poll() is None:
                    job.terminate()
                (output / 'process.json').write_text(json.dumps(job.snapshot(), indent=2))
    return code

if __name__ == '__main__':
    raise SystemExit(main())
