#!/usr/bin/env python3
"""Read decoded old/new assets and verify the score rewrite without playing sound."""
from pathlib import Path
import hashlib, importlib.util, json, math, subprocess, tempfile
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BEFORE=OUT.parent/'audio-before'
spec=importlib.util.spec_from_file_location('composer',ROOT/'tools/build_music.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checks=[]
def check(label,condition):
 checks.append({'check':label,'pass':bool(condition)})
def decode(path):
 raw=subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-ar','44100','-ac','2','pipe:1'])
 return np.frombuffer(raw,dtype='<f4').reshape(-1,2)
def spectrum(samples):
 # Welch-style, per-channel 4096-point Hann windows at 50% overlap. No stereo cancellation.
 size=4096;hop=size//2;window=np.hanning(size)
 starts=range(0,len(samples)-size+1,hop)
 power=sum(np.abs(np.fft.rfft(samples[i:i+size]*window[:,None],axis=0))**2 for i in starts).sum(axis=1)
 hz=np.fft.rfftfreq(size,1/44100);power/=sum(power)
 return {'method':'Mean stereo channel power; 4096-point Hann windows, 50% overlap; normalized spectral energy, not perceived brightness.',
  'centroid_hz':float(sum(hz*power)),
  'energy_fraction':{f'{lo}-{hi}':float(sum(power[(hz>=lo)&(hz<hi)])) for lo,hi in [(0,120),(120,500),(500,2000),(2000,4000),(4000,8000),(8000,22051)]},
  'energy_above_2000hz':float(sum(power[hz>=2000])),
  'energy_above_4000hz':float(sum(power[hz>=4000]))}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
old=json.loads((BEFORE/'assets/audio/music_manifest.json').read_text())
new=json.loads((ROOT/'assets/audio/music_manifest.json').read_text())
results=[]
for oldtrack,newtrack in zip(old['tracks'],new['tracks']):
 name=Path(newtrack['file']).stem;score=m.TRACKS[name];arr=newtrack['arrangement']
 oldpath=BEFORE/'assets/audio'/newtrack['file'];newpath=ROOT/'assets/audio'/newtrack['file']
 oldpcm=decode(oldpath);newpcm=decode(newpath)
 op=spectrum(oldpcm);npower=spectrum(newpcm)
 check(name+': source-bound encoded hash',sha(newpath)==newtrack['sha256'])
 check(name+': four separate instrument parts',len(arr['event_counts'])==4)
 check(name+': fewer than half the original events per second',arr['events_per_second']<sum(oldtrack['arrangement']['event_counts'].values())/oldtrack['decoded_vorbis']['duration_seconds']*.5)
 check(name+': written melody has at least 45% rests',arr['written_lead_rest_fraction']>=.45)
 check(name+': lead remains below F5',arr['lead_midi_range'][1]<=76)
 check(name+': no metallic counterline or continuous hats',not any(x in arr['event_counts'] for x in ['celeste','pluck','rim','shaker','kick']))
 # Three distinct pitch classes separated by a minor third or more: open-enough ordinary triads.
 check(name+': only major/minor triads',all(len(set(n%12 for n in chord))==3 and tuple(sorted((n-score['bass'][b])%12 for n in chord)) in [(0,4,7),(0,3,7)] for b,chord in enumerate(score['chords'])))
 check(name+': chord notes avoid adjacent semitones',all(min(y-x for x,y in zip(sorted(c),sorted(c)[1:]))>=3 for c in score['chords']))
 lead=[];passing=0;maxleap=0;last=None
 for bar,phrase in enumerate(score['melody']):
  previous_end=0
  for beat,pitch,length in phrase:
   check(f'{name}: bar {bar+1} note {beat} leaves valid nonoverlapping phrase',beat>=previous_end and length>0 and beat+length<=4)
   previous_end=beat+length
   if pitch%12 not in {p%12 for p in score['chords'][bar]}:
    passing+=1;check(f'{name}: passing note is brief',length<=.5)
   if last is not None:maxleap=max(maxleap,abs(pitch-last))
   last=pitch;lead.append(pitch)
 check(name+': mostly chord tones with only short passing notes',passing<=2)
 check(name+': comfortable melodic leaps including loop',max(maxleap,abs(lead[-1]-lead[0]))<=7)
 check(name+': over four dB softer than old decoded file',newtrack['decoded_vorbis']['integrated_lufs']<=oldtrack['decoded_vorbis']['integrated_lufs']-4)
 check(name+': lower absolute high-frequency energy',npower['energy_above_2000hz']*10**(newtrack['decoded_vorbis']['rms_dbfs']/10)<op['energy_above_2000hz']*10**(oldtrack['decoded_vorbis']['rms_dbfs']/10))
 check(name+': decoded level remains within gentle target',-24<newtrack['decoded_vorbis']['integrated_lufs']<-21)
 check(name+': true peak retains 6dB headroom',newtrack['decoded_vorbis']['true_peak_dbtp']<-6)
 check(name+': decoded raw sample and seam safeguards',all(newtrack['checks'].values()))
 check(name+': completely different musical PCM',newtrack['source_pcm_sha256']!=oldtrack['source_pcm_sha256'])
 results.append({'name':name,'before_spectrum':op,'after_spectrum':npower,
  'before_decoded':oldtrack['decoded_vorbis'],'after_decoded':newtrack['decoded_vorbis'],
  'before_events_per_second':sum(oldtrack['arrangement']['event_counts'].values())/oldtrack['decoded_vorbis']['duration_seconds'],
  'after_events_per_second':arr['events_per_second'],'after_written_lead_rest_fraction':arr['written_lead_rest_fraction'],
  'master_effective_rms_dbfs_before':oldtrack['decoded_vorbis']['rms_dbfs']-14,
  'master_effective_rms_dbfs_after':newtrack['decoded_vorbis']['rms_dbfs']-14,
  'old_sha256':sha(oldpath),'new_sha256':sha(newpath)})
check('Different maps retain different recording hashes',new['tracks'][0]['sha256']!=new['tracks'][1]['sha256'])
check('Runtime audio controller unchanged',sha(ROOT/'fidelity/audio.gd')==sha(BEFORE/'fidelity/audio.gd'))
check('Music and SFX buses unchanged',sha(ROOT/'fidelity/audio_bus_layout.tres')==sha(BEFORE/'fidelity/audio_bus_layout.tres'))
# Rebuild exactly once in a temporary output directory and compare the encoded bytes + full manifest.
with tempfile.TemporaryDirectory(prefix='hole-soft-music-rebuild-') as directory:
 subprocess.run([str(Path(__import__('sys').executable)),str(ROOT/'tools/build_music.py'),'--output',directory],stdout=(OUT/'rebuild.log').open('w'),stderr=subprocess.STDOUT,check=True)
 files={}
 for name in ('sunny_city_loop.ogg','snack_garden_loop.ogg','music_manifest.json'):
  source=ROOT/'assets/audio'/name;copy=Path(directory)/name
  equal=source.read_bytes()==copy.read_bytes();check('Deterministic rebuild: '+name,equal)
  files[name]={'byte_identical':equal,'sha256':sha(source)}
 rebuild={'schema':1,'date':'2026-09-30','method':'Rebuilt with the same recorded local Python/NumPy/FFmpeg toolchain in a TemporaryDirectory and compared each encoded Ogg plus the full manifest byte-for-byte. Temporary copy removed.','result':'pass' if all(x['byte_identical'] for x in files.values()) else 'fail','files':files,'limitations':'No speaker playback, browser audition or listening acceptance. Cross-codec-version byte identity is not claimed.'}
 (ROOT/'assets/audio/rebuild_verification.json').write_text(json.dumps(rebuild,indent=2)+'\n')
report={'result':'pass' if all(c['pass'] for c in checks) else 'fail','checks':len(checks),'failures':[c['check'] for c in checks if not c['pass']],
 'method':'Offline decoded-signal measurements plus authored score invariants and deterministic regeneration. No audio playback or subjective audition.',
 'runtime_mix_scope':'Existing Music bus -14dB, SFX bus 0dB, player routes and attenuation untouched. Effective RMS assumes the default master gain; actual acoustic level depends on device volume and output. Food impact rate/voices unchanged.',
 'inputs':{str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'tools/build_music.py',ROOT/'fidelity/audio.gd',ROOT/'fidelity/audio_bus_layout.tres',ROOT/'assets/audio/music_manifest.json',Path(__file__)]},
 'tracks':results,'assertions':checks}
(OUT/'author-audio-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'result':report['result'],'checks':len(checks),'failures':report['failures'],'tracks':[{k:t[k] for k in ['name','before_events_per_second','after_events_per_second','after_written_lead_rest_fraction']} for t in results]},indent=2))
raise SystemExit(0 if report['result']=='pass' else 1)
