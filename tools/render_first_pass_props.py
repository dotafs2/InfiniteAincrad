"""Blender: render untouched first results; skip finished views, never call a provider."""
import importlib.util
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('renderer', ROOT / 'tools/render_tripo_houses.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
dest = ROOT / 'Art/Generated/InteriorFirstPass20260916'
report_path = dest / 'raw-metrics.json'
report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
for provider in ['tripo', 'meshy']:
    folder = ROOT / 'exports/interior-first-pass-20260916' / provider
    for file in sorted(folder.glob('*.glb')):
        key = provider + '/' + file.stem
        if key in report and all((dest / 'props' / (provider+'-'+file.stem+'-'+v+'.png')).exists() for v in ['front','back']):
            continue
        r.reset_scene()
        bpy.data.orphans_purge(do_recursive=True)
        r.configure_render(640,640,24)
        imported = r.import_glb(file)
        metrics = r.measure(imported)
        holder,copies,factor = r.build_display_copy(imported)
        r.setup_world_and_lights()
        low,high = r.world_bounds(r.mesh_objects(copies))
        centre = (low+high)*0.5
        radius = max((high-low).length*0.5,0.3)
        for name,angle in [('front',38),('back',218)]:
            r.aim_camera(centre,radius,angle,18,'AssetCamera')
            r.render_to(dest / 'props' / (provider+'-'+file.stem+'-'+name+'.png'))
        report[key] = metrics
        report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'rendered_models':len(report)}))
