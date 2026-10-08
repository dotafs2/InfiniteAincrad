"""Encode the CGL asset renders; these are OFFLINE PREVIEWS, not game captures."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
records=json.loads((OUT/'render-inputs.json').read_text())
assert len(records)==44 and len({x['id'] for x in records})==44
catalog=[]
for record in records:
    p=OUT/(record['id']+'.rgba')
    pixels=np.frombuffer(p.read_bytes(),dtype=np.uint8).reshape(540,540,4).copy()
    # CGL accumulates premultiplied RGB over clear. Encode standard straight RGBA.
    a=pixels[:,:,3].astype(np.float32)
    for channel in range(3):
        pixels[:,:,channel]=np.clip(pixels[:,:,channel].astype(np.float32)*255/np.maximum(a,1),0,255).astype(np.uint8)
    pixels[a==0,:3]=0
    image=Image.fromarray(pixels,'RGBA')
    bbox=image.getbbox();assert bbox and min(bbox[:2])>3 and max(bbox[2:])<537,(record['id'],bbox)
    target=OUT/(record['id']+'.png');image.save(target)
    catalog.append({k:record[k] for k in ['id','name','group','tint','accent']}|{'file':target.name,'width':540,'height':540,'alpha_bounds':bbox,'meshes':len(record['meshes']),'triangles':sum(len(m['indices'])//3 for m in record['meshes']),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
assert len({x['sha256'] for x in catalog})==44
fontpath=ROOT/'assets/fonts/Fredoka.ttf'
font=ImageFont.truetype(str(fontpath),21)
small=ImageFont.truetype(str(fontpath),17)
large=ImageFont.truetype(str(fontpath),31)
sheet=Image.new('RGB',(1320,2170),'#dcecff');draw=ImageDraw.Draw(sheet)
draw.text((28,18),'OFFLINE ASSET PREVIEW · 44 current skins',fill='#223c68',font=large)
draw.text((28,58),'Exported game geometry + shader equations. Not an in-game screenshot.',fill='#466385',font=small)
for i,entry in enumerate(catalog):
    x=(i%6)*220;y=96+(i//6)*256
    thumb=Image.open(OUT/entry['file']).resize((214,214),Image.Resampling.LANCZOS)
    sheet.paste(thumb,(x+3,y),thumb)
    draw.text((x+110,y+214),entry['name'],anchor='mt',fill='#223c68',font=font)
    draw.text((x+110,y+239),'CLASSIC' if entry['group']=='foundation' else 'SPECIAL',anchor='mt',fill='#466385',font=small)
sheet.save(OUT/'contact-sheet.png')
paths=[ROOT/'fidelity/skin_catalog.gd',ROOT/'fidelity/skin_visual.gd',ROOT/'fidelity/skin_motifs.gd',*sorted((ROOT/'fidelity/shaders').glob('*.gdshader')),ROOT/'fidelity/cinder_flame.gdshader']
manifest={'scope':'OFFLINE ASSET PREVIEWS from current exported Godot meshes and material parameters in a windowless CGL renderer; not Godot screenshots, gameplay capture, or device performance evidence. Geometry sampled at 0.5s. Flat materials preserve actual unshaded colors; shipped procedural shader equations translated to GLSL. Camera is an elevated orthographic showcase framing, not a gameplay camera. No player progress loaded or written.','size':[540,540],'format':'PNG, RGBA, straight alpha','core_blue_verified':all(m['params'].get('core_blue')==1 for r in records if r['id']=='core_shell' for m in r['meshes'] if m['shader'].endswith('accretion.gdshader')),'count':len(catalog),'groups':{group:sum(e['group']==group for e in catalog) for group in ['foundation','resonance']},'renderer_log':(OUT/'render.log').read_text(),'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'catalog':catalog}
(OUT/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('44 distinct bounded transparent PNG previews; core_blue:',manifest['core_blue_verified'])
