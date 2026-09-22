"""Capture the project's own map scenes with their built-in capture switches.

Every run is off-screen (``--position -2400,-1400``) so recording never takes
over the user's desktop, and only scenes whose own code reports
``model_calls: 0`` / ``save_writes: 0`` are used. The living quarter is opened
through a *copy* of a saved world with ``--town-restore`` (read-only) plus the
repository's offline physics walk probe, which moves real resident bodies
without any provider call.

  python -X utf8 tools/capture_map_tour.py [--only LABEL ...]
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp' / 'map-tour'
ENGINE_CANDIDATES = [
    Path(os.environ.get('GODOT_EXE', '')) if os.environ.get('GODOT_EXE') else None,
    ROOT / 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe',
    Path(os.environ.get('USERPROFILE', '')) / '.cache/level0-tools/godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe',
]
OFF_SCREEN = ['--position', '-2400,-1400', '--resolution', '1280x720']

# label, scene, extra user args, timeout seconds
SCENES = [
    ('reel', 'res://scenes/floor1_environment_v2_reel.tscn', [], 420),
    ('environment-v2-review', 'res://scenes/floor1_environment_v2_review.tscn', [], 420),
    ('environment-kit20', 'res://scenes/floor1_environment_kit_20_preview.tscn', [], 420),
    ('residences-review', 'res://scenes/floor1_residences_review.tscn', [], 420),
    ('deepseek-residences', 'res://scenes/deepseek_residences_review.tscn', [], 420),
    ('floor1-art-preview', 'res://scenes/floor1_art_preview.tscn', [], 420),
    ('expanded-world', 'res://scenes/floor1_expanded_world.tscn', [], 600),
]

QUARTER_SAVE = ROOT / 'tmp/mvp-autonomy-20260914/prepared/real/canonical-world.json'


def find_engine() -> Path:
    for candidate in ENGINE_CANDIDATES:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    raise SystemExit('Godot 4.7.2 .NET not found; pass GODOT_EXE.')


def run(label: str, scene: str, user_args: list[str], timeout: float) -> dict:
    engine = find_engine()
    target = OUT / label
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True, exist_ok=True)
    command = [str(engine), '--path', str(ROOT / 'game'), *OFF_SCREEN, scene]
    if user_args:
        command += ['--', *user_args]
    started = time.monotonic()
    timed_out = False
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 encoding='utf-8', errors='replace', timeout=timeout)
        code = process.returncode
        tail = (process.stdout or '').strip().splitlines()[-3:]
    except subprocess.TimeoutExpired as expired:
        code = 124
        timed_out = True
        tail = ((expired.stdout or b'').decode('utf-8', 'replace') if isinstance(expired.stdout, bytes) else (expired.stdout or '')).strip().splitlines()[-3:]
    files = sorted(p.name for p in target.rglob('*') if p.is_file())
    return {
        'label': label,
        'scene': scene,
        'exit_code': code,
        'timed_out': timed_out,
        'seconds': round(time.monotonic() - started, 1),
        'files': files,
        'file_count': len(files),
        'stdout_tail': tail,
    }


def run_quarter() -> dict:
    """Local/offline quarter walk: a copy of a saved world, restore-only, probe on."""
    if not QUARTER_SAVE.is_file():
        return {'label': 'quarter-walk', 'skipped': 'no offline save copy at ' + str(QUARTER_SAVE)}
    engine = find_engine()
    work = ROOT / 'tmp' / 'map-tour' / 'quarter-walk'
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True, exist_ok=True)
    save_copy = work / 'world-copy.json'
    shutil.copy2(QUARTER_SAVE, save_copy)
    report = work / 'report'
    report.mkdir(parents=True, exist_ok=True)
    command = [str(engine), '--path', str(ROOT / 'game'), *OFF_SCREEN, 'res://scenes/town_street.tscn', '--',
               '--town-save=' + str(save_copy), '--town-restore', '--quarter-probe',
               '--quarter-report=' + str(report), '--town-capture=' + str(work / 'frames'),
               '--town-duration=60']
    started = time.monotonic()
    timed_out = False
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 encoding='utf-8', errors='replace', timeout=600)
        code = process.returncode
        tail = (process.stdout or '').strip().splitlines()[-6:]
    except subprocess.TimeoutExpired as expired:
        code = 124
        timed_out = True
        tail = ((expired.stdout or b'').decode('utf-8', 'replace') if isinstance(expired.stdout, bytes) else (expired.stdout or '')).strip().splitlines()[-6:]
    produced = sorted(str(p.relative_to(work)).replace('\\', '/') for p in work.rglob('*') if p.is_file())
    return {
        'label': 'quarter-walk',
        'scene': 'res://scenes/town_street.tscn',
        'exit_code': code,
        'timed_out': timed_out,
        'seconds': round(time.monotonic() - started, 1),
        'save_touched': 'copy only; original never opened for write',
        'files': produced[:60],
        'file_count': len(produced),
        'stdout_tail': tail,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', action='append', default=None, help='capture only this label (repeatable)')
    parser.add_argument('--skip-quarter', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    for label, scene, user_args, timeout in SCENES:
        if args.only and label not in args.only:
            continue
        capture_dir = OUT / label
        results.append(run(label, scene, [*user_args, '--capture-dir=' + str(capture_dir)], timeout))
        print(json.dumps({'event': 'captured', **{k: results[-1][k] for k in ('label', 'exit_code', 'timed_out', 'file_count')}}, ensure_ascii=False), flush=True)
    if not args.skip_quarter and (not args.only or 'quarter-walk' in args.only):
        results.append(run_quarter())
        print(json.dumps({'event': 'captured', **{k: results[-1][k] for k in ('label', 'exit_code', 'timed_out', 'file_count')}}, ensure_ascii=False), flush=True)
    summary = OUT / 'capture-summary.json'
    summary.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps({'summary': str(summary.relative_to(ROOT)), 'entries': len(results)}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
