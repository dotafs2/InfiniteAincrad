"""Own one hidden Blender process and author the catalog through MCP commands."""
import argparse,subprocess,socket,json,time,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--blender',required=True);p.add_argument('--addon',required=True);p.add_argument('--evidence',required=True)
a=p.parse_args();root=Path(__file__).resolve().parent;evidence=Path(a.evidence);evidence.mkdir(parents=True,exist_ok=True)
port=19876
def command(kind,params=None):
    with socket.create_connection(('127.0.0.1',port),timeout=300) as s:
        s.sendall(json.dumps({'type':kind,'params':params or {}}).encode());chunks=b''
        while True:
            data=s.recv(65536)
            if not data:break
            chunks+=data
        response=json.loads(chunks)
        if response.get('status')!='success':raise RuntimeError(response)
        return response
receipts=[]
with (evidence/'blender.log').open('w',encoding='utf8') as log:
    proc=subprocess.Popen([a.blender,'--background','--factory-startup','--threads','4','--python',str(root/'headless_blender_bridge.py'),'--',str(Path(a.addon).resolve()),str(port)],stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    try:
        for _ in range(80):
            if proc.poll() is not None:raise RuntimeError('Blender exited; inspect log')
            try:command('ping');break
            except OSError:time.sleep(.5)
        command('execute_code',{'code':f"import sys; sys.path.insert(0,{str(root)!r}); import build_blender_catalog as kit; kit.setup(); print(bpy.app.version_string)"})
        for i in range(208):
            begin=time.monotonic();r=command('execute_code',{'code':f'import build_blender_catalog as kit; kit.build_one({i})'})
            receipts.append({'index':i+1,'type':'execute_code','status':r['status'],'seconds':round(time.monotonic()-begin,3),'result':r['result']['result'][-240:]})
            if (i+1)%16==0:print('MODELS',i+1,flush=True)
        command('execute_code',{'code':'import build_blender_catalog as kit; kit.finish()'})
        receipts.append({'type':'get_scene_info','response':command('get_scene_info')})
    finally:
        try:command('shutdown')
        except Exception:pass
        try:proc.wait(timeout=20)
        except subprocess.TimeoutExpired:proc.terminate();proc.wait(timeout=10)
        (evidence/'mcp_receipts.json').write_text(json.dumps({'addon_sha256':hashlib.sha256(Path(a.addon).read_bytes()).hexdigest(),'transport':'headless main-thread adapter, official Blender MCP command handlers','owned_pid':proc.pid,'exit_code':proc.returncode,'commands':receipts},indent=2)+'\n',encoding='utf8')
print('COMPLETE',len(receipts)-1)
