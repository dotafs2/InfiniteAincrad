"""Reuse first-pass Meshy geometry; package embedded textures at 2K for the live town."""
import hashlib
import io
import json
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IDS = ['bed','table','chair','chest','hearth','jug','shelf','workbench']


def prepare(asset, source=None, destination=None, texture_size=2048):
    source = Path(source) if source else ROOT/'exports/interior-first-pass-20260916/meshy'/f'{asset}.glb'
    destination = Path(destination) if destination else ROOT/'game/assets/floor1/living_props_20260916'/f'{asset}.glb'
    raw = source.read_bytes()
    size, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+size])
    bin_offset = 20+size
    bin_size, bin_kind = struct.unpack_from('<II', raw, bin_offset)
    assert bin_kind == 0x004E4942
    binary = raw[bin_offset+8:bin_offset+8+bin_size]
    replacements = {}
    for image in doc.get('images',[]):
        view_index = image['bufferView']
        view = doc['bufferViews'][view_index]
        blob = binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        with Image.open(io.BytesIO(blob)) as picture:
            picture.thumbnail((texture_size,texture_size),Image.Resampling.LANCZOS)
            stream = io.BytesIO()
            picture.save(stream,format='PNG',compress_level=6)
        replacements[view_index] = stream.getvalue()
        image['mimeType']='image/png'
    rebuilt = bytearray()
    for index, view in enumerate(doc['bufferViews']):
        blob = replacements.get(index,binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
        rebuilt.extend(b'\0'*(-len(rebuilt)%4))
        view['byteOffset']=len(rebuilt)
        view['byteLength']=len(blob)
        rebuilt.extend(blob)
    doc['buffers'][0]['byteLength']=len(rebuilt)
    rebuilt.extend(b'\0'*(-len(rebuilt)%4))
    encoded=json.dumps(doc,separators=(',',':')).encode()
    encoded+=b' '*(-len(encoded)%4)
    result=struct.pack('<III',0x46546C67,2,12+8+len(encoded)+8+len(rebuilt))
    result+=struct.pack('<II',len(encoded),0x4E4F534A)+encoded
    result+=struct.pack('<II',len(rebuilt),0x004E4942)+rebuilt
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(result)
    return {'id':asset,'source':str(source.relative_to(ROOT)).replace('\\','/'),
            'source_sha256':hashlib.sha256(raw).hexdigest(),
            'packaged_sha256':hashlib.sha256(result).hexdigest(),
            'source_bytes':len(raw),'packaged_bytes':len(result),'geometry_unchanged':True,'textures_max':texture_size}


if __name__=='__main__':
    report=[prepare(asset) for asset in IDS]
    (ROOT/'game/assets/floor1/living_props_20260916/manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'models':len(report),'bytes':sum(r['packaged_bytes'] for r in report),'new_api_calls':0}))
