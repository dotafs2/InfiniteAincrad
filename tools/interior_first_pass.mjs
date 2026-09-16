/** Frozen first-attempt interior comparison. Run init once, then bounded tick calls.
 * No quality retries, no paid-request retries, no scheduler. Keys and raw URLs stay ignored.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const WORK=path.join(ROOT,'tmp','interior-first-pass-20260916');
const OUT=path.join(ROOT,'exports','interior-first-pass-20260916');
const requestPath=path.join(ROOT,'Art/Generated/InteriorFirstPass20260916/request.json');
const plan=JSON.parse(fs.readFileSync(requestPath,'utf8'));
const fingerprint=createHash('sha256').update(fs.readFileSync(requestPath)).digest('hex');
const save=(p,data)=>{fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p+'.new',JSON.stringify(data,null,2)+'\n');fs.renameSync(p+'.new',p);};
const statePath=path.join(WORK,'state.json');
const keys=Object.fromEntries(['tripo','meshy'].map(p=>[p,fs.readFileSync(path.join(ROOT,'secrets',p+'-key.txt'),'utf8').replace(/^\uFEFF/,'').trim()]));
const cli=process.env.TRIPO_CLI_DIR||path.join(process.env.APPDATA,'npm/node_modules/tripo-cli');
const {TripoClient}=await import(pathToFileURL(path.join(cli,'dist/core/client.js')).href);
const tripo=new TripoClient({apiKey:keys.tripo,maxRetries:0,timeoutMs:45000});
let state=fs.existsSync(statePath)?JSON.parse(fs.readFileSync(statePath,'utf8')):null;
if(state&&state.request_sha256!==fingerprint)throw new Error('frozen_request_changed');
const record=()=>save(statePath,state);
const terminal=s=>['success','SUCCEEDED','FAILED','failed','cancelled','CANCELED','banned','EXPIRED','failed_or_uncertain'].includes(s);
async function meshy(method,route,body){
  const r=await fetch('https://api.meshy.ai/openapi/'+route,{method,headers:{Authorization:'Bearer '+keys.meshy,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(45000)});
  if(!r.ok){const e=new Error('meshy_http_'+r.status);e.status=r.status;throw e;}
  return r.json();
}
async function balances(){const [t,m]=await Promise.all([tripo.getBalance(),meshy('GET','v1/balance')]);return {tripo:t,meshy:m};}
async function init(){
  if(state)throw new Error('existing_run');
  for(const asset of plan.assets)if((asset.prompt+' '+plan.style).length>800)throw new Error('prompt_too_long_'+asset.id);
  const b=await balances();
  if(b.tripo.balance<540||b.meshy.balance<540)throw new Error('insufficient_balance');
  state={request_sha256:fingerprint,created_at:new Date().toISOString(),initial_balances:b,stages:{}};record();
}
async function create(provider,asset,kind){
  const key=provider+'/'+asset.id+'/'+kind;if(state.stages[key])throw new Error('attempt_already_recorded');
  const prompt=asset.prompt+' '+plan.style;
  const payload=provider==='tripo'?{...plan.tripo,prompt,face_limit:asset.faces}:kind==='preview'?{...plan.meshy,mode:'preview',prompt,target_polycount:asset.faces}:{...plan.refine,texture_prompt:prompt,preview_task_id:state.stages['meshy/'+asset.id+'/preview'].task_id};
  const stage=state.stages[key]={provider,asset:asset.id,kind,status:'reserved',submitted_at:new Date().toISOString(),payload};record();
  try{
    const result=provider==='tripo'?await tripo.request('POST','/v3/generation/text-to-model',payload):await meshy('POST','v2/text-to-3d',payload);
    save(path.join(WORK,'receipts',key.replaceAll('/','-')+'-submission.json'),result);
    const id=result.task_id||result.result;if(typeof id!=='string')throw new Error('missing_task_id');
    Object.assign(stage,{status:'submitted',task_id:id});record();
  }catch(e){Object.assign(stage,{status:'failed_or_uncertain',error_type:e.constructor.name,error_code:e.status||null});record();throw e;}
}
async function download(url,stage){
  if(!url||new URL(url).protocol!=='https:')throw new Error('missing_https_model');
  const dest=path.join(OUT,stage.provider,stage.asset+'.glb');fs.mkdirSync(path.dirname(dest),{recursive:true});
  if(!fs.existsSync(dest)){
    const r=await fetch(url,{signal:AbortSignal.timeout(120000)});if(!r.ok)throw new Error('download_http_'+r.status);
    const fd=fs.openSync(dest+'.part','w');let size=0;
    try{for await(const chunk of r.body){size+=chunk.length;if(size>200*1024*1024)throw new Error('oversized_model');let off=0;while(off<chunk.length)off+=fs.writeSync(fd,chunk,off,chunk.length-off);}}finally{fs.closeSync(fd);}
    const data=fs.readFileSync(dest+'.part');if(data.toString('ascii',0,4)!=='glTF'||data.readUInt32LE(8)!==data.length)throw new Error('invalid_glb');
    fs.renameSync(dest+'.part',dest);
  }
  const data=fs.readFileSync(dest);stage.model={path:path.relative(ROOT,dest).replaceAll('\\','/'),bytes:data.length,sha256:createHash('sha256').update(data).digest('hex')};record();
}
async function tick(){
  if(!state)throw new Error('init_first');
  for(const [key,stage] of Object.entries(state.stages)){
    if(!stage.task_id||stage.model||terminal(stage.status)&&!['success','SUCCEEDED'].includes(stage.status))continue;
    if(stage.kind==='preview'&&stage.status==='SUCCEEDED')continue;
    const r=stage.provider==='tripo'?await tripo.getTask(stage.task_id):await meshy('GET','v2/text-to-3d/'+stage.task_id);
    save(path.join(WORK,'receipts',key.replaceAll('/','-')+'-latest.json'),r);
    Object.assign(stage,{status:r.status,progress:r.progress,credits:r.credits_consumed??r.consumed_credits??null,observed_at:new Date().toISOString()});record();
    if(['success','SUCCEEDED'].includes(r.status)){
      stage.completed_observed_at||=new Date().toISOString();record();
      if(stage.kind!=='preview')await download(stage.provider==='tripo'?r.output?.pbr_model_url||r.output?.model_url:r.model_urls?.glb,stage);
    }
  }
  // A failed/ambiguous paid request is a visible stop condition, never a new creation retry.
  if(Object.values(state.stages).some(s=>['failed_or_uncertain','failed','FAILED','banned','EXPIRED'].includes(s.status)))throw new Error('provider_failure_requires_review');
  for(const provider of ['tripo','meshy']){
    let active=Object.values(state.stages).filter(s=>s.provider===provider&&!terminal(s.status)).length;
    if(provider==='meshy')for(const a of plan.assets){
      if(active>=plan.rules.max_active_per_provider)break;
      if(state.stages['meshy/'+a.id+'/preview']?.status==='SUCCEEDED'&&!state.stages['meshy/'+a.id+'/refine']){await create('meshy',a,'refine');active++;}
    }
    for(const a of plan.assets){
      if(active>=plan.rules.max_active_per_provider)break;
      const kind=provider==='tripo'?'model':'preview';
      if(!state.stages[provider+'/'+a.id+'/'+kind]){await create(provider,a,kind);active++;}
    }
  }
  if(Object.values(state.stages).filter(s=>s.model).length===plan.assets.length*2&&!state.final_balances){state.final_balances=await balances();state.finished_at=new Date().toISOString();record();}
}
function summary(){return !state?{}:{initial_balances:state.initial_balances,final_balances:state.final_balances,finished_at:state.finished_at,providers:Object.fromEntries(['tripo','meshy'].map(p=>{const s=Object.values(state.stages).filter(s=>s.provider===p);return [p,{downloaded:s.filter(x=>x.model).length,active:s.filter(x=>!terminal(x.status)).map(x=>({asset:x.asset,kind:x.kind,status:x.status,progress:x.progress})),credits_recorded:s.reduce((n,x)=>n+(x.credits||0),0),failures:s.filter(x=>x.status==='failed_or_uncertain').map(x=>({asset:x.asset,code:x.error_code}))}];}))};}
fs.mkdirSync(WORK,{recursive:true});
const lock=path.join(WORK,'running.lock');let fd;
try{fd=fs.openSync(lock,'wx');const action=process.argv[2];if(action==='init')await init();else if(action==='tick')await tick();else if(action!=='summary')throw new Error('use_init_tick_summary');console.log(JSON.stringify(summary()));}
catch(e){console.log(JSON.stringify({error:e.constructor.name,code:e.status||null,message:Object.values(keys).reduce((s,k)=>s.replaceAll(k,'[redacted]'),String(e.message)),summary:summary()}));process.exitCode=1;}
finally{if(fd!==undefined){fs.closeSync(fd);fs.unlinkSync(lock);}}
