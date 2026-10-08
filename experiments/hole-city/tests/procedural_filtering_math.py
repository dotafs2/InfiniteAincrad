"""Test shipped scalar shader helpers with an independent interval oracle.

Compiles the actual GLSL helper text as C++ float arithmetic. This is not an
image-quality test. Full shader compilation and device captures are separate.
No engine, importer, UI window, save, or project setting is changed.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/visual-quality-20260928/filtering'


def expected_interval(x, start, width, span):
    lo, hi = x - span / 2, x + span / 2
    return max(0.0, min(hi, start + width) - max(lo, start)) / span


def expected_repeat(x, start, width, period, span):
    # Enumerate physical painted intervals; no floor/fract antiderivative.
    lo, hi = x - span / 2, x + span / 2
    first = math.floor((lo - start) / period) - 1
    last = math.ceil((hi - start) / period) + 1
    covered = sum(max(0.0, min(hi, start + k * period + width) -
                      max(lo, start + k * period)) for k in range(first, last + 1))
    return covered / span


def main():
    rng = random.Random(20260928)
    # Actual lane paint, paving joints, facade panes/frames/crossbars and grass.
    patterns = [(0.045,.11,3.7), (1.2,1.8,3), (.035,1.365,1.4),
                (.0392,1.3608,1.4), (.23,.54,1), (.16,.68,1),
                (.01,.98,1), (0,1,1), (.482,.036,1), (.48,.52,1), (.2,.8,1)]
    cases = []
    for start,width,period in patterns:
        for span_ratio in [.002,.01,.1,.5,1,2,7,16]:
            for x in [start, start+width, start+period, -2*period+start,
                      start-width/2, start+width/2, rng.uniform(-45,45)]:
                cases.append((x,start,width,period,span_ratio*period))
    helpers = {}
    for name in ['asphalt','facade']:
        code = (ROOT/'fidelity'/(name+'.gdshader')).read_text()
        helpers[name] = code.split('// FILTERING_HELPERS_BEGIN')[1].split('// FILTERING_HELPERS_END')[0]
    preamble = '''#include <algorithm>
#include <cmath>
#include <iostream>
#include <iomanip>
using std::min; using std::max; using std::floor;
float fract(float x){return x-std::floor(x);}
float clamp(float x,float lo,float hi){return std::clamp(x,lo,hi);}
'''
    results = {}
    with tempfile.TemporaryDirectory(prefix='hole-filter-mask-') as temp:
        temp = Path(temp)
        for name,helper in helpers.items():
            # GLSL unsuffixed constants are floats; C++ requires the suffix.
            helper = re.sub(r'(?<![\w.])(\d+\.\d+)(?![\w.])',r'\1f',helper)
            main_code = '\nint main(){float x,start,width,period,span;std::cout<<std::setprecision(9);while(std::cin>>x>>start>>width>>period>>span){std::cout<<coverage_repeat(x,start,width,period,span)'
            if name == 'asphalt':
                main_code += '<<" "<<coverage_interval(x,start,start+width,span)'
            main_code += '<<"\\n";}return 0;}\n'
            source = temp/(name+'.cpp'); binary=temp/name
            source.write_text(preamble+helper+main_code)
            subprocess.run(['xcrun','clang++','-std=c++17','-O2',str(source),'-o',str(binary)],check=True,timeout=30)
            inp=''.join(' '.join(map(str,c))+'\n' for c in cases)
            run=subprocess.run([str(binary)],input=inp,text=True,capture_output=True,check=True,timeout=10)
            rows = [list(map(float,r.split())) for r in run.stdout.splitlines()]
            assert len(rows)==len(cases)
            errors=[]; interval_errors=[]; far_phase=[]
            for case,row in zip(cases,rows):
                x,start,width,period,span=case
                errors.append(abs(row[0]-expected_repeat(*case)))
                assert math.isfinite(row[0]) and 0<=row[0]<=1
                # Includes float cancellation at distant coordinates. The
                # coverage error budget is half a percentage point.
                assert errors[-1] < .005, (name,case,row,errors[-1])
                if name=='asphalt':
                    interval_errors.append(abs(row[1]-expected_interval(x,start,width,span)))
                    assert interval_errors[-1] < .005, (case,row)
                if span>=period and abs(span/period-round(span/period))<1e-6:
                    far_phase.append(abs(row[0]-width/period))
                    assert far_phase[-1] < .0001, (name,'distant duty cycle',case,row)
            results[name]={'periodic_cases':len(rows),'max_coverage_error':max(errors),
                           'single_interval_cases':len(interval_errors),
                           'max_interval_error':max(interval_errors,default=0),
                           'integer_period_phase_cases':len(far_phase),'max_duty_cycle_error':max(far_phase)}
    output={'status':'PASS','scope':'Actual shipped scalar shader helpers compiled as C++ float arithmetic; independent interval-intersection oracle. Not browser/device pixels.',
            'results':results,'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'fidelity/asphalt.gdshader',ROOT/'fidelity/facade.gdshader',Path(__file__)]}}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'mask-math.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(output))


if __name__=='__main__':
    main()
