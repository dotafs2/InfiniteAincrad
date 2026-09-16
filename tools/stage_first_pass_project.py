"""Copy source scripts and first-result GLBs into a self-contained local Godot project."""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'exports/interior-first-pass-20260916'
PROJECT = OUT / 'project'
PROJECT.mkdir(parents=True, exist_ok=True)
for name in ['project.godot', 'main.tscn', 'main.gd', 'house.gd','LICENSE','NOTICE.txt','Start.ps1','Start.cmd']:
    shutil.copy2(ROOT / 'experiments/interior-first-pass' / name, PROJECT / name)
shutil.copy2(ROOT / 'game/spatial/modular_house_component.gd', PROJECT / 'modular_house_component.gd')
axes = ROOT / 'Art/Generated/InteriorFirstPass20260916/assembly-axes.json'
if axes.exists(): shutil.copy2(axes,PROJECT / 'assembly-axes.json')
count = 0
for provider in ['tripo','meshy']:
    dest = PROJECT / 'assets' / provider
    dest.mkdir(parents=True, exist_ok=True)
    for source in (OUT / provider).glob('*.glb'):
        target = dest / source.name
        if not target.exists():
            shutil.copy2(source, target)
        count += 1
print(json.dumps({'project':str(PROJECT),'models_staged':count}))
