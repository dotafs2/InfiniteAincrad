"""Build a phone-friendly, explicitly offline walkthrough of current assets.

This never starts, modifies or captures the running game.
"""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / 'assembly'
OUT.mkdir(exist_ok=True)
FFMPEG = '/opt/homebrew/bin/ffmpeg'
FONT = ROOT / 'assets/fonts/Fredoka.ttf'
W, H, FPS = 720, 1440, 24
BG, INK = '#e5edff', '#253553'
shots = []

def font(size):
    return ImageFont.truetype(str(FONT), size)

def wrapped(draw, value, y, size=28, fill=INK, width=630):
    lines, line = [], ''
    for word in value.split():
        nxt = (line + ' ' + word).strip()
        if draw.textlength(nxt, font=font(size)) > width and line:
            lines.append(line)
            line = word
        else:
            line = nxt
    if line: lines.append(line)
    for line in lines:
        draw.text((360,y), line, font=font(size), fill=fill, anchor='mt')
        y += size + 12
    return y

def frame(content, title, detail):
    result = Image.new('RGB', (W,H), '#172641')
    art = ImageOps.contain(content.convert('RGB'), (720,1280), Image.Resampling.LANCZOS)
    result.paste(Image.new('RGB',(720,1280),BG),(0,80))
    result.paste(art, ((720-art.width)//2,80+(1280-art.height)//2))
    d = ImageDraw.Draw(result)
    d.text((28,17), title, font=font(28), fill='white')
    d.text((28,52), detail, font=font(16), fill='#bcd3f5')
    d.text((360,1373), 'OFFLINE PREVIEW · NOT A SCREEN RECORDING', font=font(22), fill='white',anchor='mt')
    d.text((360,1408), 'Current v0.8.0 data · Lighting and rasterization are approximate',font=font(17),fill='#bcd3f5',anchor='mt')
    return result

def card(title, lines):
    img = Image.new('RGB',(720,1280),BG)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((38,130,682,1135),radius=45,fill='white')
    y = wrapped(d,title,200,58)
    for text in lines:
        y = wrapped(d,text,y+48,29)
    return img

def add(name, title, detail, duration, source=None, content=None):
    if content is None: content = Image.open(HERE/source)
    image_path = OUT/(name+'.png')
    frame(content,title,detail).save(image_path)
    shots.append(dict(name=name,title=title,detail=detail,duration=duration,source=source,
                      frame=str(image_path),kind='still'))

def encode_args(output):
    return ['-an','-c:v','libx264','-threads','2','-preset','veryfast','-crf','21',
            '-pix_fmt','yuv420p','-r',str(FPS),'-video_track_timescale','24000',
            '-movflags','+faststart',str(output)]

def encode_still(shot):
    out = OUT/(shot['name']+'.mp4')
    subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-loop','1',
                    '-framerate',str(FPS),'-i',shot['frame'],'-t',str(shot['duration']),
                    *encode_args(out)],check=True)
    return str(out)

def encode_motion(name, images, title, detail, repeat=1):
    out = OUT/(name+'.mp4')
    p = subprocess.Popen([FFMPEG,'-hide_banner','-loglevel','error','-y','-f','rawvideo',
                          '-pixel_format','rgb24','-video_size',f'{W}x{H}',
                          '-framerate',str(FPS),'-i','-',*encode_args(out)],stdin=subprocess.PIPE)
    first = None
    count = 0
    try:
        for img in images:
            full = frame(img,title,detail)
            if first is None:
                first = OUT/(name+'.png')
                full.save(first)
            raw = full.tobytes()
            for _ in range(repeat):
                p.stdin.write(raw)
                count += 1
    finally:
        p.stdin.close()
    assert p.wait() == 0
    shots.append(dict(name=name,title=title,detail=detail,duration=count/FPS,
                      frame=str(first),kind='motion',clip=str(out)))

def shader_frames():
    # Re-layout the three existing 320px tiles vertically for phone readability.
    for _ in range(3):
        for i in range(48):
            src = Image.open(HERE/f'skins/animation/frame-{i:03d}.png')
            canvas = Image.new('RGB',(720,1280),BG)
            d = ImageDraw.Draw(canvas)
            for col,label in enumerate(['Core Shell · accretion','Tide · flowing water','Cinder · rising flame']):
                tile = src.crop((col*320,55,(col+1)*320,327)).resize((420,357),Image.Resampling.LANCZOS)
                canvas.paste(tile,(150,24+col*410))
                d.text((360,375+col*410),label,font=font(27),fill=INK,anchor='mt')
            yield canvas

def food_frames():
    for i in range(120):
        yield Image.open(HERE/f'food/frame-{i:04d}.ppm')

def main():
    catalog = json.loads((HERE/'skins/catalog.json').read_text())
    pages = [f'classic-page-{i}' for i in range(1,6)] + [f'special-page-{i}' for i in range(1,4)]
    ids = [sid for page in pages for sid in json.loads((HERE/'ui'/f'{page}.json').read_text())['card_ids']]
    assert len(ids)==len(set(ids))==44 and set(ids)=={x['id'] for x in catalog}
    add('intro','SINK CITY · CURRENT BUILD','Phone walkthrough · September 28, 2026',5,
        content=card('SINK CITY\nv0.8.0',[
            '24 interface states · All 44 skins · Two maps',
            'UI reconstructed from current draw commands. Scenes rendered from current models.',
            'Includes a controlled food-collapse physics replay.',
            'Offline preview. Not a screen recording.']))
    ui_shots = [
        ('home','Home · Sunny City','Current home interface and actual miniature model',4),
        ('food-home','Home · Snack Garden','Current map selection and actual miniature model',4),
        ('store','Coin shop','Current shop layout · isolated test profile',3),
        ('store-gift','Gem gift','Actual gift action in an isolated test profile',3),
    ]
    for name,title,detail,dur in ui_shots: add(name,title,detail,dur,'ui/rendered/'+name+'.png')
    for i in range(1,6): add(f'classic-page-{i}',f'Classic skins · {i} / 5','All 27 current Classic skins · rendered asset previews',4,f'ui/rendered/classic-page-{i}.png')
    for i in range(1,4): add(f'special-page-{i}',f'Special skins · {i} / 3','All 17 current Special skins · rendered asset previews',4,f'ui/rendered/special-page-{i}.png')
    for name,title,detail in [
        ('locked-skin','Locked skin','Current locked-card state · isolated test profile'),
        ('unlocked-skin','Coin unlock','Actual random unlock action · isolated test profile'),
        ('insufficient-coins','Insufficient coins','Current shortfall feedback · isolated test profile')]:
        add(name,title,detail,3,'ui/rendered/'+name+'.png')
    encode_motion('shader-motion',shader_frames(),'Shader motion · three skin examples','Shader time only · fixed mesh poses · offline rendering')
    for name,title in [('manual-skill','Manual skill prompt'),('auto-skill','Automatic skill prompt')]:
        add(name,title,'Current UI layout · seeded test state',3,'ui/rendered/'+name+'.png')
    for name,title in [('city-intro','Sunny City · match intro'),('city-hud','Sunny City · match HUD')]:
        add(name,title,'Current UI layout · scene intentionally separate',3,'ui/rendered/'+name+'.png')
    for name,title in [('opening','Sunny City · opening view'),('overview','Sunny City · district overview'),('street-close','Sunny City · street detail')]:
        add('city-'+name,title,'Actual current models and NPC poses · approximate lighting',5,'city/'+name+'-raw.png')
    add('food-hud','Snack Garden · match HUD','Current UI layout · scene intentionally separate',3,'ui/rendered/food-hud.png')
    add('food-opening','Snack Garden · opening view','Actual food-city meshes · approximate lighting',5,'food/opening-raw.png')
    add('food-overview','Snack Garden · city overview','Actual current geometry and roads · approximate lighting',5,'food/overview.ppm')
    encode_motion('food-physics',food_frames(),'Food collapse + rain · physics replay','59 independent pieces · pre-grown 3.5 m hole · 12 fps pose replay',repeat=2)
    for name,title in [('pause','Pause menu'),('eaten','Result · eaten'),('timeout','Result · timeout'),('complete','Result · complete')]:
        add(name,title,'Current UI layout · seeded test state',3,'ui/rendered/'+name+'.png')
    add('outro','Preview scope','Current assets and interface · no device benchmark',5,
        content=card('Preview complete',[
            'UI · 44 skins · Sunny City · Snack Garden',
            'Food clip: actual support, gravity and collection in a controlled test.',
            'Lighting, shadows and touch feel require a live game recording.',
            'Video frame rate is not a phone performance result.']))
    stills = [s for s in shots if s['kind']=='still']
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        for shot,clip in zip(stills,executor.map(encode_still,stills)):
            shot['clip']=clip
            print('Encoded:',shot['name'],flush=True)
    concat = OUT/'concat.txt'
    concat.write_text(''.join("file '"+Path(s['clip']).name+"'\n" for s in shots))
    destination = HERE/'sink-city-v0.8.0-offline-showcase.mp4'
    subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0',
                    '-i',str(concat),'-c','copy','-movflags','+faststart',str(destination)],check=True)
    time = 0
    for shot in shots:
        shot['start_seconds'] = time
        time += shot['duration']
    manifest = dict(title='Sink City v0.8.0 offline showcase',scope='NOT a game, browser or device capture',
                    width=W,height=H,encoded_fps=FPS,duration_seconds=time,audio=False,
                    ui_states=24,unique_skin_ids=ids,chapters=shots,
                    output=destination.name,bytes=destination.stat().st_size,
                    sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),
                    rendering='UI draw reconstruction; offline scene/skin render; actual headless food physics poses',
                    limitations=['Approximate lighting and rasterization','Fixture UI states and controlled food test',
                                 'No natural full-match gameplay','No phone GPU/FPS evidence'])
    (HERE/'showcase.json').write_text(json.dumps(manifest,indent=2)+'\n')
    # Sample every chapter in one visual QA sheet.
    sheet = Image.new('RGB',(1440,((len(shots)+5)//6)*520),'#ffffff')
    for i,shot in enumerate(shots):
        thumb = Image.open(shot['frame']).resize((240,480))
        x,y = (i%6)*240,(i//6)*520
        sheet.paste(thumb,(x,y))
        ImageDraw.Draw(sheet).text((x+6,y+486),f"{shot['start_seconds']:05.1f}s  {shot['name']}",font=font(12),fill='black')
    sheet.save(HERE/'chapter-contact-sheet.jpg',quality=90)
    Image.open(OUT/'home.png').save(HERE/'poster.jpg',quality=93)
    print(json.dumps({'video':str(destination),'seconds':time,'megabytes':destination.stat().st_size/1e6}),flush=True)

if __name__=='__main__': main()
