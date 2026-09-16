/** Meshy account onboarding through its visible official UI. No cookies or traces saved.
 * Invoked by meshy_pool.py inside an owned Windows process job.
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const SECRET=path.join(ROOT,'secrets','meshy-pool');
const PRIVATE=path.join(ROOT,'private','meshy-pool','onboarding');
const configFile=path.join(SECRET,'accounts.json');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const hash=s=>createHash('sha256').update(s).digest('hex');
const emit=(event,fields={})=>console.log(JSON.stringify({event,...fields}));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const save=(p,obj)=>{fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p+'.new',JSON.stringify(obj,null,2)+'\n');fs.renameSync(p+'.new',p);};
const stop=code=>{const error=new Error(code);error.safeCode=code;throw error;};

function playwright(){
  const bundled=path.join(os.homedir(),'.cache','codex-runtimes','codex-primary-runtime','dependencies','node','node_modules');
  for(const base of [path.join(ROOT,'package.json'),path.join(process.env.PLAYWRIGHT_MODULE_DIR||bundled,'package.json')]){
    try{return createRequire(base)('playwright');}catch{}
  }
  stop('PLAYWRIGHT_NOT_FOUND_SET_PLAYWRIGHT_MODULE_DIR');
}

async function visible(locator){
  for(let i=0;i<Math.min(await locator.count(),12);i++)if(await locator.nth(i).isVisible())return locator.nth(i);
  return null;
}

async function waitManual(page,id,reason,predicate,seconds=180){
  emit('manual_action_required',{account:id,reason,timeout_seconds:seconds});
  const until=Date.now()+seconds*1000;
  while(Date.now()<until){
    if(page.isClosed())stop('BROWSER_CLOSED_'+id);
    const result=await predicate();
    if(result)return result;
    await sleep(1500);
  }
  stop('MANUAL_ACTION_TIMEOUT_'+id);
}

async function balance(key){
  const response=await fetch('https://api.meshy.ai/openapi/v1/balance',{
    headers:{Authorization:'Bearer '+key},redirect:'error',signal:AbortSignal.timeout(45000)});
  if(!response.ok)stop('KEY_BALANCE_HTTP_'+response.status);
  const result=await response.json();
  if(typeof result.balance!=='number'||!Number.isFinite(result.balance)||result.balance<0)stop('INVALID_BALANCE');
  return result.balance;
}

async function register(account,keyFile,state,stateFile){
  const key=fs.readFileSync(keyFile,'utf8').trim();
  if(!/^msy_[A-Za-z0-9_-]{16,256}$/.test(key))stop('INVALID_CAPTURED_KEY');
  const credit=await balance(key);
  const config=read(configFile);
  const existing=config.accounts.find(a=>a.id===account.id);
  if(existing&&existing.login_email_sha256!==hash(account.email.toLowerCase()))stop('ACCOUNT_ID_COLLISION');
  if(!existing){
    config.accounts.push({id:account.id,key_file:'keys/'+account.id+'.txt',enabled:true,
      price_cny:account.price_cny??12,purchased_credits:account.purchased_credits??1100,
      login_email_sha256:hash(account.email.toLowerCase())});
    save(configFile,config);
  }
  state.status='ready';state.finished_at=new Date().toISOString();save(stateFile,state);
  emit('account_ready',{account:account.id,balance:credit});
}

async function login(page,account){
  await page.goto('https://www.meshy.ai/workspace',{waitUntil:'domcontentloaded',timeout:45000});
  const loginButton=page.getByRole('button',{name:/^(Log In|登录)$/i});
  await loginButton.first().waitFor({state:'visible',timeout:20000});
  await loginButton.first().click();
  const passwordMode=page.getByRole('button',{name:/^(Use Password|使用密码|密码登录)$/i});
  await passwordMode.first().waitFor({state:'visible',timeout:15000});
  await passwordMode.first().click();
  const email=page.locator('input[type="email"]');
  const password=page.locator('input[type="password"]');
  await email.first().fill(account.email);
  await password.first().fill(account.password);
  // Only submit Meshy's login form; no signup, payment, or verification bypass.
  if(new URL(page.url()).hostname!=='www.meshy.ai')stop('UNEXPECTED_LOGIN_ORIGIN');
  const form=password.first().locator('xpath=ancestor::form[1]');
  let submit=await visible(form.getByRole('button',{name:/^(Log In|Login|Sign In|Continue|登录)$/i}));
  submit ||= await visible(page.getByRole('dialog').getByRole('button',{name:/^(Log In|Login|Sign In|Continue|登录)$/i}));
  submit ||= await visible(page.getByRole('button',{name:/^(Continue|登录)$/i}));
  if(!submit)stop('LOGIN_SUBMIT_NOT_FOUND');
  await submit.click();
  for(let i=0;i<8;i++){
    if(!(await visible(password)) && !(await visible(loginButton)))return;
    const invalid=await page.getByText(/incorrect (email|password)|invalid credentials|密码错误|账号或密码错误/i).count();
    if(invalid)stop('LOGIN_REJECTED_'+account.id);
    await sleep(1000);
  }
  await waitManual(page,account.id,'Complete any CAPTCHA, email code or two-factor check in the visible Meshy window.',
    async()=>!(await visible(password))&&!(await visible(loginButton)));
}

async function extractKey(page){
  // Inspect only visible dialog content and displayed key fields. Never log their text.
  const values=await page.locator('[role="dialog"] input, [role="dialog"] textarea, [role="dialog"] code, [role="dialog"] pre, input[readonly], textarea[readonly]').evaluateAll(elements=>elements.map(e=>e.value||e.textContent||''));
  const dialogs=await page.getByRole('dialog').allTextContents();
  for(const text of [...values,...dialogs]){
    const match=text.match(/\bmsy_[A-Za-z0-9_-]{16,256}\b/);
    if(match)return match[0];
  }
  return null;
}

async function createKey(page,account,state,stateFile,keyFile){
  await page.goto('https://www.meshy.ai/settings/api',{waitUntil:'domcontentloaded',timeout:45000});
  const create=page.getByRole('button',{name:/^(Create API Key|New API Key|创建 API Key|创建 API 密钥|创建密钥)$/i});
  let button;
  try{await create.first().waitFor({state:'visible',timeout:12000});button=await visible(create);}catch{}
  if(!button)button=await waitManual(page,account.id,'Open your API key settings. API access may require a paid plan; this script will not purchase one.',()=>visible(create));
  await button.click();
  let dialog=page.getByRole('dialog');
  try{await dialog.first().waitFor({state:'visible',timeout:10000});}catch{stop('CREATE_KEY_DIALOG_NOT_FOUND');}
  dialog=dialog.filter({has:page.locator('input')}).last();
  let name=await visible(dialog.getByRole('textbox',{name:/name|名称/i}));
  name ||= await visible(dialog.locator('input[type="text"],input:not([type])'));
  if(!name)stop('KEY_NAME_INPUT_NOT_FOUND');
  await name.fill(state.key_name);
  const confirm=await visible(dialog.getByRole('button',{name:/^(Create|Create API Key|Generate|生成|创建|创建密钥|确认)$/i}));
  if(!confirm)stop('CREATE_KEY_CONFIRM_NOT_FOUND');
  state.status='create_submitting';save(stateFile,state);
  await confirm.click();
  let key;
  for(let i=0;i<15&&!key;i++){await sleep(500);key=await extractKey(page);}
  if(!key)key=await waitManual(page,account.id,'The key was submitted for creation. Keep the one-time key dialog open; do not create another key.',()=>extractKey(page),90);
  fs.mkdirSync(path.dirname(keyFile),{recursive:true});
  fs.writeFileSync(keyFile,key+'\n',{flag:'wx',mode:0o600});
  state.status='key_saved_pending_verification';save(stateFile,state);
  await register(account,keyFile,state,stateFile);
}

async function main(){
  const index=process.argv.indexOf('--limit');
  const limit=index<0?1:Number(process.argv[index+1]);
  if(!Number.isInteger(limit)||limit<1||limit>100)stop('INVALID_LIMIT');
  const entries=read(path.join(SECRET,'accounts-to-import.json')).accounts;
  if(!Array.isArray(entries))stop('INVALID_ACCOUNT_INBOX');
  const ids=new Set(),emails=new Set();
  for(const a of entries){
    if(!/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/.test(a.id||''))stop('INVALID_ACCOUNT_ID');
    if(!a.email&&!a.password)continue;
    if(typeof a.email!=='string'||!a.email.includes('@')||typeof a.password!=='string'||!a.password)stop('MISSING_EMAIL_OR_PASSWORD_'+a.id);
    if(ids.has(a.id)||emails.has(a.email.toLowerCase()))stop('DUPLICATE_ACCOUNT_IN_INBOX');
    if(!Number.isFinite(a.price_cny??12)||(a.price_cny??12)<=0||!Number.isInteger(a.purchased_credits??1100)||(a.purchased_credits??1100)<=0)stop('INVALID_ACCOUNT_COST');
    ids.add(a.id);emails.add(a.email.toLowerCase());
  }
  const config=read(configFile);
  for(const entry of entries){
    const existing=config.accounts.find(a=>a.id===entry.id);
    if(existing&&entry.email&&existing.login_email_sha256!==hash(entry.email.toLowerCase()))stop('ACCOUNT_ID_EMAIL_CHANGED');
  }
  const entriesToRun=entries.filter(a=>a.email&&a.password&&!config.accounts.some(c=>c.id===a.id)).slice(0,limit);
  if(!entriesToRun.length){emit('no_accounts_to_onboard',{message:'Fill email/password in the local private inbox first, or all listed accounts are already configured.'});return;}
  const {chromium}=playwright();
  const browser=await chromium.launch({headless:false,...(process.platform==='win32'?{channel:'msedge'}:{})});
  try{
    for(const account of entriesToRun){
      const stateFile=path.join(PRIVATE,account.id+'.json');
      const keyFile=path.join(SECRET,'keys',account.id+'.txt');
      const state=fs.existsSync(stateFile)?read(stateFile):{id:account.id,login_email_sha256:hash(account.email.toLowerCase()),status:'new',key_name:'aincrad-pool-'+account.id,started_at:new Date().toISOString()};
      if(state.login_email_sha256!==hash(account.email.toLowerCase()))stop('ACCOUNT_ID_EMAIL_CHANGED');
      if(fs.existsSync(keyFile)){await register(account,keyFile,state,stateFile);continue;}
      if(state.status==='create_submitting')stop('KEY_CREATION_UNCERTAIN_'+account.id+'_SAVE_EXISTING_KEY_TO_PRIVATE_KEY_FILE');
      save(stateFile,state);
      const context=await browser.newContext({locale:'en-US',viewport:{width:1280,height:900}});
      try{
        const page=await context.newPage();
        emit('logging_in',{account:account.id});
        await login(page,account);
        await createKey(page,account,state,stateFile,keyFile);
      }finally{await context.close();}
    }
  }finally{await browser.close();}
}
main().catch(error=>{emit('onboarding_stopped',{code:error.safeCode||'BROWSER_'+error.name});process.exitCode=2;});
