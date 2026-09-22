"""Assemble the model-nav report video: title card, flowchart, scene footage, summary.

Uses the ffmpeg binary bundled with imageio-ffmpeg (no system install needed).
On-screen text is English (project documentation language policy).
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'tmp' / 'model-nav-report'
FRAMES = WORK / 'frames'
SCENE = WORK / 'scene.avi'
OUTPUT = ROOT / 'docs' / 'validation' / 'model-nav-20260922' / 'model-nav-report.mp4'
FPS = 30
FRAME_FPS = 30
W, H = 1280, 720

# Scene-shot captions, timed to the in-scene camera timeline (fixed 60 fps render).
# Note: drawtext text must avoid ':' and ',' characters — they break filtergraph parsing.
CAPTIONS = [
    (0.2, 2.0, 'Ten generated models placed as a market square'),
    (2.2, 4.0, 'The market street and the open doorway of the turret house'),
    (4.2, 6.5, 'Inside the house the staircase leads to the second floor'),
    (6.7, 9.6, 'NpcA climbs to floor 2 and reaches NpcB'),
    (9.8, 11.9, 'Headless acceptance 21 of 21 checks passed'),
]


def probe(ffmpeg: str, path: Path) -> str:
    result = subprocess.run([ffmpeg, '-hide_banner', '-i', str(path)],
                            capture_output=True, text=True, encoding='utf-8', errors='replace')
    for line in (result.stderr or '').splitlines():
        if 'Video:' in line:
            return line.strip()
    return '(no video stream found)'


def main() -> int:
    # The Godot movie writer froze part-way through this scene, so the report
    # footage comes from a viewport frame capture when one is present.
    frame_files = sorted(FRAMES.glob('frame_*.png')) if FRAMES.exists() else []
    use_frames = len(frame_files) > 120
    if not use_frames and not SCENE.exists():
        print(json.dumps({'error': 'no scene frames and no scene.avi', 'frames': str(FRAMES), 'avi': str(SCENE)}))
        return 1
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    font_bold = WORK / 'caption-bold.ttf'
    if not font_bold.exists():
        shutil.copy2('C:/Windows/Fonts/segoeuib.ttf', font_bold)

    print(json.dumps({
        'ffmpeg': ffmpeg,
        'scene_source': 'viewport frames' if use_frames else 'scene.avi',
        'scene_frames': len(frame_files) if use_frames else None,
        'scene_stream': None if use_frames else probe(ffmpeg, SCENE),
    }, indent=2))

    base = (f'fps={FPS},scale={W}:{H}:force_original_aspect_ratio=decrease,'
            f'pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=0x121821,setsar=1,format=yuv420p')
    drawtexts = []
    for index, (start, end, text) in enumerate(CAPTIONS):
        drawtexts.append(
            "drawtext=fontfile=caption-bold.ttf:text='{text}':fontcolor=white:fontsize=30:"
            "box=1:boxcolor=black@0.55:boxborderw=16:x=(w-text_w)/2:y=h-96:enable='between(t,{start},{end})'".format(
                text=text, start=start, end=end))
        drawtexts.append(
            "drawtext=fontfile=caption-bold.ttf:text='{n} / {total}':fontcolor=white@0.72:fontsize=20:"
            "box=1:boxcolor=black@0.45:boxborderw=10:x=w-text_w-40:y=36:enable='between(t,{start},{end})'".format(
                n=index + 1, total=len(CAPTIONS), start=start, end=end))

    filters = [
        f"[0:v]{base},fade=t=in:st=0:d=0.7[v0]",
        f"[1:v]{base}[v1]",
        f"[2:v]{base}," + ','.join(drawtexts) + "[v2]",
        f"[3:v]{base},fade=t=out:st=5.6:d=1.2[v3]",
        "[v0][v1][v2][v3]concat=n=4:v=1:a=0[outv]",
    ]
    graph = ';'.join(filters)
    (WORK / 'report.filters.txt').write_text(';\n'.join(filters) + '\n', encoding='utf-8')

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    scene_input = (['-framerate', str(FRAME_FPS), '-start_number', '0', '-i', str(FRAMES / 'frame_%05d.png')]
                   if use_frames else ['-i', str(SCENE)])
    command = [
        ffmpeg, '-y', '-hide_banner',
        '-loop', '1', '-t', '5', '-i', str(WORK / 'title.png'),
        '-loop', '1', '-t', '9', '-i', str(WORK / 'flowchart.png'),
        *scene_input,
        '-loop', '1', '-t', '7', '-i', str(WORK / 'summary.png'),
        '-filter_complex', graph,
        '-map', '[outv]',
        '-c:v', 'libx264', '-preset', 'medium', '-crf', '20',
        '-pix_fmt', 'yuv420p', '-r', str(FPS), '-movflags', '+faststart',
        str(OUTPUT),
    ]
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (result.stderr or '').strip().splitlines()[-6:]
    print(json.dumps({
        'exit_code': result.returncode,
        'stderr_tail': tail,
        'output': str(OUTPUT),
        'output_bytes': OUTPUT.stat().st_size if OUTPUT.exists() else 0,
    }, indent=2))
    return 0 if result.returncode == 0 and OUTPUT.exists() else 1


if __name__ == '__main__':
    sys.exit(main())
