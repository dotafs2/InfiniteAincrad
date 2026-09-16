"""Archive the day's generated source assets, or restore their local export paths.

Only explicitly listed models, renders and authored project files are included.
Provider responses, credentials, caches and private world state are never copied.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / 'Art/SourceModels/20260916'
MANIFEST = ARCHIVE / 'manifest.json'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def safe_copy(source, target):
    if target.exists():
        if digest(source) != digest(target):
            raise FileExistsError(f'Refusing to overwrite different content: {target}')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def build():
    pairs = []
    for provider in ['meshy', 'tripo']:
        for source in sorted((ROOT / 'exports/interior-first-pass-20260916' / provider).glob('*.glb')):
            pairs.append((source, ROOT / 'experiments/interior-first-pass/assets' / provider / source.name))
    assert len(pairs) == 36, 'Both complete first-pass component batches are required'
    project = ROOT / 'exports/interior-first-pass-20260916/project'
    for name in ['modular_house_component.gd', 'assembly-axes.json', 'asset-provenance.json',
                 'visual-review.json', 'assets/shell/01_hearth_cottage.glb', 'assets/shell/manifest.json']:
        pairs.append((project / name, ROOT / 'experiments/interior-first-pass' / name))
    comparison = ROOT / 'exports/tripo-meshy-comparison-20260916'
    for pattern in ['*.glb', 'blend/*.blend']:
        for source in sorted(comparison.glob(pattern)):
            pairs.append((source, ARCHIVE / 'house-comparison' / source.relative_to(comparison)))
    for source in [comparison / 'overview.png', comparison / 'render-report.json', *sorted((comparison / 'renders').glob('*.png'))]:
        pairs.append((source, ROOT / 'Art/Generated/TripoMeshyComparison20260916/source-review' / source.relative_to(comparison)))
    for batch in ['floor1-pcg-20260916-v1', 'floor1-demo-props-20260916-v1']:
        for source in sorted((ROOT / 'exports/meshy-pool' / batch).glob('*.glb')):
            pairs.append((source, ARCHIVE / batch / source.name))
    records = []
    for source, target in pairs:
        safe_copy(source, target)
        records.append({'original_path': source.relative_to(ROOT).as_posix(),
                        'archive_path': target.relative_to(ROOT).as_posix(),
                        'bytes': target.stat().st_size, 'sha256': digest(target)})
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps({'date': '2026-09-16', 'files': records,
        'license_note': 'API-generated models retain provider-specific rights; see experiments/interior-first-pass/NOTICE.txt. No blanket MIT relicensing.',
        'restore': 'python tools/archive_art_20260916.py --restore'}, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'archived_files': len(records), 'bytes': sum(r['bytes'] for r in records)}))


def restore():
    records = json.loads(MANIFEST.read_text(encoding='utf-8'))['files']
    for record in records:
        source = (ROOT / record['archive_path']).resolve()
        target = (ROOT / record['original_path']).resolve()
        if not source.is_relative_to(ROOT) or not target.is_relative_to(ROOT / 'exports'):
            raise ValueError('Archive path escapes its expected directory')
        if digest(source) != record['sha256']:
            raise ValueError(f'Archive hash mismatch (run git lfs pull): {source}')
        safe_copy(source, target)
    print(json.dumps({'restored_files': len(records), 'api_calls': 0}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', action='store_true')
    args = parser.parse_args()
    restore() if args.restore else build()
