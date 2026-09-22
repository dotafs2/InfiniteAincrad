"""Capture the maps that ship no capture switch, plus the residents-walking clip.

Uses game/tests/map_capture.gd (viewport frames, scene untouched). The living
quarter run opens a *copy* of a saved world with --town-restore (read-only) and
the repository's offline physics walk probe, which moves real resident bodies
without any provider call.

  python -X utf8 tools/capture_map_frames.py [--only LABEL ...]
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
SCRIPT = 'res://tests/map_capture.gd'
QUARTER_SAVE = ROOT / 'tmp/mvp-autonomy-20260914/prepared/real/canonical-world.json'
OFF_SCREEN = ['--position', '-2400,-1400', '--resolution', '1280x720']

# label, scene, seconds, fps, warmup, extra user args
JOBS = [
    ('demo-town', 'res://scenes/demo_town.tscn', 12.0, 12.0, 10.0, ['town-mode']),
    ('street-trial', 'res://scenes/street_trial.tscn', 10.0, 12.0, 6.0, []),
    ('sao-town-quarter', 'res://scenes/sao_town_quarter.tscn', 12.0, 12.0, 8.0, []),
    ('navigation-mvp-house', 'res://scenes/navigation_mvp_house.tscn', 18.0, 12.0, 6.0, []),
]


def engine() -> Path:
    candidates = [
        Path(os.environ['GODOT_EXE']) if os.environ.get('GODOT_EXE') else None,
        ROOT / 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe',
        Path(os.environ.get('USERPROFILE', '')) / '.cache/level0-tools/godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe',
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    raise SystemExit('Godot 4.7.2 .NET not found; pass GODOT_EXE.')


def capture(label: str, scene: str, seconds: float, fps: float, warmup: float,
            extra: list[str], timeout: float) -> dict:
    target = OUT / label
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True, exist_ok=True)
    # Town-family scenes require an explicit separately migrated --town-save path;
    # a copy is used so the maintained world is never opened for write. The copy is
    # made *after* the capture directory is cleared, or it would be deleted again.
    if 'town-mode' in extra:
        extra = [item for item in extra if item != 'town-mode']
        save_copy = target / 'world-copy.json'
        shutil.copy2(QUARTER_SAVE, save_copy)
        extra = ['--town-save=' + str(save_copy), '--town-restore', *extra]
        for item in extra:
            if item.startswith('--quarter-report='):
                Path(item.split('=', 1)[1]).mkdir(parents=True, exist_ok=True)
    command = [str(engine()), '--path', str(ROOT / 'game'), *OFF_SCREEN,
               '--script', SCRIPT, '--',
               '--scene=' + scene, '--out=' + str(target),
               '--seconds=' + str(seconds), '--fps=' + str(fps), '--warmup=' + str(warmup),
               *extra]
    started = time.monotonic()
    timed_out = False
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 encoding='utf-8', errors='replace', timeout=timeout)
        code, stdout = process.returncode, process.stdout or ''
    except subprocess.TimeoutExpired as expired:
        code, timed_out = 124, True
        stdout = (expired.stdout.decode('utf-8', 'replace') if isinstance(expired.stdout, bytes) else (expired.stdout or ''))
    frames = sorted(p.name for p in target.rglob('frame_*.png'))
    walk_lines = [line for line in stdout.splitlines()
                  if 'QUARTER_WALK_LEG' in line or 'MAPCAPTURE' in line or 'LIVING_QUARTER_REPORT' in line]
    return {
        'label': label,
        'scene': scene,
        'exit_code': code,
        'timed_out': timed_out,
        'seconds': round(time.monotonic() - started, 1),
        'frames': len(frames),
        'walk_legs': len(walk_lines),
        'stdout_markers': walk_lines[-6:],
    }


def capture_quarter(timeout: float = 1500.0) -> dict:
    label = 'quarter-walk-motion'
    target = OUT / label
    # The scene's own camera is parked away from the walking routes, so the clip is
    # recorded from a read-only viewer camera above the market square. The probe
    # moves every active resident, prints QUARTER_WALK_LEG per leg and writes
    # physical_walks into report.json before the scene quits itself -- so the
    # capture window is long and slow rather than short and dense.
    extra = ['town-mode', '--quarter-probe', '--quarter-report=' + str(target / 'report'),
             '--camera-pos=2,42,46', '--camera-look=2,0,12']
    return capture(label, 'res://scenes/town_street.tscn', 260.0, 6.0, 10.0, extra, timeout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', action='append', default=None)
    parser.add_argument('--skip-quarter', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    summary_path = OUT / 'frame-capture-summary.json'
    previous = {}
    if summary_path.is_file():
        previous = {entry['label']: entry for entry in json.loads(summary_path.read_text(encoding='utf-8'))}
    results = []
    for label, scene, seconds, fps, warmup, extra in JOBS:
        if args.only and label not in args.only:
            if label in previous:
                results.append(previous[label])
            continue
        entry = capture(label, scene, seconds, fps, warmup, extra, timeout=600.0)
        results.append(entry)
        print(json.dumps({'event': 'captured', **{k: entry[k] for k in ('label', 'exit_code', 'frames', 'seconds')}}), flush=True)
    if not args.skip_quarter:
        entry = capture_quarter()
        results.append(entry)
        print(json.dumps({'event': 'captured', **{k: entry[k] for k in ('label', 'exit_code', 'frames', 'walk_legs')}}, ensure_ascii=False), flush=True)
    summary_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps({'summary': str(summary_path.relative_to(ROOT)), 'entries': len(results)}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
