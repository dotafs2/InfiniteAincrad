"""Import assets with editor plugins disabled; always restore the user's settings."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    project = ROOT / 'game/project.godot'
    before = project.read_bytes()
    text = before.decode('utf-8')
    disabled, count = re.subn(r'(\[editor_plugins\]\s*\n)enabled=[^\n]*',
                              r'\1enabled=PackedStringArray()', text, count=1)
    if count != 1:
        raise RuntimeError('Expected one editor_plugins setting')
    try:
        project.write_text(disabled, encoding='utf-8', newline='\n')
        return subprocess.call([sys.executable, str(ROOT / 'tools/run_pcg_tool.py'),
                                '--out', args.out, '--timeout', '180', '--',
                                args.godot, '--headless', '--path', str(ROOT / 'game'),
                                '--editor', '--import'], cwd=ROOT)
    finally:
        project.write_bytes(before)

if __name__ == '__main__':
    raise SystemExit(main())
