"""Independent decoded-file audit; no playback, capture, or production writes."""
from pathlib import Path
import array, hashlib, json, math, statistics, subprocess
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
rows=[];decoded=[]
for name in ['sunny_city_loop.ogg','snack_garden_loop.ogg']:
    path=ROOT/'assets/audio'/name
    probe=subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(path)],capture_output=True,check=True,text=True)
    meta=json.loads(probe.stdout);stream=meta['streams'][0]
    result=subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-'],capture_output=True,check=True)
    assert not result.stderr,result.stderr.decode()
    samples=array.array('f');samples.frombytes(result.stdout)
    assert stream['channels']==2 and stream['sample_rate']=='44100' and stream['codec_name']=='vorbis'
    count=len(samples)//2; rate=int(stream['sample_rate'])
    energy=sum(x*x for x in samples)/len(samples)
    peak=max(abs(x) for x in samples)
    means=[sum(samples[ch::2])/count for ch in range(2)]
    seam=max(abs(samples[ch]-samples[-2+ch]) for ch in range(2))
    edge=list(samples[:882])+list(samples[-882:])
    edge_rms=math.sqrt(sum(x*x for x in edge)/len(edge))
    adjacent=sorted(abs(samples[i]-samples[i-2]) for i in range(2,len(samples),8))
    p99=adjacent[int(.99*(len(adjacent)-1))]
    rows.append({'file':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'codec':stream['codec_name'],'rate':rate,'channels':2,'samples_per_channel':count,'duration':count/rate,'rms_dbfs':20*math.log10(math.sqrt(energy)),'peak':peak,'peak_dbfs':20*math.log10(peak),'clipped':sum(abs(x)>=1 for x in samples),'dc':means,'last_to_first_step':seam,'adjacent_step_p99_subsample':p99,'boundary_20ms_rms_dbfs':20*math.log10(edge_rms)})
    decoded.append(samples)
    assert 25<count/rate<40 and -25<rows[-1]['rms_dbfs']<-10
    assert peak<.9 and rows[-1]['clipped']==0 and seam<.01 and seam<p99*1.5
    assert max(abs(x) for x in means)<.001 and edge_rms>.015
n=min(len(x) for x in decoded)
a=decoded[0][:n:20]; b=decoded[1][:n:20]
mean_a=statistics.mean(a);mean_b=statistics.mean(b)
corr=sum((x-mean_a)*(y-mean_b) for x,y in zip(a,b))/math.sqrt(sum((x-mean_a)**2 for x in a)*sum((y-mean_b)**2 for y in b))
assert rows[0]['sha256']!=rows[1]['sha256'] and abs(corr)<.3
result={'tracks':rows,'waveform_correlation_subsample':corr,'pass':True,'limits':'Decoded asset measurements; no audition or browser autoplay certification.'}
(OUT/'decoded-audio.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
