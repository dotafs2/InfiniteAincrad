/** One bounded Tripo/Meshy house comparison. No creation request is retried.
 * Uses Tripo CLI's installed official client, with maxRetries=0; Meshy uses its
 * official API. Credentials, signed URLs and raw receipts remain local.
 * node tools/compare_house_providers.mjs start|tick|summary
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const OUT=path.join(ROOT,'tmp','tripo-meshy-comparison-20260916','generation');
const MODELS=path.join(ROOT,'exports','tripo-meshy-comparison-20260916');
const CLI=process.env.TRIPO_CLI_DIR || path.join(process.env.APPDATA || '', 'npm','node_modules','tripo-cli');
const {TripoClient}=await import(pathToFileURL(path.join(CLI,'dist','core','client.js')).href);
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const save=(p,v)=>{fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p+'.new',JSON.stringify(v,null,2)+'\n');fs.renameSync(p+'.new',p);};
const statePath=path.join(OUT,'state.json');
const manifestPath=path.join(OUT,'manifest.json');
const prompt='One complete standalone two-storey fantasy cottage. Pale cream stone and plaster, honey oak framing, muted terracotta gable roof, teal shutters. Arched front door, small covered porch, one dormer, chimney and window flower boxes. Cohesive hand-painted anime European town style, clean broad colors, soft wear and clear shapes. Complete roof and all four exterior walls, including a finished back. Only one building: no people, text, landscape, base slab, cutaway or baked shadows. Intended game building about 7 metres wide.';
const plan={id:'tripo-meshy-comparison-20260916',prompt,maximum_creations:{tripo:1,meshy_preview:1,meshy_refine:1},
  planned_credits:{tripo:30,meshy:30},expected_target_faces:80000,
  tripo:{prompt,model:'v3.1-20260211',face_limit:80000,texture:true,pbr:true,texture_quality:'detailed',geometry_quality:'standard'},
  meshy:{mode:'preview',prompt,ai_model:'meshy-7',model_type:'standard',should_remesh:true,topology:'triangle',target_polycount:80000,ultra_mode:false,target_formats:['glb']},
  refine:{mode:'refine',ai_model:'meshy-7',enable_pbr:true,texture_resolution:'4k',texture_prompt:prompt,target_formats:['glb']},
  limitations:['One specimen per provider; no general model ranking.','Same text and approximate face target; provider algorithms and texture semantics differ.','Geometry and texture are generated separately in Meshy, together in Tripo.']};
if(fs.existsSync(manifestPath)){
  if(JSON.stringify(read(manifestPath))!==JSON.stringify(plan))throw new Error('frozen_manifest_changed');
}else save(manifestPath,plan);
let state=fs.existsSync(statePath)?read(statePath):{stages:{},started:new Date().toISOString()};
const keys=Object.fromEntries(['tripo','meshy'].map(name=>[name,fs.readFileSync(path.join(ROOT,'secrets',name+'-key.txt'),'utf8').replace(/^\uFEFF/,'').trim()]));
if(Object.values(keys).some(k=>!k))throw new Error('empty_key');
const tripo=new TripoClient({apiKey:keys.tripo,maxRetries:0,timeoutMs:30000});
async function meshy(method,route,body){
  const response=await fetch('https://api.meshy.ai/openapi/'+route,{method,headers:{Authorization:'Bearer '+keys.meshy,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(30000)});
  const result=await response.json();
  if(!response.ok){const e=new Error('meshy_http_'+response.status);e.status=response.status;throw e;}
  return result;
}
function record(){save(statePath,state);}
async function create(name,payload,call){
  if(state.stages[name])throw new Error('existing_attempt_no_automatic_replay_'+name);
  state.stages[name]={status:'reserved',submitted_at:new Date().toISOString(),payload};record();
  try{
    const response=await call();save(path.join(OUT,name+'-submission.json'),response);
    const id=response.task_id || response.result;
    if(typeof id!=='string'||!id)throw new Error('no_task_id');
    Object.assign(state.stages[name],{task_id:id,status:'submitted'});record();
  }catch(error){Object.assign(state.stages[name],{status:'failed_or_uncertain',error_type:error.constructor.name,error_code:error.status || null});record();throw error;}
}
async function start(){
  if(Object.keys(state.stages).length)throw new Error('comparison_already_started');
  const balances=await Promise.all([tripo.getBalance(),meshy('GET','v1/balance')]);
  state.initial_balances={tripo:balances[0],meshy:balances[1]};record();
  if(Number(balances[0].balance)<30||Number(balances[1].balance)<30)throw new Error('insufficient_balance');
  await create('tripo',plan.tripo,()=>tripo.request('POST','/v3/generation/text-to-model',plan.tripo));
  await create('meshy_preview',plan.meshy,()=>meshy('POST','v2/text-to-3d',plan.meshy));
}
async function download(url,name){
  if(!url)return null;
  if(new URL(url).protocol!=='https:')throw new Error('non_https_artifact');
  fs.mkdirSync(MODELS,{recursive:true});const target=path.join(MODELS,name);
  if(fs.existsSync(target))return {path:target,bytes:fs.statSync(target).size,sha256:createHash('sha256').update(fs.readFileSync(target)).digest('hex')};
  // Signed downloads receive no API Authorization header.
  const response=await fetch(url,{signal:AbortSignal.timeout(120000)});
  if(!response.ok)throw new Error('download_http_'+response.status);
  const file=fs.openSync(target+'.part','w');let size=0;const digest=createHash('sha256');
  try{for await(const chunk of response.body){size+=chunk.length;if(size>300*1024*1024)throw new Error('artifact_size_limit');fs.writeSync(file,chunk);digest.update(chunk);}}
  finally{fs.closeSync(file);}
  if(name.endsWith('.glb')){
    const header=Buffer.alloc(12);const check=fs.openSync(target+'.part','r');try{fs.readSync(check,header,0,12,0);}finally{fs.closeSync(check);}
    if(header.toString('ascii',0,4)!=='glTF'||header.readUInt32LE(4)!==2||header.readUInt32LE(8)!==size)throw new Error('invalid_glb');
  }
  fs.renameSync(target+'.part',target);return {path:target,bytes:size,sha256:digest.digest('hex')};
}
async function tick(){
  for(const name of ['tripo','meshy_preview','meshy_refine']){
    const stage=state.stages[name];if(!stage?.task_id)continue;
    if(['failed','FAILED','cancelled','CANCELED','banned','EXPIRED'].includes(stage.status))continue;
    const result=name==='tripo'?await tripo.getTask(stage.task_id):await meshy('GET','v2/text-to-3d/'+stage.task_id);
    save(path.join(OUT,name+'-latest.json'),result);
    Object.assign(stage,{status:result.status,progress:result.progress,credits_consumed:result.credits_consumed ?? result.consumed_credits ?? result.consumed_credit ?? null,last_observed:new Date().toISOString()});record();
    if(['success','SUCCEEDED'].includes(result.status)){
      stage.observed_complete_at ||= new Date().toISOString();record();
      if(name!=='meshy_preview'&&!stage.model){
        const url=name==='tripo'?result.output?.pbr_model_url || result.output?.model_url:result.model_urls?.glb;
        if(!url)throw new Error('missing_model_url_'+name);
        stage.model=await download(url,name+'.glb');record();
      }
      if(name==='meshy_preview'&&!state.stages.meshy_refine){
        const payload={...plan.refine,preview_task_id:stage.task_id};
        await create('meshy_refine',payload,()=>meshy('POST','v2/text-to-3d',payload));
      }
    }
  }
  if(state.stages.tripo?.model&&state.stages.meshy_refine?.model&&!state.final_balances){
    const balances=await Promise.all([tripo.getBalance(),meshy('GET','v1/balance')]);
    state.final_balances={tripo:balances[0],meshy:balances[1]};state.finished=new Date().toISOString();record();
  }
}
function summary(){return {stages:Object.fromEntries(Object.entries(state.stages).map(([name,s])=>[name,{task_id:s.task_id,status:s.status,progress:s.progress,credits_consumed:s.credits_consumed,model:s.model}])),initial_balances:state.initial_balances,final_balances:state.final_balances,finished:state.finished};}
try{
  const action=process.argv[2];if(action==='start')await start();else if(action==='tick')await tick();else if(action!=='summary')throw new Error('use_start_tick_or_summary');
  console.log(JSON.stringify(summary()));
}catch(error){console.log(JSON.stringify({error_type:error.constructor.name,error_code:error.status||null,message:Object.values(keys).reduce((s,k)=>s.replaceAll(k,'[redacted]'),String(error.message)),state:summary()}));process.exitCode=1;}
