"""Embed existing render thumbnails for a local, API-free human comparison."""
import base64
import io
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Art/Generated/InteriorFirstPass20260916'
TARGET = PUBLIC / 'first-result-review.html'
catalog = json.loads((PUBLIC / 'review-scores.json').read_text(encoding='utf-8'))
template = (PUBLIC / 'review.template.html').read_text(encoding='utf-8')
sources = []

def thumbnail(path, edge, quality):
    sources.append(str(path.relative_to(ROOT)).replace('\\', '/'))
    with Image.open(path) as original:
        image = original.convert('RGB')
        image.thumbnail((edge, edge), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        image.save(out, format='WEBP', quality=quality, method=4)
    return 'data:image/webp;base64,' + base64.b64encode(out.getvalue()).decode('ascii')

for edge, quality in [(440, 60), (400, 55), (360, 50), (320, 45)]:
    sources = []
    for item in catalog['items']:
        item['views'] = []
        if item['group'] == '组件':
            for angle, label in [('front', '正面斜视'), ('back', '背面斜视')]:
                item['views'].append({'label': label, **{p: thumbnail(PUBLIC / 'props' / f'{p}-{item["id"]}-{angle}.png',edge,quality) for p in ['tripo','meshy']}})
        elif item['id'] == 'generated_house':
            for angle,label in [('front34','方位角 38°'),('side128','方位角 128°'),('back34','方位角 218°'),('side308','方位角 308°')]:
                item['views'].append({'label':label, **{p:thumbnail(ROOT / 'exports/tripo-meshy-comparison-20260916/renders' / f'{prefix}-{angle}.png',edge,quality) for p,prefix in [('tripo','tripo'),('meshy','meshy_refine')]}})
        else:
            for angle,label in [('01_entrance','入口'),('02_inside','室内全景'),('03_workshop','工作区'),('04_living','生活区'),('05_kitchen','炉灶区'),('06_window_open','窗户打开'),('07_window_closed','窗户关闭')]:
                item['views'].append({'label':label, **{p:thumbnail(PUBLIC / 'screenshots' / f'{p}_{angle}.png',edge,quality) for p in ['tripo','meshy']}})
    encoded = json.dumps(catalog,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
    result = template.replace('__REVIEW_DATA__',encoded)
    if len(result.encode('utf-8')) < 990_000: break
else:
    raise RuntimeError('Review exceeds inline size budget')
TARGET.parent.mkdir(parents=True,exist_ok=True)
TARGET.write_text(result,encoding='utf-8')
(PUBLIC / 'review-delivery.json').write_text(json.dumps({'inline_review':str(TARGET),'item_pairs':len(catalog['items']),'source_images':len(sources),'thumbnail_max_edge':edge,'thumbnail_webp_quality':quality,'bytes':TARGET.stat().st_size,'provider_api_calls':0,'model_changes':False,'sources':sources},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'path':str(TARGET),'pairs':len(catalog['items']),'images':len(sources),'bytes':TARGET.stat().st_size,'edge':edge,'quality':quality},ensure_ascii=False))
