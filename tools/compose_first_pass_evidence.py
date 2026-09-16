"""Compose genuine model renders and game screenshots without altering their content."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'Art/Generated/InteriorFirstPass20260916'
plan = json.loads((DEST / 'request.json').read_text(encoding='utf-8'))
font = r'C:\Windows\Fonts\msyh.ttc'
title = ImageFont.truetype(font, 30)
label = ImageFont.truetype(font, 23)
small = ImageFont.truetype(font, 18)
for page in range(3):
    sheet = Image.new('RGB', (1800, 1660), '#1b2027')
    draw = ImageDraw.Draw(sheet)
    draw.text((22, 16), f'首轮原始组件对照 {page+1}/3 · 每项仅生成一次', font=title, fill='#e9eceb')
    draw.text((22, 62), '每组左 Tripo H3.1 / 右 Meshy 7；仅归一化展示大小，没有修模、重抽或重贴图。',font=small,fill='#b6bec7')
    for i, asset in enumerate(plan['assets'][page*6:page*6+6]):
        row, col = divmod(i,2)
        x, y = col*900, 108+row*510
        draw.text((x+20,y),asset['name_zh'],font=label,fill='#edebe5')
        for j,provider in enumerate(['tripo','meshy']):
            source = DEST / 'props' / (provider+'-'+asset['id']+'-front.png')
            draw.text((x+20+j*450,y+35),provider.capitalize(),font=small,fill='#bcc7d1')
            if source.exists():
                im = Image.open(source).convert('RGB').resize((430,430),Image.Resampling.LANCZOS)
                sheet.paste(im,(x+10+j*450,y+65))
            else:
                draw.text((x+20+j*450,y+220),'未生成 / 未下载',font=label,fill='#eea185')
    sheet.save(DEST / f'components-{page+1}.jpg',quality=94)

shots = DEST / 'screenshots'
for name,views in [('interiors',['02_inside','03_workshop','04_living','05_kitchen']),
                   ('doors-windows',['01_entrance','06_window_open','07_window_closed'])]:
    sheet = Image.new('RGB',(1920,78+len(views)*635),'#1b2027')
    draw = ImageDraw.Draw(sheet)
    draw.text((24,14),'Tripo 住宅                                  Meshy 住宅 · Godot 实机',font=title,fill='#eeeeea')
    for row,view in enumerate(views):
        for col,provider in enumerate(['tripo','meshy']):
            file = shots / (provider+'_'+view+'.png')
            if file.exists():
                image = Image.open(file).convert('RGB')
                image.thumbnail((950,594),Image.Resampling.LANCZOS)
                sheet.paste(image,(col*960+5,78+row*635))
                draw.text((col*960+18,674+row*635),provider.capitalize()+' / '+view,font=small,fill='#bdc8d0')
    if shots.exists(): sheet.save(DEST / (name+'.jpg'),quality=94)
print('Comparison sheets updated from existing evidence only.')
