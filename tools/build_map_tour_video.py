"""Assemble the captured map stills into one captioned tour video (fast path).

still -> 2.5 s captioned clip (veryfast x264) -> per-map concat -> final concat,
so no heavyweight filter graph is built. Input: tmp/map-tour/<label>/ from
tools/capture_map_tour.py. Output: docs/validation/map-tour-20260922/map-tour.mp4
"""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'tmp' / 'map-tour'
PARTS = WORK / 'parts'
OUT_DIR = ROOT / 'docs' / 'validation' / 'map-tour-20260922'
OUTPUT = OUT_DIR / 'map-tour.mp4'
FPS = 30
W, H = 1280, 720
STILL_SECONDS = 2.6
MAX_STILLS = 3
PREFERRED = ('aerial', 'overview', 'market', 'town', 'house', 'canopy', 'courtyard', 'street', 'capture', 'planter', 'front')

CAPTIONS = {
    'quarter-walk-motion': ('Living quarter - residents moving', 'Offline physics walk probe - no provider calls'),
    'quarter-walk': ('Living quarter', 'Aerial view with resident positions marked'),
    'demo-town': ('PCG demo town', '16 houses, 10 residents, 145 props, market street'),
    'expanded-world': ('Expanded world', 'Floor One terrain, roads and quarters'),
    'residences-review': ('Residences', 'Five authored residence variants'),
    'deepseek-residences': ('DeepSeek residences', 'Residence set for the living quarter'),
    'reel': ('Environment reel', 'Floor One - 20 environment assets in engine'),
    'environment-v2-review': ('Environment kit v2', 'Stylised vegetation, rock and prop review'),
    'environment-kit20': ('Environment kit 20', 'First-pass kit components in engine'),
    'floor1-art-preview': ('Floor 1 art preview', 'Street-level art and material pass'),
    'sao-town-quarter': ('SAO town quarter', 'Standalone floor-one starting-city blockout study'),
    'street-trial': ('Street trial', 'Street block layout trial'),
    'navigation-mvp-house': ('Navigation MVP', 'Route-graph walk: door, ladder and second floor'),
}
ORDER = ['quarter-walk-motion', 'quarter-walk', 'demo-town', 'expanded-world',
         'residences-review', 'deepseek-residences', 'reel', 'environment-v2-review',
         'environment-kit20', 'floor1-art-preview', 'sao-town-quarter', 'street-trial',
         'navigation-mvp-house']
## Frames captured at this rate; motion clips are trimmed to MOTION_CAP seconds.
FRAME_RATE_IN = 12.0
FRAME_RATE_BY_LABEL = {'quarter-walk-motion': 6.0}
MOTION_CAP = {
    'quarter-walk-motion': 20.0,
    'navigation-mvp-house': 16.0,
    'demo-town': 12.0,
    'sao-town-quarter': 12.0,
    'street-trial': 10.0,
}

FONT_DIR = Path('C:/Windows/Fonts')
BG = (18, 24, 33)
TEXT = (234, 240, 246)
ACCENT = (255, 213, 79)
MUTED = (150, 165, 182)


def font(name: str, size: int):
    try:
        return ImageFont.truetype(str(FONT_DIR / name), size)
    except OSError:
        return ImageFont.load_default()


def build_card(title: str, lines: list[str], path: Path) -> None:
    image = Image.new('RGB', (W, H), BG)
    draw = ImageDraw.Draw(image)
    for y in range(H):
        shade = int(18 + 16 * (y / H))
        draw.line([(0, y), (W, y)], fill=(shade, shade + 6, shade + 13))
    draw.text((48, 130), 'INFINITE AINCRAD', font=font('segoeuib.ttf', 22), fill=ACCENT)
    draw.text((48, 170), title, font=font('segoeuib.ttf', 46), fill=TEXT)
    draw.line([(48, 250), (W - 48, 250)], fill=(60, 74, 92), width=2)
    y = 290
    for line in lines:
        draw.text((48, y), line, font=font('segoeui.ttf', 22), fill=MUTED)
        y += 40
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def pick_stills(label: str) -> list[Path]:
    directory = WORK / label
    if not directory.is_dir():
        return []
    stills = [p for p in directory.rglob('*.png') if p.is_file() and not p.name.startswith('frame_')]
    def rank(path: Path) -> tuple:
        name = path.name.lower()
        preferred = 0 if any(key in name for key in PREFERRED) else 1
        return (preferred, name)
    return sorted(stills, key=rank)[:MAX_STILLS]


def frames_for(label: str) -> list[Path]:
    """Captured viewport frames for the maps that ship no capture switch."""
    for candidate in (WORK / label / 'frames', WORK / label):
        if candidate.is_dir():
            found = sorted(candidate.glob('frame_*.png'))
            if len(found) >= 20:
                return found
    return []


def run(command: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')


def make_still_clip(ffmpeg: str, image: Path, title: str, caption: str, target: Path) -> bool:
    graph = (f'fps={FPS},scale={W}:{H}:force_original_aspect_ratio=decrease,'
             f'pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=0x121821,setsar=1,format=yuv420p,'
             f"drawtext=fontfile=caption-bold.ttf:text='{title}':fontcolor=white:fontsize=32:"
             f'box=1:boxcolor=black@0.55:boxborderw=18:x=(w-text_w)/2:y=h-104,'
             f"drawtext=fontfile=caption-bold.ttf:text='{caption}':fontcolor=white@0.85:fontsize=21:"
             f'box=1:boxcolor=black@0.45:boxborderw=12:x=(w-text_w)/2:y=h-56')
    result = run([ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                  '-loop', '1', '-t', str(STILL_SECONDS), '-i', str(image),
                  '-vf', graph, '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '21',
                  '-pix_fmt', 'yuv420p', '-r', str(FPS), str(target)])
    return result.returncode == 0 and target.exists()


def concat(ffmpeg: str, clips: list[Path], target: Path, workdir: Path) -> bool:
    listing = workdir / (target.stem + '.txt')
    listing.write_text(''.join(f"file '{c.as_posix()}'\n" for c in clips), encoding='utf-8')
    result = run([ffmpeg, '-y', '-hide_banner', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
                  '-i', str(listing), '-c', 'copy', str(target)])
    return result.returncode == 0 and target.exists()


def main() -> int:
    summary_path = WORK / 'capture-summary.json'
    available: set[str] = set()
    for summary_name in ('capture-summary.json', 'frame-capture-summary.json'):
        candidate = WORK / summary_name
        if candidate.is_file():
            for entry in json.loads(candidate.read_text(encoding='utf-8')):
                if entry.get('file_count') or entry.get('frames'):
                    available.add(entry['label'])
    labels = [label for label in ORDER if label in available and (pick_stills(label) or frames_for(label))]
    missing = [label for label in ORDER if label not in labels]
    if not labels:
        print(json.dumps({'error': 'no captured material to assemble'}))
        return 1

    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    if PARTS.exists():
        shutil.rmtree(PARTS)
    PARTS.mkdir(parents=True, exist_ok=True)
    font_target = PARTS / 'caption-bold.ttf'
    shutil.copy2(FONT_DIR / 'segoeuib.ttf', font_target)
    base = (f'fps={FPS},scale={W}:{H}:force_original_aspect_ratio=decrease,'
            f'pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=0x121821,setsar=1,format=yuv420p')

    map_clips: list[Path] = []
    detail = []
    for label in labels:
        title, caption = CAPTIONS.get(label, (label, ''))
        frames = frames_for(label)
        merged = PARTS / f'clip-{label}.mp4'
        if frames:
            cap = MOTION_CAP.get(label, 12.0)
            rate = FRAME_RATE_BY_LABEL.get(label, FRAME_RATE_IN)
            # The filter chain normalises to FPS before the frame cap applies, so the
            # cap is counted in output frames or the clip would be cut short.
            limit = int(cap * FPS)
            pattern = frames[0].parent / (frames[0].stem.rsplit('_', 1)[0] + '_%05d.png')
            graph = (f'[0:v]{base},'
                     f"drawtext=fontfile=caption-bold.ttf:text='{title}':fontcolor=white:fontsize=32:"
                     f'box=1:boxcolor=black@0.55:boxborderw=18:x=(w-text_w)/2:y=h-104,'
                     f"drawtext=fontfile=caption-bold.ttf:text='{caption}':fontcolor=white@0.85:fontsize=21:"
                     f'box=1:boxcolor=black@0.45:boxborderw=12:x=(w-text_w)/2:y=h-56[outv]')
            result = run([ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                          '-framerate', str(rate), '-i', str(pattern),
                          '-frames:v', str(limit), '-filter_complex', graph, '-map', '[outv]',
                          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '21',
                          '-pix_fmt', 'yuv420p', '-r', str(FPS), str(merged)])
            if result.returncode == 0 and merged.exists():
                map_clips.append(merged)
                detail.append({'label': label, 'kind': 'motion', 'frames': min(len(frames), limit)})
                print(json.dumps({'event': 'clip', **detail[-1]}), flush=True)
            continue
        clips = []
        for index, still in enumerate(pick_stills(label)):
            clip = PARTS / f'{label}-{index:02d}.mp4'
            if make_still_clip(ffmpeg, still, title, caption, clip):
                clips.append(clip)
        if not clips:
            continue
        merged = PARTS / f'clip-{label}.mp4'
        if concat(ffmpeg, clips, merged, PARTS):
            map_clips.append(merged)
            detail.append({'label': label, 'stills': len(clips)})
            print(json.dumps({'event': 'clip', **detail[-1]}), flush=True)

    if not map_clips:
        print(json.dumps({'error': 'no clips'}))
        return 1

    build_card('Project map tour', [
        f'{len(map_clips)} captured scenes from the repository',
        'Rendered off-screen by each scene\'s own capture switch',
        'No save writes, no model calls, no desktop takeover',
    ], PARTS / 'card-title.png')
    build_card('Captured with the project\'s own switches', [
        'tools/capture_map_tour.py  ·  tools/build_map_tour_video.py',
        'Next: demo town, SAO quarter and the navigation MVP house',
    ], PARTS / 'card-end.png')

    title_clip = PARTS / 'title.mp4'
    end_clip = PARTS / 'end.mp4'
    ok_title = make_still_clip(ffmpeg, PARTS / 'card-title.png', 'Infinite Aincrad', 'Project map tour - captured 2026-09-22', title_clip)
    ok_end = make_still_clip(ffmpeg, PARTS / 'card-end.png', 'Captured from the project itself', 'No save writes - no provider calls', end_clip)
    sequence = ([title_clip] if ok_title else []) + map_clips + ([end_clip] if ok_end else [])
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    merged = concat(ffmpeg, sequence, OUTPUT, PARTS)
    duration = run([ffmpeg, '-hide_banner', '-i', str(OUTPUT)]).stderr
    seconds = next((line.strip() for line in duration.splitlines() if 'Duration' in line), '')
    print(json.dumps({
        'ok': merged,
        'output': str(OUTPUT),
        'output_bytes': OUTPUT.stat().st_size if OUTPUT.exists() else 0,
        'clips': detail,
        'missing_maps': missing,
        'duration_line': seconds.strip(),
    }, indent=2))
    return 0 if merged else 1


if __name__ == '__main__':
    sys.exit(main())
