"""Encode current shader motion as an explicitly labeled offline preview strip."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
a=OUT/'animation'
fontpath=ROOT/'assets/fonts/Fredoka.ttf'
font=ImageFont.truetype(str(fontpath),22)
small=ImageFont.truetype(str(fontpath),17)
ids=['core_shell','tide','cinder']
labels=['Core Shell · blue accretion','Tide · flowing water','Cinder · rising flame']
frames=[]
for i in range(48):
    strip=Image.new('RGB',(960,410),'#dcecff');draw=ImageDraw.Draw(strip)
    draw.text((18,10),'OFFLINE SHADER PREVIEW · current game assets',fill='#223c68',font=font)
    for j,skin in enumerate(ids):
        raw=np.frombuffer((a/f'{skin}-{i:03d}.rgba').read_bytes(),dtype=np.uint8).reshape(320,320,4).copy()
        alpha=raw[:,:,3].astype(np.float32)
        for c in range(3):raw[:,:,c]=np.clip(raw[:,:,c].astype(np.float32)*255/np.maximum(alpha,1),0,255).astype(np.uint8)
        raw[alpha==0,:3]=0
        image=Image.fromarray(raw,'RGBA');strip.paste(image,(j*320,40),image)
        draw.text((j*320+160,356),labels[j],anchor='mt',fill='#223c68',font=font)
    draw.text((480,389),'Shader motion only · fixed mesh poses · not an in-game recording',anchor='mt',fill='#466385',font=small)
    path=a/f'frame-{i:03d}.png';strip.save(path)
    frames.append({'file':path.name,'time':i/24,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
assert len({f['sha256'] for f in frames})==48
(a/'manifest.json').write_text(json.dumps({'scope':'Windowless offscreen shader-equation animation from current meshes/materials. Not engine gameplay or a screen capture. Geometry held at exported 0.5s pose; shader time samples 0 through 47/24s.','width':960,'height':410,'fps':24,'seconds':2,'ids':ids,'frames':frames},indent=2)+'\n')
print('48 distinct labeled 960x410 offline shader frames, 24 fps / 2 seconds')
