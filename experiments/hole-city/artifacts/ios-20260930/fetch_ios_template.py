"""Download only the standard iOS member of the official export archive."""
import io,json,zipfile,urllib.request,hashlib
from pathlib import Path
BASE=Path(__file__).resolve().parents[2]
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
SIZE=1281349702
class Remote(io.RawIOBase):
 def __init__(self):self.pos=0;self.downloaded=0
 def readable(self):return True
 def seekable(self):return True
 def tell(self):return self.pos
 def seek(self,off,whence=0):
  self.pos=off if whence==0 else self.pos+off if whence==1 else SIZE+off
  if not 0<=self.pos<=SIZE:raise ValueError('Invalid ZIP seek')
  return self.pos
 def read(self,n=-1):
  n=SIZE-self.pos if n<0 else min(n,SIZE-self.pos)
  if not n:return b''
  start=self.pos;end=start+n-1
  request=urllib.request.Request(URL,headers={'User-Agent':'SinkCity-iOS-preparation','Range':f'bytes={start}-{end}'})
  with urllib.request.urlopen(request,timeout=60) as r:
   if r.status!=206 or r.headers.get('Content-Range')!=f'bytes {start}-{end}/{SIZE}':raise RuntimeError('Unexpected range response')
   data=r.read(n+1)
  if len(data)!=n:raise RuntimeError('Truncated range')
  self.pos+=n;self.downloaded+=n
  return data
remote=Remote()
with zipfile.ZipFile(remote) as z:
 versions=[n for n in z.namelist() if n.endswith('/version.txt')]
 member=[n for n in z.namelist() if n.endswith('/ios.zip')]
 assert len(versions)==1 and len(member)==1
 version=z.read(versions[0]).decode().strip();assert version=='4.7.2.stable',version
 info=z.getinfo(member[0]);print('Downloading official standard iOS template:', info.file_size,flush=True)
 data=z.read(member[0])
 assert len(data)==info.file_size
with zipfile.ZipFile(io.BytesIO(data)) as ios:
 assert ios.testzip() is None
 assert 'libgodot.ios.release.xcframework/ios-arm64/libgodot.a' in ios.namelist()
 assert 'godot_apple_embedded.xcodeproj/project.pbxproj' in ios.namelist()
output=BASE/'.build/ios-4.7.2/ios.zip';output.parent.mkdir(parents=True,exist_ok=True)
output.write_bytes(data)
old=Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable.mono/ios.zip'
sha=lambda b:hashlib.sha256(b).hexdigest()
receipt={'source_url':URL,'standard_version':version,'member':member[0],'member_crc32':format(info.CRC,'08x'),'bytes':len(data),'sha256':sha(data),'archive_total_bytes':SIZE,'range_bytes_downloaded':remote.downloaded,'published_full_archive_sha256':'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011','full_archive_hash_verified':False,'verification':'HTTPS official release byte ranges; ZIP member CRC and all inner ZIP member CRCs verified. Full archive was not downloaded.','installed_mono_member_same_bytes':old.exists() and old.read_bytes()==data}
(BASE/'artifacts/ios-20260930/template-provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
