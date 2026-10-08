"""Background transport for the official Blender MCP command handlers.

Upstream start() intentionally rejects -b because GUI timers do not tick there.
This adapter dispatches the same JSON commands synchronously on Blender's main
thread. It does not register the addon in the user's preferences or use a GUI.
Usage: blender -b --factory-startup --python THIS -- ADDON.py PORT
"""
import sys, socket, json, importlib.util, bpy
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:]
spec=importlib.util.spec_from_file_location('local_blender_mcp',args[0])
addon=importlib.util.module_from_spec(spec);sys.modules[spec.name]=addon;spec.loader.exec_module(addon)
addon.register()
server=addon.BlenderMCPServer(host='127.0.0.1',port=int(args[1]))
with socket.socket() as listener:
    listener.bind(('127.0.0.1',int(args[1])));listener.listen(1);listener.settimeout(1800)
    print('HEADLESS_MCP_READY',flush=True)
    running=True
    while running:
        client,_=listener.accept()
        with client:
            chunks=b''
            while True:
                packet=client.recv(65536)
                if not packet:break
                chunks+=packet
                try:command=json.loads(chunks);break
                except json.JSONDecodeError:continue
            if command.get('type')=='shutdown':
                result={'status':'success'};running=False
            else:result=server.execute_command(command)
            client.sendall(json.dumps(result).encode())
addon.unregister()
