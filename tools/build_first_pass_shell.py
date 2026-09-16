"""Blender: reuse the existing authored modular construction as a one-floor shell."""
import copy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('existing_house_authoring', ROOT / 'Art/Generated/Floor1Modular20260916/build_modular_houses.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
recipe = copy.deepcopy(module.SPECS['01_hearth_cottage'])
recipe['blocks'][0].update(floors=1, floor_h=3.2)
recipe['blocks'][0]['roof']['rise'] = 2.2
recipe.update(name_zh='首轮组件对照住宅', target_height=5.4, dormer=False)
out = ROOT / 'exports/interior-first-pass-20260916/project/assets/shell'
entry = module.build_variant('01_hearth_cottage', recipe, out, out / 'renders', render=False)
entry['source_glb'] = 'res://assets/shell/01_hearth_cottage.glb'
(out / 'manifest.json').write_text(json.dumps({'houses': [entry], 'authoring': 'Existing H88 modular shell, one floor; not AI house generation.'}, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'shell_triangles': entry['triangles_total'], 'openings': len(entry['openings'])}))
