"""Serve a local Godot Web build with the isolation required by WASM threads."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from pathlib import Path
import argparse, os
class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        self.send_header('Cache-Control','no-store')
        super().end_headers()
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8768)
    p.add_argument('--directory',type=Path,default=Path(__file__).resolve().parents[1]/'build/web')
    p.add_argument('--pid-file',type=Path)
    args=p.parse_args()
    root=args.directory.resolve()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(Handler,directory=str(root)))
    state=args.pid_file.resolve() if args.pid_file else root.parent/'review-server.pid'
    state.parent.mkdir(parents=True,exist_ok=True);state.write_text(str(os.getpid())+'\n')
    print(f'Local review: http://127.0.0.1:{args.port} (PID {os.getpid()})',flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:
        server.server_close()
        if state.exists() and state.read_text().strip()==str(os.getpid()):state.unlink()
