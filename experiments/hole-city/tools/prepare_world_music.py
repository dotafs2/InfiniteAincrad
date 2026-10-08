#!/usr/bin/env python3
"""Prepare verified CC0 author recordings and compose an original case theme.
No playback. Source archives are downloaded separately from pinned author URLs.
"""
from pathlib import Path
import argparse,hashlib,json,math,re,subprocess,zipfile
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
RATE=44100
ARCHIVE_SHA256={'towns.zip': 'b56785b248ad0faf629a5981eed7ec507b738abf87230e19ae0dba2f4eb466f8', 'march.zip': 'feea4abc34d3ba19a742603bedc2619b75820e1bef423773ccaae03538f7f02a', 'snow.zip': '10fe7758311e7b7e724abbad56fbee0d86e0131e1fa66512f4188a5ee6a0c05c'}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def decode(path):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-af','asetpts=N/SR/TB','-ar',str(RATE),'-ac','2','-f','f32le','-'])
    return np.frombuffer(raw,dtype='<f4').reshape(-1,2)
def loudness(path):
    r=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True,check=True)
    return float(re.findall(r'I:\s+([-\d.]+) LUFS',r.stderr)[-1]),float(re.findall(r'Peak:\s+([-\d.]+) dBFS',r.stderr)[-1])
def measures(path):
    x=decode(path);lufs,peak=loudness(path);mono=x.mean(axis=1);spectrum=np.abs(np.fft.rfft(mono[::2]))**2;freq=np.fft.rfftfreq(len(mono[::2]),2/RATE)
    return {'seconds':len(x)/RATE,'frames':len(x),'sample_rate':RATE,'channels':2,'lufs':lufs,'true_peak_dbfs':peak,'sample_peak':float(np.max(np.abs(x))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'boundary_sample_jump':float(np.max(np.abs(x[0]-x[-1]))),'high_band_energy_fraction':float(spectrum[freq>4000].sum()/max(spectrum.sum(),1e-10)),'dc':float(np.max(np.abs(x.mean(axis=0)))),'finite':bool(np.isfinite(x).all()),'clipped_samples':int((np.abs(x)>=1).sum())}

def case_theme(path):
    """D major, 96 BPM,16 bars: felt electric keys, low pad and round bass.
    Original written notes and synthesized timbres; no samples or external models.
    """
    beat=60/96;count=round(64*beat*RATE);mix=np.zeros((count,2),dtype=np.float64);events=[]
    chords=[[50,57,61,66],[47,54,57,62],[43,50,57,59],[45,52,57,61]]*4
    melody=[[66,None,64,62],[62,None,61,None],[59,None,62,66],[64,None,61,None],
            [66,None,69,None],[66,64,62,None],[62,None,59,None],[61,None,64,None],
            [69,None,66,64],[62,None,66,None],[67,None,66,62],[64,None,61,None],
            [66,None,64,62],[62,None,61,None],[59,None,62,None],[61,None,None,None]]
    def add(note,at,duration,gain,kind,pan=0):
        n=round(duration*RATE);t=np.arange(n)/RATE;f=440*2**((note-69)/12);tail=np.minimum(1,(duration-t)/.12).clip(0,1)**2
        if kind=='keys':
            e=(1-np.exp(-t/.015))*np.exp(-t/1.0)*tail
            x=(np.sin(2*np.pi*f*t+.30*np.sin(2*np.pi*f*2*t)*np.exp(-t/.18))+.09*np.sin(2*np.pi*f*3*t)*np.exp(-t/.23))*e
        elif kind=='pad':
            e=np.sin(np.pi*np.minimum(t/.45,1)/2)**2*tail
            x=(np.sin(2*np.pi*f*t)+.09*np.sin(2*np.pi*f*2*t))*e
        else:
            e=(1-np.exp(-t/.023))*np.exp(-t/.48)*tail
            x=(np.sin(2*np.pi*f*t)+.12*np.sin(2*np.pi*f*2*t))*e
        stereo=x[:,None]*gain*np.array([math.cos((pan+1)*math.pi/4),math.sin((pan+1)*math.pi/4)])
        idx=(np.arange(n)+round(at*beat*RATE))%count;np.add.at(mix,idx,stereo)
        events.append({'voice':kind,'midi':note,'beat':at,'seconds':duration,'gain':gain})
    for bar,chord in enumerate(chords):
        at=bar*4
        for j,n in enumerate(chord):add(n+12,at+j*.075,1.35,.026,'keys',-.4+j*.22)
        for n in chord[:3]:add(n,at,2.5,.008,'pad',0)
        add(chord[0]-12,at,.9,.085,'bass')
        if bar%4!=3:add(chord[0]-5,at+2.5,.5,.035,'bass')
        for j,n in enumerate(melody[bar]):
            if n is not None:add(n,at+j+.45,.72,.046,'keys',.1)
    for delay,gain in ((.065,.10),(.12,.055)):
        mix+=np.roll(mix,round(delay*RATE),axis=0)[:,::-1]*gain
    # Periodic filtering keeps decay tails continuous across the loop boundary.
    freq=np.fft.rfftfreq(count,1/RATE);filter_=(freq**2/(freq**2+40**2))/(1+(freq/4200)**6)**.5
    mix=np.fft.irfft(np.fft.rfft(mix,axis=0)*filter_[:,None],n=count,axis=0)
    mix*=.5/max(np.max(np.abs(mix)),1e-10)
    raw=path.with_suffix('.f32');raw.write_bytes(mix.astype('<f4').tobytes())
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','2','-i',str(raw),'-c:a','pcm_s16le',str(path)],check=True)
    return {'title':'A Little Wonder','author':'Hole Feast original composition','license':'Project original','bpm':96,'bars':16,'key':'D major','events':events,'source_kind':'Original deterministic synthesis; no third-party samples'}

def main():
    p=argparse.ArgumentParser();p.add_argument('--sources',type=Path,default=ROOT/'build/music-worlds-20261008/sources');p.add_argument('--output',type=Path,default=ROOT/'assets/audio/worlds');p.add_argument('--snow-member',default='Snow Theme/BGM_Snow_Theme_Slowed_Loop.wav');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    work=ROOT/'build/music-worlds-20261008/processed';work.mkdir(parents=True,exist_ok=True)
    specs={
      'city':('towns.zip','Town1 - Home Town.ogg','Hometown','Juhani Junkala','https://opengameart.org/content/jrpg-pack-2-towns',0),
      'food':('towns.zip','Town3 - Sunshine Coast.ogg','Sunshine Coast','Juhani Junkala','https://opengameart.org/content/jrpg-pack-2-towns',-3),
      'toys':('march.zip',"Children's March Theme.wav","Children's March Theme",'Cleyton Kauffman','https://opengameart.org/content/childrens-march-theme',-2),
      'frost':('snow.zip',a.snow_member,'Through the Snow (author slowed loop)','Cleyton Kauffman','https://opengameart.org/content/snow-theme',-2),
    }
    result={'schema':2,'contexts':{},'limits':'Objective waveform and decoder checks do not prove subjective listening quality or physical-device performance.'}
    for context,(archive,member,title,author,url,shelf) in specs.items():
        archive_path=a.sources/archive
        assert digest(archive_path)==ARCHIVE_SHA256[archive],"Unexpected source archive"
        with zipfile.ZipFile(archive_path) as z:data=z.read(member)
        source=work/(context+Path(member).suffix);source.write_bytes(data)
        result['contexts'][context]={'title':title,'author':author,'license':'CC0-1.0','source_url':url,'license_url':'https://creativecommons.org/publicdomain/zero/1.0/','source_archive_sha256':digest(archive_path),'source_member':member,'source_member_sha256':digest(source),'source':source,'shelf':shelf}
    result['contexts']['case']=case_theme(work/'case.wav')|{'source':work/'case.wav','shelf':0}
    for context,meta in result['contexts'].items():
        source=meta.pop('source');shelf=meta.pop('shelf');prefilter=work/(context+'-prefilter.wav')
        filters='highpass=f=35'+(f',highshelf=f=2800:g={shelf}:width_type=q:width=0.7' if shelf else '')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-af',filters,'-ar',str(RATE),'-ac','2','-c:a','pcm_f32le',str(prefilter)],check=True)
        lufs,peak=loudness(prefilter);gain=min(-22-lufs,-6-peak)
        duration=len(decode(prefilter))/RATE
        seam_guard=f',afade=t=in:st=0:d=0.003,afade=t=out:st={duration-0.003:.9f}:d=0.003'
        dest=a.output/(context+'.ogg')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(prefilter),'-af',f'volume={gain}dB'+seam_guard,'-map_metadata','-1','-c:a','libvorbis','-q:a','3','-metadata','title='+meta['title'],'-metadata','artist='+meta['author'],'-metadata','license='+meta['license'],str(dest)],check=True)
        meta.update({'asset':'worlds/'+dest.name,'sha256':digest(dest),'bytes':dest.stat().st_size,'processing':{'constant_gain_db':gain,'filters':filters,'duration_or_tempo_changed':False,'seam_guard_seconds':0.003,'note':'Source author slowed alternative is used as supplied for Frost; no time stretching here.' if context=='frost' else 'Full composition, no rearrangement or time stretching.'},'measurements':measures(dest)})
        assert meta['measurements']['finite'] and meta['measurements']['clipped_samples']==0
        assert meta['measurements']['true_peak_dbfs'] < -4.5
        print(context,meta['measurements']['seconds'],meta['measurements']['lufs'],meta['bytes'],flush=True)
    old=json.loads((ROOT/'assets/audio/shop_theme_manifest.json').read_text());menu=old.copy();menu.pop('maps',None);menu['asset']='shop_theme_loop.ogg';menu['measurements']=measures(ROOT/'assets/audio/shop_theme_loop.ogg');result['contexts']['menu']=menu
    result['generator']={'path':'tools/prepare_world_music.py','sha256':digest(Path(__file__)),'numpy_version':np.__version__,'ffmpeg_version':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0]}
    result['contexts']['case']['original_pcm_sha256']=digest(work/'case.wav')
    result['total_bytes']=sum(m['bytes'] for m in result['contexts'].values())
    (a.output/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    (ROOT/'assets/audio/music_manifest.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
