"""Non-author file/score/decode review. Does not play audio or write game files."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
paths=['tools/build_music.py','assets/audio/music_manifest.json','assets/audio/sunny_city_loop.ogg','assets/audio/snack_garden_loop.ogg','fidelity/audio.gd','fidelity/audio_bus_layout.tres','tests/music_review.gd']
def hashes():return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
before=hashes();failures=[];checks=0
spec=importlib.util.spec_from_file_location('score',ROOT/'tools/build_music.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
manifest=json.loads((ROOT/'assets/audio/music_manifest.json').read_text());tracks=[]
def check(ok,label):
 global checks
 checks+=1
 if not ok:failures.append(label)
def decode(path):
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-ar','44100','-ac','2','pipe:1']);return np.frombuffer(raw,dtype='<f4').reshape(-1,2)
def db(x):return float(20*np.log10(max(1e-12,float(x))))
check(before['tools/build_music.py']==manifest['generator_sha256'],'Generator hash binds manifest')
for key,bpm,scale,tonic,dominant in [('sunny_city_loop',104,{0,2,4,5,7,9,11},0,7),('snack_garden_loop',108,{0,2,4,5,7,9,10},5,0)]:
 cfg=module.TRACKS[key];stored=next(x for x in manifest['tracks'] if x['file']==key+'.ogg');path=ROOT/'assets/audio'/stored['file'];audio=decode(path);old=decode(ROOT/'artifacts/feel-20260930/audio-before/assets/audio'/stored['file'])
 check(hashlib.sha256(path.read_bytes()).hexdigest()==stored['sha256'],key+' Ogg bound to measured manifest')
 check(len(audio)==round(16*4*60/bpm*44100),key+' 16 bars at actual tempo')
 check(np.isfinite(audio).all() and np.max(np.abs(audio))<.4,key+' finite unclipped headroom')
 peak=db(np.max(np.abs(audio)));rms=db(np.sqrt(np.mean(audio.astype(np.float64)**2)));old_rms=db(np.sqrt(np.mean(old.astype(np.float64)**2)))
 check(-25<rms<-24 and old_rms-rms>5,key+' actual decoded mix is gentler than original')
 check(np.max(abs(audio.mean(axis=0)))<.0001,key+' no appreciable DC')
 step=float(np.max(np.abs(audio[0]-audio[-1])));p99=float(np.quantile(np.abs(np.diff(audio,axis=0)),.99))
 check(step<.005 and step<p99,key+' boundary smaller than ordinary sample increments')
 windows=np.array([np.sqrt(np.mean(audio[max(0,i-221):min(len(audio),i+221)].astype(float)**2)) for i in (0,len(audio)-1)])
 check(db(windows.min())>-45,key+' no long musical fade to silence at boundary')
 rebuilt,arrangement=module.compose(key,cfg)
 check(hashlib.sha256(rebuilt.tobytes()).hexdigest()==stored['source_pcm_sha256'],key+' independent invocation produces exact source PCM')
 check(arrangement==stored['arrangement'],key+' actual program reproduces published score events')
 check(set(arrangement['event_counts'])=={cfg['lead'],'nylon','bass','brush'} and sum(arrangement['event_counts'].values())==131,key+' four parts and 131 events, no hidden dense layer')
 check(arrangement['written_lead_rest_fraction']>.5,key+' melodic written rests exceed half the form')
 check(len(cfg['chords'])==len(cfg['melody'])==16,key+' full bar-by-bar form')
 for bar,(chord,melody) in enumerate(zip(cfg['chords'],cfg['melody'])):
  pcs={x%12 for x in chord};root=cfg['bass'][bar]%12
  check(pcs in [{root,(root+3)%12,(root+7)%12},{root,(root+4)%12,(root+7)%12}],key+f' bar{bar+1} ordinary root-based major/minor triad')
  check(all(p%12 in scale and 65<=p<=76 and t>=0 and t+length<=4 for t,p,length in melody),key+f' bar{bar+1} diatonic readable register with no overrun')
  check(all(t>=0 and length>0 for t,p,length in melody),key+f' bar{bar+1} valid explicit timing')
 check(cfg['bass'][0]%12==tonic and cfg['bass'][-1]%12==dominant,key+' seam dominant resolves into tonic')
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(path)]))['streams'][0]
 check(probe['codec_name']=='vorbis' and probe['channels']==2 and probe['sample_rate']=='44100',key+' actual stereo Vorbis 44100')
 check(int(probe['tags']['LOOPSTART'])==0 and int(probe['tags']['LOOPEND'])==len(audio),key+' embedded loop sample metadata')
 tracks.append({'name':key,'samples':len(audio),'duration':len(audio)/44100,'peak_dbfs':peak,'rms_dbfs':rms,'prior_rms_dbfs':old_rms,'seam_jump':step,'interior_step_p99':p99,'written_rest_fraction':arrangement['written_lead_rest_fraction'],'parts':arrangement['event_counts']})
check(hashes()==before,'Source, Ogg, buses and maintained test stable across review')
result={'checks':checks,'failures':failures,'inputs':before,'tracks':tracks,'scope':'Independent decoded-file and score analysis, not hearing or speaker/browser playback. Subjective musical preference and SFX balance remain unauditioned.'}
(OUT/'analysis.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'checks':checks,'failures':failures,'tracks':tracks}));raise SystemExit(bool(failures))
