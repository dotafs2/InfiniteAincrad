"""Compile and inspect isolated skin shaders on macOS without any UI window.

This is supplementary shader/geometry QA, not a Godot frame or phone benchmark.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/skin-ui'


def run(command, log):
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=120)
    (OUT / log).write_text(result.stdout)
    if result.returncode or 'SCRIPT ERROR' in result.stdout:
        raise RuntimeError(f'Shader QA failed; see {OUT / log}')
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    completion = run([str(args.godot.resolve()), '--headless', '--path', str(ROOT),
                     '--script', 'tools/export_skin_render_fixture.gd', '--log-file',
                     str(OUT / 'fixture.engine.log'), '--', '--test'], 'fixture.log')
    if 'SKIN_RENDER_FIXTURE exported ten real mesh/material sets' not in completion:
        raise RuntimeError('Missing fixture completion marker')
    run(['python3', 'tools/check_skin_shaders.py'], 'glsl-prepare.log')
    with tempfile.TemporaryDirectory(prefix='hole-shader-qa-') as temp:
        binary = str(Path(temp) / 'render')
        run(['xcrun', 'clang', 'tools/skin_shader_offscreen.m', '-framework', 'Foundation',
             '-framework', 'OpenGL', '-o', binary, '-Wno-deprecated-declarations',
             '-Wno-incompatible-pointer-types'], 'offscreen-build.log')
        for time in ['0.5', '1.5']:
            output = run([binary, str(OUT), time], f'offscreen-{time}.log')
            if 'Compiled 5 shipped shader programs; rendered 10 skins' not in output:
                raise RuntimeError('Missing offscreen completion marker')
            run(['sips', '-s', 'format', 'png', str(OUT / f'shader-frame-{time}.ppm'),
                 '--out', str(OUT / f'shader-frame-{time}.png')], f'png-{time}.log')
    def pixels(time):
        return (OUT / f'shader-frame-{time}.ppm').read_bytes().split(b'\n', 3)[3]
    before, after = pixels('0.5'), pixels('1.5')
    if len(before) != 1600 * 640 * 3 or len(after) != len(before):
        raise RuntimeError('Unexpected offscreen output size')
    metrics = []
    for i, skin in enumerate(json.loads((OUT / 'render-inputs.json').read_text())):
        changed = difference = 0
        for y in range(i // 5 * 320, (i // 5 + 1) * 320):
            for x in range(i % 5 * 320, (i % 5 + 1) * 320):
                p = (y * 1600 + x) * 3
                delta = sum(abs(before[p+k] - after[p+k]) for k in range(3))
                difference += delta
                changed += delta > 12
        metrics.append(dict(skin=skin['id'], changed_pixels=changed,
                            mean_rgb_delta=round(difference / (320 * 320 * 3), 3)))
    failures = [m['skin'] + ': animated surface did not change' for m in metrics
                if m['skin'] in ['core_shell', 'tide', 'orbit', 'cinder', 'prism_vale']
                and m['changed_pixels'] < 300]
    shader_paths = [*sorted((ROOT/'fidelity/shaders').glob('*.gdshader')),
                    ROOT/'fidelity/cinder_flame.gdshader']
    result = dict(renderer='Apple Software Renderer / OpenGL 4.1', shaders_compiled=5,
                  skins_rendered=10, samples_seconds=[0.5, 1.5], frames=metrics, failures=failures,
                  scope='Shipped shader equations and exported meshes in a windowless CGL harness; '
                        'not a Godot frame, browser review or device benchmark. Geometry sampled at '
                        '0.5 seconds; local leaf/stone/spark motion is checked separately in Godot.',
                  shader_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in shader_paths})
    (OUT/'offscreen-shader-check.json').write_text(json.dumps(result, indent=2)+'\n')
    if failures:
        raise RuntimeError('; '.join(failures))
    print('Five shipped shaders compiled; ten skins rendered; animated surfaces changed pixels.')


if __name__ == '__main__':
    main()
