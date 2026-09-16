"""Blender: derive a rigid placement rotation, so each untouched sword lies flat."""
import json
from pathlib import Path
import bpy
import numpy as np

root = Path(__file__).resolve().parents[1]
out = {}
for provider in ['tripo','meshy']:
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root / 'exports/interior-first-pass-20260916' / provider / 'sword.glb'))
    points = []
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for vert in obj.data.vertices:
                p = obj.matrix_world @ vert.co
                points.append([p.x,p.z,-p.y])
    array = np.asarray(points)
    values, vectors = np.linalg.eigh(np.cov(array.T))
    rotation = np.stack([vectors[:,2],vectors[:,0],vectors[:,1]])
    if np.linalg.det(rotation)<0: rotation[2] *= -1
    out[provider+'/sword'] = {'rotation_rows':rotation.tolist(), 'reason':'rigid assembly only: longest axis along workbench, thinnest axis vertical'}
target = root / 'Art/Generated/InteriorFirstPass20260916/assembly-axes.json'
target.write_text(json.dumps(out,indent=2),encoding='utf-8')
print('Two rigid sword placement rotations recorded; original GLBs unchanged.')
