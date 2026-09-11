"""Build and check one Windows .NET preview; no network model calls or publication.

Requires Python 3.11+, dotnet SDK 8+, official Godot 4.7.2 .NET and its templates.
Each invocation creates a new output directory. Existing builds/saves are never reset.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.0.1-preview'
ENGINE_VERSION = '4.7.2.stable.mono.official.ed1daf0bf'
SUITES = ('core_acceptance', 'decision_boundary_acceptance', 'resident_knowledge',
          'oga_acceptance', 'street_resume_edges')


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    godot = args.godot.resolve()
    # On Windows the console wrapper waits for the entire child job, including
    # compiler servers. Invoke the actual engine with redirected logs instead.
    if godot.name.endswith('_console.exe'):
        engine_exe = godot.with_name(godot.name.replace('_console.exe', '.exe'))
        if engine_exe.is_file():
            godot = engine_exe
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output = (args.output or ROOT / 'exports' / f'windows-{stamp}').resolve()
    if any(output.is_relative_to(ROOT / name) for name in ('game', 'third_party', 'distribution')):
        raise ValueError('Output must be outside the source directories copied into a build.')
    output.mkdir(parents=True, exist_ok=False)
    evidence = output / 'evidence'
    evidence.mkdir()
    package = output / f'InfiniteAincrad-{VERSION}-win-x64'
    package.mkdir()
    # Godot's publish restore rewrites lock files for ExportRelease/win-x64.
    # Build a fresh source snapshot so the checkout and pinned upstream bytes stay intact.
    source_root = output / 'source-snapshot'
    source_root.mkdir()
    ignore = shutil.ignore_patterns('.godot', '.git', 'bin', 'obj', '__pycache__',
                                    'private', 'saves', '.env', '.env.*', '*.log', '*.user')
    for directory in ('game', 'third_party'):
        shutil.copytree(ROOT / directory, source_root / directory, ignore=ignore)
    source_hashes = {p.relative_to(source_root).as_posix(): digest(p)
                     for p in sorted(source_root.rglob('*')) if p.is_file()}
    write_json(evidence / 'source-SHA256.json', source_hashes)
    upstream = json.loads((ROOT / 'third_party/opengameagent.lock.json').read_text(encoding='utf-8'))
    for entry in upstream['files']:
        if source_hashes.get(entry['path']) != entry['sha256']:
            raise RuntimeError(f'Pinned upstream bytes changed: {entry["path"]}')
    env = os.environ.copy()
    env.update(DOTNET_CLI_HOME=str(ROOT / 'tmp' / 'dotnet-home'),
               NUGET_PACKAGES=str(ROOT / 'tmp' / 'nuget-packages'),
               DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1',
               DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1',
               DOTNET_GENERATE_ASPNET_CERTIFICATE='false',
               DOTNET_ADD_GLOBAL_TOOLS_TO_PATH='false',
               DOTNET_CLI_USE_MSBUILD_SERVER='0', MSBUILDDISABLENODEREUSE='1',
               UseSharedCompilation='false',
               APPDATA=str(evidence / 'appdata'),
               LOCALAPPDATA=str(evidence / 'local-appdata'))
    for name in list(env):
        if name.startswith('AINCRAD_'):
            del env[name]
    for name in ('APPDATA', 'LOCALAPPDATA'):
        Path(env[name]).mkdir()
    # Keep the editor's installed template location (including setup-godot on CI).
    # Only game/test processes need the isolated application-data directory.
    editor_env = env.copy()
    for name in ('APPDATA', 'LOCALAPPDATA'):
        if name in os.environ:
            editor_env[name] = os.environ[name]
        else:
            editor_env.pop(name, None)
    records = []

    def run(name, command, timeout=90, cwd=ROOT, child_env=None):
        command = [str(item) for item in command]
        record = {'name': name, 'command': command, 'cwd': str(cwd),
                  'started_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
        record_path = evidence / f'{name}.process.json'
        started = time.monotonic()
        with (evidence / f'{name}.log').open('w', encoding='utf-8') as log:
            child = subprocess.Popen(command, cwd=cwd, env=child_env or env,
                                     stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            record.update(pid=child.pid, status='running')
            write_json(record_path, record)
            try:
                code = child.wait(timeout=timeout)
                record.update(exit_code=code, status='exited')
            except BaseException:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
                record.update(exit_code=child.returncode, status='terminated_owned_process')
                raise
            finally:
                record['elapsed_seconds'] = round(time.monotonic() - started, 3)
                write_json(record_path, record)
        records.append(record)
        text = (evidence / f'{name}.log').read_text(encoding='utf-8', errors='replace')
        print(f'{name}: exit {code} ({record["elapsed_seconds"]}s)', flush=True)
        if code or 'SCRIPT ERROR:' in text or 'Parse Error:' in text or (name in ('import', 'export', 'first-start', 'cold-restore') and 'ERROR:' in text):
            raise RuntimeError(f'{name} failed; see {evidence / (name + ".log")}\n{text[-3000:]}')
        return text.strip()

    actual_version = run('godot-version', [godot, '--version'])
    if actual_version != ENGINE_VERSION:
        raise RuntimeError(f'Expected {ENGINE_VERSION}; got {actual_version!r}')
    sdk_version = run('dotnet-version', ['dotnet', '--version'])
    asset = ROOT / 'game/assets/market/StartingTown_Market_CraftV5.glb'
    asset_hash = digest(asset)
    if asset_hash != '2e680ec8814a6aa7f4d09c74ad20fb859b5ccae5e3ef161f51d70e9c40f1b67d':
        raise RuntimeError('Market asset is missing, changed, or still an LFS pointer. Run git lfs pull.')
    project = source_root / 'game/InfiniteAincrad.csproj'
    run('restore', ['dotnet', 'restore', project, '--locked-mode'], timeout=240)
    run('build', ['dotnet', 'build', project, '--no-restore', '--disable-build-servers', '-v', 'minimal'], timeout=180)
    engine = [godot, '--path', source_root / 'game']
    run('import', engine + ['--headless', '--editor', '--import'], timeout=180, child_env=editor_env)
    for suite in SUITES:
        run(suite, engine + ['--headless', '--script', f'res://tests/{suite}.gd'])
    cold_save = evidence / 'core-cold.json'
    for phase in ('cold-write', 'cold-read'):
        run(phase, engine + ['--headless', '--script', 'res://tests/core_acceptance.gd',
                            '--', f'--phase={phase}', f'--save-path={cold_save}'])
    executable = package / 'InfiniteAincrad.exe'
    run('export', engine + ['--headless', '--export-release', 'Windows Preview', executable], timeout=300, child_env=editor_env)
    if not executable.is_file() or not executable.with_suffix('.pck').is_file():
        raise RuntimeError('Exporter did not produce both EXE and PCK.')
    runtimes = list(package.rglob('coreclr.dll'))
    if len(runtimes) != 1 or not list(package.rglob('InfiniteAincrad.dll')):
        raise RuntimeError('Self-contained .NET runtime or project assembly missing from package.')
    shutil.copytree(ROOT / 'distribution', package, dirs_exist_ok=True)
    notices = package / 'licenses'
    notices.mkdir(exist_ok=True)
    shutil.copy2(ROOT / 'third_party/OpenGameAgent/LICENSE', notices / 'OpenGameAgent-MIT.txt')
    # These are exact upstream files checked into distribution, not a license grant for this project.
    for required in ('Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'dotnet-LICENSE.txt', 'dotnet-THIRD-PARTY-NOTICES.txt'):
        if not (notices / required).is_file():
            raise RuntimeError(f'Missing distribution notice: {required}')
    source = run('source-revision', ['git', 'rev-parse', 'HEAD'])
    dirty = bool(run('source-status', ['git', 'status', '--porcelain']))
    manifest = {'version': VERSION, 'source_commit': source, 'source_dirty': dirty,
                'godot': actual_version, 'dotnet_sdk': sdk_version, 'market_sha256': asset_hash,
                'source_snapshot_sha256': digest(evidence / 'source-SHA256.json'),
                'provider': 'offline_observation_fixture', 'paid_calls': 0,
                'rights_status': 'project_license_proposal_pending',
                'built_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
    write_json(package / 'build-info.json', manifest)
    checksums = {p.relative_to(package).as_posix(): digest(p)
                 for p in sorted(package.rglob('*')) if p.is_file()}
    write_json(package / 'SHA256.json', checksums)
    archive = output / (package.name + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zip_out:
        for path in sorted(package.rglob('*')):
            if path.is_file():
                zip_out.write(path, path.relative_to(package.parent))
    (output / 'SHA256SUMS.txt').write_text(f'{digest(archive)}  {archive.name}\n', encoding='utf-8')
    # Verify bytes after extraction, away from the source tree and export working directory.
    extracted = evidence / 'unpacked with spaces'
    with zipfile.ZipFile(archive) as zip_in:
        zip_in.extractall(extracted)
    isolated = extracted / package.name
    for name, expected in checksums.items():
        if digest(isolated / name) != expected:
            raise RuntimeError(f'Package checksum mismatch: {name}')
    run('package-validation', [sys.executable, ROOT / 'tools/verify_windows_preview.py',
                              '--package', isolated, '--output', evidence / 'package-validation'], timeout=200)
    write_json(output / 'validation.json', {'passed': True, 'package': archive.name,
               'sha256': digest(archive), 'source_checks': list(SUITES) + ['cold-write', 'cold-read'],
               'package_checks': ['archive-checksums', 'no-dotnet-in-PATH', 'first-start', 'cold-restore-byte-equality'],
               'rendered_validation': False, 'external_testers': 0, 'paid_calls': 0})
    print(f'VALIDATED LOCAL TECHNICAL PREVIEW: {archive}\nEvidence: {evidence}', flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'FAILED: {error}', file=sys.stderr)
        sys.exit(1)
