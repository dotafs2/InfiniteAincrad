from pathlib import Path
import subprocess,json,hashlib,numpy as np
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
source=ROOT/'artifacts/shop-theme-20260930/source/buy_something_normal.ogg'
asset=ROOT/'assets/audio/shop_theme_loop.ogg'
def decode(path,clock=False):
 command=['ffmpeg','-v','error','-i',str(path)]
 if clock:command+=['-af','asetpts=N/SR/TB']
 command+=['-f','f32le','-acodec','pcm_f32le','pipe:1']
 result=subprocess.run(command,capture_output=True,check=True)
 return result.stdout,result.stderr.decode()
old,old_log=decode(source);raw,log=decode(asset);clock,clock_log=decode(asset,True)
assert raw==clock, 'Reclocking changed decoded samples'
a=np.frombuffer(old,dtype='<f4').reshape(-1,2).astype(np.float64)
b=np.frombuffer(raw,dtype='<f4').reshape(-1,2).astype(np.float64)
assert len(a)==len(b)==3880800 and np.isfinite(b).all()
gain=float(np.sum(a*b)/np.sum(a*a));correlation=float(np.sum(a*b)/np.sqrt(np.sum(a*a)*np.sum(b*b)));residual=b-a*gain
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'decoded_pcm_sha256':hashlib.sha256(raw).hexdigest(),'plain_vs_reclocked_pcm_byte_identical':raw==clock,'source_frames':len(a),'asset_frames':len(b),'duration_seconds':len(b)/44100,'least_squares_gain_db':float(20*np.log10(gain)),'waveform_correlation':correlation,'residual_snr_db':float(10*np.log10(np.sum(b*b)/np.sum(residual*residual))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(b*b)))),'sample_peak':float(np.abs(b).max()),'boundary_sample_jump':float(np.max(np.abs(b[0]-b[-1]))),'original_waveform_max_jump':float(np.max(np.abs(np.diff(a,axis=0)))),'asset_bytes':asset.stat().st_size,'ffmpeg_plain_decode_stderr':log,'ffmpeg_reclocked_decode_stderr':clock_log,'original_decode_stderr':old_log,'scope':'Full selected normal version independently decoded; gain/codec comparison only, no listening, speakers or browser claim.'}
assert correlation>.995 and abs(report['least_squares_gain_db']+7.1)<.1 and report['sample_peak']<1.0
(OUT/'recording-independent.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if 'stderr' not in k},indent=2))
