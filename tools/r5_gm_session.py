"""One bounded native DeepSeek experiment-GM turn, with durable memory and owned cleanup.

Uses the existing GM route, prompts and event parser; keeps the original ten GM
sessions untouched. Coding, main-AI advice and later author feedback are separate.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time

import gm_runner
import model_interface_experiment as base
from owned_windows_job import WindowsProcessTree

OUT = base.ROOT/'tmp/r5-capability-20260915'


def run(phase):
    candidate = OUT/'gm-candidate'
    memory_path = OUT/'gm-memory.json'
    memory = base.read(memory_path) if memory_path.exists() else {
        'identity':'h86-gm-02','focus':gm_runner.GM_FOCUS['gm-02'],
        'branch':'New isolated experiment session; does not resume or replace original GM-02.',
        'session_id':None,'turns':[]}
    directory = OUT/'gm-turns'/phase
    if directory.exists():
        raise RuntimeError('existing_gm_turn_requires_review_no_replay')
    directory.mkdir(parents=True)
    route = gm_runner.Route(OUT/'deepseek-route.json',base.DEEPSEEK_KEY,shutil.which('codex'),None)
    resume_id = memory['session_id']
    if resume_id:
        refusal=route.preflight_resume(resume_id)
        if refusal:raise RuntimeError(refusal)
    coding = phase in ('coding','repair')
    instructions = gm_runner.STABLE_CODE_INSTRUCTIONS if coding else gm_runner.STABLE_FEEDBACK_INSTRUCTIONS
    instructions += '\nThis is the isolated H86 experimental branch of capability GM-02. Keep its own session/memory; original GM sessions are untouched. Use bounded searches in named source files. Never run the editor or import asset trees. Stop owned test processes.\n'
    instruction_path=directory/'instructions.txt';instruction_path.write_text(instructions,encoding='utf-8')
    catalog=directory/'models.json';base.write(catalog,gm_runner.codex_catalog(instructions))
    task=base.read(OUT/('gm-task.json' if phase=='coding' else 'gm-'+phase+'.json'))
    prompt=json.dumps({'identity':memory['identity'],'memory':memory,'current_task':task},ensure_ascii=False)
    route.assert_no_credential(prompt,'experiment GM prompt')
    (directory/'prompt.json').write_text(prompt,encoding='utf-8')
    output=directory/'answer.md'
    command=gm_runner.codex_command(route,candidate,output,instruction_path,catalog,resume_id,
                                    sandbox='workspace-write' if coding else 'read-only')
    logs=[open(directory/name,'w',encoding='utf-8') for name in ['native.jsonl','stderr.log']]
    started=time.monotonic()
    attempt={'phase':phase,'identity':memory['identity'],'provider':'deepseek-flash',
             'resume_requested':resume_id,'status':'reserved','usage':None}
    base.write(directory/'receipt.json',attempt)
    job=WindowsProcessTree(command,cwd=candidate,env=route.environment(),stdin=subprocess.PIPE,
                           stdout=logs[0],stderr=logs[1],text=True,encoding='utf-8')
    base.write(directory/'process.json',{'pid':job.process.pid,'status':'running'})
    try:
        job.process.communicate(prompt,timeout={'coding':720,'repair':240,'feedback':120}[phase])
    except subprocess.TimeoutExpired:
        job.terminate(124)
        attempt['timeout']=True
    finally:
        snapshot=job.snapshot();job.close()
        for log in logs:log.close()
        base.write(directory/'process.json',{'pid':job.process.pid,'exit_code':job.process.returncode,'process_tree':snapshot})
    events=gm_runner.parse_events((directory/'native.jsonl').read_text(encoding='utf-8'))
    attempt.update(exit_code=job.process.returncode,elapsed_seconds=time.monotonic()-started,
                   session_returned=events.get('thread_id'),usage=events.get('usage'),events=events,
                   assistant_text=output.read_text(encoding='utf-8') if output.exists() else '')
    attempt['usage_cumulative'] = attempt['usage']
    attempt['usage_basis'] = 'Native session cumulative; never sum resumed phase receipts.'
    attempt['status']='settled' if job.process.returncode==0 and gm_runner.usage_is_measured(attempt['usage']) else 'failed_or_uncertain'
    base.write(directory/'receipt.json',attempt)
    if attempt['session_returned']:
        if resume_id and resume_id!=attempt['session_returned']:raise RuntimeError('GM session mismatch')
        memory['session_id']=attempt['session_returned']
    memory['turns'].append({'phase':phase,'receipt':str(directory/'receipt.json'),
        'status':attempt['status'],'result':attempt['assistant_text']})
    base.write(memory_path,memory)
    base.emit({k:attempt[k] for k in ['phase','status','exit_code','elapsed_seconds','usage','session_returned']})
    if attempt['status']!='settled':raise RuntimeError('GM turn failed or usage uncertain; inspect retained evidence')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['coding','repair','feedback'])
    run(parser.parse_args().phase)
