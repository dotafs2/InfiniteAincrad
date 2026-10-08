"""Label and encode the actual-mesh offline food showcase, never game capture."""
import hashlib,json,subprocess
from pathlib import Path
O=Path(__file__).resolve().parent
ROOT=O.parents[2]
font=ROOT/'assets/fonts/Fredoka.ttf'
def run(args):subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',*args],check=True,timeout=120)
def overlay(wide=False):
    size=23 if wide else 19
    sub=17 if wide else 14
    return ','.join(['drawbox=x=0:y=0:w=iw:h=78:color=0x172747@0.90:t=fill',f"drawtext=fontfile='{font}':text='OFFLINE PREVIEW / NOT GAME CAPTURE':fontsize={size}:fontcolor=white:x=(w-tw)/2:y=14",f"drawtext=fontfile='{font}':text='Actual food meshes and physics / approximate lighting':fontsize={sub}:fontcolor=0xbfe4ff:x=(w-tw)/2:y=45"])
for name in ['opening','overview']:
    run(['-i',str(O/(name+'.ppm')),'-vf',overlay(name=='overview'),'-frames:v','1',str(O/(name+'.png'))])
video_filter=overlay()+',drawbox=x=0:y=ih-56:w=iw:h=56:color=0x172747@0.86:t=fill'+f",drawtext=fontfile='{font}':text='59 separate pieces / real food rain':fontsize=19:fontcolor=white:x=(w-tw)/2:y=h-45"+f",drawtext=fontfile='{font}':text='Controlled grown-hole test / 12 fps pose preview':fontsize=14:fontcolor=0xbfe4ff:x=(w-tw)/2:y=h-21"
run(['-framerate','12','-i',str(O/'frame-%04d.ppm'),'-frames:v','120','-vf',video_filter,'-c:v','libx264','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(O/'food-collapse-rain.mp4')])
run(['-ss','2.5','-i',str(O/'food-collapse-rain.mp4'),'-frames:v','1',str(O/'collapse-poster.png')])
sources=['fidelity/game.gd','fidelity/food_city.gd','fidelity/food_body.gd','fidelity/food_shapes.gd','fidelity/food_surface.gd','fidelity/food_neighborhoods.gd','fidelity/food_glaze.gdshader','fidelity/hole.gd','scripts/hole.gd','scripts/swallowable.gd','assets/food_city/neighborhoods.json','assets/food_city/streets.png']
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
release=json.loads((ROOT/'artifacts/audit-fixes-20260928/release/release.json').read_text())
sim=json.loads((O/'simulation.json').read_text())
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(O/'food-collapse-rain.mp4')]))
manifest={'label':'OFFLINE PREVIEW; NOT a Godot/browser/device recording','source_sha256':hashes,'matches_final_release_source':all(release['source_sha256'].get(p)==v for p,v in hashes.items()),'rendering':{'stills':'windowless CGL, actual geometry and copied shipped food GLSL equations','video':'CPU triangle projection, actual physics transforms, shipped sRGB/reflection equations evaluated at vertices','lighting':'approximate; no Godot shadows/postprocessing','omissions':['NPC rigs','game UI','decorative hole skin','contact crumbs/ripples','audio','active opponents','NPC and traffic controller motion'],'cgl_video_attempt':'Owned 120-second CGL scene render timed out after producing two stills; process ended. CPU fallback completed full video.'},'simulation':{k:v for k,v in sim.items() if k!='timeline'},'qa_fixture':'Pre-grown level 5/radius 3.5 hole moves six metres to the real central authored heap; runtime support, gravity, admission and collection are unchanged. Scores start at zero and only change through actual collection. This is not normal human gameplay.','video_probe':probe,'files':{name:{'bytes':(O/name).stat().st_size,'sha256':hashlib.sha256((O/name).read_bytes()).hexdigest()} for name in ['opening.png','overview.png','food-collapse-rain.mp4','collapse-poster.png']},'helpers_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in O.iterdir() if p.suffix in ['.gd','.mm','.m','.py']}}
(O/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'source_matches_release':manifest['matches_final_release_source'],'outputs':manifest['files'],'simulation':manifest['simulation']},indent=2))
