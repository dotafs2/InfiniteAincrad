"""Bind scene, isolated-shader, CPU-trace and HTTP delivery evidence.

This checks stored bytes and receipts, never captures a browser or certifies
the appearance or frame rate of a physical device.
"""
import argparse
import hashlib
import json
import math
import statistics
from pathlib import Path
from urllib.request import urlopen
from urllib.parse import quote
from release_web import ROOT, SUITES, input_hashes
from profile_maps import profile_hashes, validate_trace


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--url',default='http://127.0.0.1:8768/')
    args=parser.parse_args();base=args.evidence.resolve()
    destination=base/'verification.json';destination.unlink(missing_ok=True)
    release=read(base/'release/release.json')
    if release['failures'] or release['source_sha256']!=input_hashes():
        raise RuntimeError('Current source differs from the successful release')
    for phase,total in [('source','source_checks'),('package','packaged_checks')]:
        checks=0
        for suite,_,minimum in SUITES:
            receipt=read(base/'release'/f'{phase}-{suite}.json')
            if receipt.get('failures') or type(receipt.get('checks')) is not int or receipt['checks']<minimum:
                raise RuntimeError('Missing or unsuccessful scene suite: '+phase+'/'+suite)
            checks+=receipt['checks']
        if release.get(total)!=checks:raise RuntimeError('Scene total differs from suite receipts')
    if not {'index.html','index.js','index.pck','index.wasm','device-qa.js'}<=set(release['artifacts']):
        raise RuntimeError('Release is missing core exported artifacts')
    shaders=read(base/'shader-probe-final/result.json')
    if shaders['failures']:
        raise RuntimeError('Shader coverage did not pass')
    expected_programs={'asphalt','facade','palette','food_glaze','hole_reveal_standard','reveal-coverage','adapter-albedo','selective-palette','selective-food_glaze','selective-hole_reveal_standard'}
    if len(shaders['programs'])!=len(expected_programs) or {p['name'] for p in shaders['programs']}!=expected_programs or not all(p.get('compiled') is True for p in shaders['programs']):
        raise RuntimeError('Shader program receipt is incomplete')
    fixture=read(base/'shader-probe-final/fixture.json')
    jobs={p['name']:p for p in fixture['programs']}
    if set(jobs)!=expected_programs:raise RuntimeError('Shader fixture is incomplete')
    for program in shaders['programs']:
        expected=jobs[program['name']]['cases'];measured=program['cases']
        required_count={'reveal-coverage':19,'adapter-albedo':12,'selective-palette':3,'selective-food_glaze':5,'selective-hole_reveal_standard':2}.get(program['name'],0)
        if len(expected)!=required_count or len(measured)!=required_count or [c['name'] for c in measured]!=[c['name'] for c in expected]:
            raise RuntimeError('Shader case receipt is incomplete')
        for case,result in zip(expected,measured):
            if result['total_pixels']!=4096:raise RuntimeError('Incorrect shader coverage resolution')
            if case.get('expected')=='solid' and result['visible_pixels']!=4096:raise RuntimeError('Excluded fragment was discarded')
            if case.get('expected')=='cut' and not 0<result['visible_pixels']<=614:raise RuntimeError('Foreground reveal did not clear aperture')
            if 'expected_rgba8' in case and (len(result['center_rgba8'])!=4 or max(abs(a-b) for a,b in zip(case['expected_rgba8'],result['center_rgba8']))>1):
                raise RuntimeError('Adapter midtone differs')
    required_inputs={'fidelity/'+name for name in ['asphalt.gdshader','facade.gdshader','palette.gdshader','food_glaze.gdshader','hole_reveal_standard.gdshader','hole_reveal.gdshaderinc']}
    required_inputs.update(['tools/validate_mobile_visual_shaders.py','tools/visual_shader_probe.m'])
    if not required_inputs<=set(shaders['input_sha256']):raise RuntimeError('Shader inputs are missing')
    for name,expected in shaders['input_sha256'].items():
        if sha(ROOT/name)!=expected:
            raise RuntimeError('Shader probe is stale: '+name)
        if name in release['source_sha256'] and release['source_sha256'][name]!=expected:
            raise RuntimeError('Shader probe and exported source differ: '+name)
    profile=read(base/'cpu/summary.json')
    if profile['source_sha256']!=profile_hashes(args.godot.resolve()) or profile.get('inputs_unchanged')!=True:
        raise RuntimeError('CPU trace is stale or changed during measurement')
    if type(profile.get('repeats')) is not int or profile['repeats']<1:raise RuntimeError('CPU trace repeats must be positive')
    if set(profile['summary'])!={'city-opening','city-grown','food-opening','food-grown'}:
        raise RuntimeError('CPU summary scenarios are incomplete')
    version=next(line.split('=',1)[1].strip('"') for line in (ROOT/'project.godot').read_text().splitlines() if line.startswith('config/version='))
    traces=[]
    for map_id in ['city','food']:
        for scenario in ['opening','grown']:
            records=[]
            for repeat in range(1,profile['repeats']+1):
                path=base/'cpu'/f'{map_id}-{scenario}-{repeat}.json'
                record=read(path);validate_trace(record,map_id,scenario,version);records.append(record)
                traces.append({'file':str(path.relative_to(base)),'sha256':sha(path)})
            aggregate={key:statistics.median(r[key] for r in records) for key in ['p50_ms','p95_ms','p99_ms','worst_ms','nodes']}
            aggregate.update({key:sum(r[key] for r in records) for key in ['samples','over_16_67_ms','measured_reveal_updates']})
            for key,value in aggregate.items():
                reported=profile['summary'][map_id+'-'+scenario].get(key)
                if type(reported) not in (int,float) or not math.isfinite(reported) or not math.isclose(value,reported,abs_tol=.000001):
                    raise RuntimeError('CPU summary differs from raw trace: '+key)
    delivery={}
    for name,expected in release['artifacts'].items():
        if Path(name).name!=name:raise RuntimeError('Invalid artifact basename')
        with urlopen(args.url.rstrip('/')+'/'+quote(name),timeout=60) as response:
            actual=hashlib.sha256(response.read()).hexdigest()
            headers={key:response.headers.get(key) for key in ['Cross-Origin-Opener-Policy','Cross-Origin-Embedder-Policy','Cache-Control']}
        if actual!=expected:raise RuntimeError('HTTP delivery differs: '+name)
        if headers['Cross-Origin-Opener-Policy']!='same-origin' or headers['Cross-Origin-Embedder-Policy']!='require-corp':
            raise RuntimeError('Missing WebAssembly isolation headers')
        delivery[name]={'sha256':actual,'headers':headers}
    result={'version':version,'failures':[],'source_checks':release['source_checks'],
        'packaged_checks':release['packaged_checks'],'shader_programs':len(shaders['programs']),
        'shader_cases':sum(len(p['cases']) for p in shaders['programs']),
        'cpu_samples':sum(s['samples'] for s in profile['summary'].values()),
        'traces':traces,'http_artifacts':delivery,
        'receipt_sha256':{str(p.relative_to(base)):sha(p) for p in [base/'release/release.json',base/'shader-probe-final/result.json',base/'cpu/summary.json']},
        'verification_tool_sha256':sha(Path(__file__)),
        'limitation':'Static HTTP delivery, headless scene/CPU checks and isolated shader equations; no browser/game capture or iPhone certification'}
    destination.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['version','source_checks','packaged_checks','shader_cases','cpu_samples','failures']}))


if __name__=='__main__':main()
