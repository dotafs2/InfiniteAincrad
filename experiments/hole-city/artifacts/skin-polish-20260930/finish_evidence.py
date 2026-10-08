from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
ids=['pizza_party','frosted_cake','fox_den','bunny_burrow','rocket_port','dragon_roost']
font='/System/Library/Fonts/Supplemental/Arial.ttf';normal=ImageFont.truetype(font,18);title=ImageFont.truetype(font,25)
canvas=Image.new('RGB',(1440,990),'#e1edf5');d=ImageDraw.Draw(canvas);d.text((24,14),'ORIGINAL SKIN POLISH · Offline asset comparison',font=title,fill='#243550');d.text((24,47),'Actual exported meshes. Blender lighting approximation. Not game screenshots or device performance evidence.',font=normal,fill='#324662')
for i,name in enumerate(ids):
 x=(i%3)*480;y=90+(i//3)*440;d.text((x+15,y),name.replace('_',' ').title(),font=title,fill='#243550')
 for j,folder in enumerate(['before','author']):
  im=Image.open(out/folder/'renders'/f'{name}.png').convert('RGBA');im.thumbnail((232,210));canvas.paste(im,(x+5+j*240,y+42),im)
  d.text((x+18+j*240,y+246),'BEFORE' if j==0 else 'AFTER',font=normal,fill='#324662')
  small=Image.open(out/folder/'renders'/f'{name}.png').convert('RGBA').resize((144,120),Image.Resampling.LANCZOS);canvas.paste(small,(x+40+j*240,y+276),small)
 d.text((x+15,y+402),'Small preview · identical presentation scale',font=normal,fill='#324662')
canvas.save(out/'before-after.png')
paths=['fidelity/skin_visual.gd','fidelity/skin_sculpt.gd','fidelity/skin_catalog.gd','fidelity/skin_motifs.gd','fidelity/skin_rarity.gd','tests/skin_polish_acceptance.gd']
manifest={'source_hashes':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},'changed_ids':ids,'before_hashes':{str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (out/'before').glob('*.gd')},'scope':'Six original existing Rare/Epic cosmetics. Blender CPU actual mesh previews, approximate Godot materials; no game/browser screenshot or phone-FPS claim. Thin original ring shader shown by base color.','reference_scope':'Official store URLs resolved but tool did not expose inspectable image pixels. No current direct visual parity claim.','receipts':{p.stem:json.loads(p.read_text())['checks'] for p in (out/'author').glob('final-*.json')}}
a=(out/'before/skin_catalog.gd').read_text();b=(root/'fidelity/skin_catalog.gd').read_text();catalog_before=[json.loads(line.rstrip(',')) for line in a.splitlines() if line.strip().startswith('{')];catalog_after=[json.loads(line.rstrip(',')) for line in b.splitlines() if line.strip().startswith('{')];changes={}
for old,new in zip(catalog_before,catalog_after):
 if old!=new:changes[new['id']]={k:{'before':old[k],'after':new[k]} for k in old if old[k]!=new[k]}
assert len(changes)==6 and all(set(v)=={'skill_desc'} for v in changes.values());manifest['catalog_changes']=changes
manifest['render_hashes']={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*/renders/*.png')}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
