"""Render recorded current-game UI commands. This is NOT a viewport capture.

Pillow approximates Godot's shadow, border rasterization and text emboldening.
No game scene or 3D previews are synthesized or substituted.
"""
import json
import math
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/ui-comparison'
S = 2

def font(size):
    f = ImageFont.truetype(str(ROOT / 'assets/fonts/Fredoka.ttf'), round(size*S))
    f.set_variation_by_axes([650, 100])
    return f

def rgba(c):
    return tuple(round(max(0, min(1, n))*255) for n in c)

def render(name):
    data = json.loads((OUT / f'{name}.json').read_text())
    image = Image.new('RGBA', (540*S, 960*S), '#dce3eb')
    at, angle, scale = [0,0], 0, [1,1]
    def point(p):
        x,y = p[0]*scale[0], p[1]*scale[1]
        return ((at[0]+x*math.cos(angle)-y*math.sin(angle))*S,
                (at[1]+x*math.sin(angle)+y*math.cos(angle))*S)
    for command in data['commands']:
        op,a = command['op'], command['args']
        layer = Image.new('RGBA', image.size)
        d = ImageDraw.Draw(layer)
        if op == 'transform':
            at,angle,scale = a
            continue
        if op == 'rect':
            (x,y,w,h),c,filled,width = a
            pts = [point(p) for p in [(x,y),(x+w,y),(x+w,y+h),(x,y+h)]]
            d.polygon(pts, fill=rgba(c))
        elif op in ('circle','arc'):
            center,radius = a[:2]
            start,end,count = (0,math.tau,120) if op=='circle' else a[2:5]
            pts = [point((center[0]+math.cos(start+(end-start)*i/(count-1))*radius,
                          center[1]+math.sin(start+(end-start)*i/(count-1))*radius)) for i in range(count)]
            if op=='circle': d.polygon(pts, fill=rgba(a[2]))
            else: d.line(pts, fill=rgba(a[5]), width=max(1,round(a[6]*S)), joint='curve')
        elif op in ('line','polyline','polygon'):
            pts,c = ([a[0],a[1]],a[2]) if op=='line' else a[:2]
            if op=='polygon':d.polygon([point(p) for p in pts], fill=rgba(c))
            else:d.line([point(p) for p in pts], fill=rgba(c), width=max(1,round(a[-1]*S)), joint='curve')
        elif op=='text':
            pos,text,size,color,outline = a
            d.text(point(pos),text,font=font(size),anchor='ls',fill=rgba(color),stroke_width=round(outline*S),stroke_fill=rgba(color))
        elif op=='image':
            (x,y,w,h),filename,modulate = a
            sprite=Image.open(OUT/'icons'/filename).convert('RGBA').resize((round(w*S*abs(scale[0])),round(h*S*abs(scale[1]))),Image.Resampling.LANCZOS)
            if scale[0]<0:sprite=sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if scale[1]<0:sprite=sprite.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            if angle:sprite=sprite.rotate(-math.degrees(angle),expand=True,resample=Image.Resampling.BICUBIC)
            center=point((x+w*.5,y+h*.5))
            layer.alpha_composite(sprite,(round(center[0]-sprite.width*.5),round(center[1]-sprite.height*.5)))
        elif op=='style':
            (x,y,w,h),color,border,radius,left,bottom,shadow,blur,offset = a
            bounds = (x*S,y*S,(x+w)*S,(y+h)*S)
            if shadow[3]>0:
                d.rounded_rectangle(((x+offset[0]-blur*.5)*S,(y+offset[1])*S,(x+w+offset[0]+blur*.5)*S,(y+h+offset[1]+blur*.5)*S),radius=radius*S,fill=rgba(shadow))
            d.rounded_rectangle(bounds,radius=min(radius,h/2)*S,fill=rgba(color),outline=rgba(border),width=round(left*S))
        image = Image.alpha_composite(image,layer)
    d=ImageDraw.Draw(image)
    def label(x,y,text,size=20,color='#42536b'):
        d.text((x*S,y*S),text,font=font(size),anchor='mm',fill=color)
    redesigned=data['version']>='0.6.0'
    if name in ('home','food-home'):
        label(270,330 if redesigned else 366,'3D CITY MINIATURE',22,'#fffdf7')
        label(270,361 if redesigned else 397,'Preview omitted in this layout export',16,'#fffdf7')
    elif data.get('preview_rects'):
        for x,y,w,h in data['preview_rects']:
            label(x+w/2,y+h/2,'3D skin',16)
            label(x+w/2,y+h/2+20,'Preview omitted',11)
    elif name in ('city-hud','food-hud','order-complete'):
        label(270,450,'3D WORLD OMITTED',23)
        label(270,481,'HUD layout only',19)
    image.convert('RGB').resize((540,960),Image.Resampling.LANCZOS).save(OUT/f'{name}.png')
    return image.convert('RGB')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=OUT)
    args=parser.parse_args();OUT=args.output.resolve()
    screens={p.stem:render(p.stem) for p in OUT.glob('*.json') if 'commands' in json.loads(p.read_text())}
    board=Image.new('RGB',(1770,1110),'#f2f5fa')
    d=ImageDraw.Draw(board)
    version=json.loads((OUT/'home.json').read_text())['version']
    d.text((30,12),f'SINK CITY  v{version}  /  CURRENT UI LAYOUT',font=font(17),fill='#243060')
    d.text((30,57),'Code-derived reconstruction. Not an in-game screenshot. 3D views omitted.',font=font(10),fill='#4b5a74')
    for i,(name,title) in enumerate([('home','HOME'),('skins','SKINS'),('food-hud','FOOD MAP HUD')]):
        x=30+i*590
        d.text((x,98),title,font=font(13),fill='#243060')
        board.paste(screens[name].resize((540,960),Image.Resampling.LANCZOS),(x,140))
    board.save(OUT/'our-ui-layouts.png')
    print(OUT/'our-ui-layouts.png')
