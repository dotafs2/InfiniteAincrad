"""Package only the owned Godot kit, never keys, provider URLs, caches or private state."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'exports/interior-first-pass-20260916'
PROJECT = OUT / 'project'
PUBLIC = ROOT / 'Art/Generated/InteriorFirstPass20260916'
files = [PROJECT / name for name in ['project.godot','main.tscn','main.gd','house.gd','modular_house_component.gd',
         'LICENSE','NOTICE.txt','Start.ps1','Start.cmd','assembly-axes.json','asset-provenance.json','visual-review.json']]
files += [PROJECT / 'assets/shell/01_hearth_cottage.glb', PROJECT / 'assets/shell/manifest.json']
for provider in ['tripo','meshy']:
    files += sorted((PROJECT / 'assets' / provider).glob('*.glb'))
assert len(files)==50, 'Unexpected package contents'
assert all(p.is_file() for p in files)
keys = [(ROOT / 'secrets' / (provider+'-key.txt')).read_text(encoding='utf-8-sig').strip().encode() for provider in ['tripo','meshy']]
for file in files:
    if file.suffix != '.glb':
        assert not any(k in file.read_bytes() for k in keys), 'Credential in package'
archive = OUT / 'FirstPassHomes-Godot.zip'
with ZipFile(archive,'w',compression=ZIP_DEFLATED,compresslevel=1) as z:
    for file in files: z.write(file,'FirstPassHomes/'+file.relative_to(PROJECT).as_posix())
with ZipFile(archive) as z:
    assert z.testzip() is None
record = {'archive':archive.relative_to(ROOT).as_posix(),'bytes':archive.stat().st_size,
          'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'file_count':len(files),
          'models':36,'authored_shells':1,'houses_in_scene':2,'no_credentials_or_private_state':True,
          'controls':{'move':'WASD','look':'click + mouse','door':'E near entrance','windows':'Q',
                      'choose_house':'1 / 2','jump':'Space','save':'F5','load':'F9','release_cursor':'Esc'},
          'launch':'Extract archive, run Start.cmd (uses installed Godot 4.7), or import project.godot in Godot.',
          'first_import':'Godot builds its own texture/import cache on first launch; no model API is called.'}
(PUBLIC / 'delivery.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record,ensure_ascii=False))
