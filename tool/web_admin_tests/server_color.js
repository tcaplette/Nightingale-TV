// Web admin: Add a server ends with the new server's guide colour (server-color-on-add 3.7).
// An SMB share is added three times: its colour chosen by keyboard on a computer, by touch on
// a phone, then the dialog closed on the colour step (the suggestion is kept). The guide shows
// each chosen colour in its key. Run from a folder with playwright installed, in the Playwright
// container on the ntv-offline network, against a server (Linux bundle --server, or the Docker
// image) whose profile NTV_PROFILE has one media server and can reach the Samba test shares at
// SMB_HOST (default 127.0.0.1), with NTV_ADMIN_PW and SMB_PW set. The share is removed after each round.
const {chromium}=require('playwright');
const B=process.env.NTV_BASE||'http://192.168.77.1:8484', pid=process.env.NTV_PROFILE, pw=process.env.NTV_ADMIN_PW;
const smbPw=process.env.SMB_PW, host=process.env.SMB_HOST||'127.0.0.1';
const shot=(p,n)=>p.screenshot({path:'shots/sc-'+n+'.png'});
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
const ok=m=>console.log('OK',m);
const api=async(ctx,m,p,b,etag)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json',...(etag?{'If-Match':etag}:{})},data:b?JSON.stringify(b):undefined});
  let j=null;try{j=JSON.parse(await r.text())}catch{}return {s:r.status(),j}};
async function open(opts,path){
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',...opts}));
  const r=await api(ctx,'POST','session',{name:'admin',password:pw}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>fail('page error '+e.message));
  await page.goto(B+`/profiles/${pid}/${path}`,{timeout:60000}); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {ctx,page};
}
const labels=page=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.innerText||'').trim()));
const shareOf=async ctx=>((await api(ctx,'GET',`profiles/${pid}/servers`)).j.servers||[]).find(s=>s.kind==='smb');
const colorOf=async(ctx,name)=>((await api(ctx,'GET',`profiles/${pid}/colors`)).j.sources||[]).find(s=>s.name===name)?.color;
async function remove(ctx){
  const share=await shareOf(ctx); if(!share) return;
  const rev=(await ctx.request.fetch(B+`/api/v1/profiles/${pid}/logo`)).headers()['etag'];
  const del=await api(ctx,'DELETE',`profiles/${pid}/servers/${share.key}`,null,rev);
  if(del.s!==200&&del.s!==204) fail('remove '+del.s);
}
// Add a server, SMB share, the archive share signed in and mapped as it's suggested: the dialog
// is left on the colour step. [tap] works it by touch.
async function addShare(page,tag,tap){
  const press=l=>tap?l.tap():l.click();
  await press(page.getByRole('button',{name:'Add a server'})); await page.waitForTimeout(1500);
  await press(page.getByRole('button',{name:'SMB share',exact:true})); await page.waitForTimeout(2500);
  await press(page.getByRole('textbox',{name:'Share address'}));
  await page.keyboard.type(`smb://${host}:1445/archive`,{delay:30}); await page.keyboard.press('Enter'); await page.waitForTimeout(4000);
  await press(page.getByRole('textbox',{name:'Username'})); await page.keyboard.type('smbtest',{delay:40});
  await press(page.getByRole('textbox',{name:'Password'})); await page.waitForTimeout(400);
  await page.keyboard.type(smbPw,{delay:60}); await page.keyboard.press('Enter'); await page.waitForTimeout(5000);
  if(!(await labels(page)).some(l=>l==="What's in archive?")) {fail(tag+': no folder step'); return false}
  await press(page.getByRole('button',{name:'Done'})); await page.waitForTimeout(6000);
  await shot(page,tag+'-step');
  const all=await labels(page);
  if(!all.some(l=>l.startsWith('Guide colour · '))) {fail(tag+': no colour step '+JSON.stringify(all.slice(0,30))); return false}
  ok(tag+': the colour step follows the folders');
  if(await page.getByRole('radio').count()!==9) fail(tag+': '+(await page.getByRole('radio').count())+' colours, not 9');
  // The share's own teal is suggested; the media server's colour is named with it.
  const teal=page.getByRole('radio',{name:'Teal'});
  if(!(await teal.count())||!(await teal.first().isChecked())) fail(tag+': teal is not selected');
  if(!all.some(l=>/^Purple · .+/.test(l))) fail(tag+': purple is not marked as in use'); else ok(tag+': the colour in use is named');
  return true;
}
async function guideHas(ctx,name){
  const page=await ctx.newPage();
  await page.goto(B+`/profiles/${pid}/guide`); await page.waitForTimeout(5000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
  const has=(await labels(page)).some(l=>l.includes(name));
  await shot(page,'guide-'+name.replace(/\W+/g,'-'));
  await page.close();
  return has;
}
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  // ---- Keyboard, on a computer: Wine, then Done ----
  let {ctx,page}=await open({viewport:{width:1280,height:900}},'servers');
  await remove(ctx);
  if(await addShare(page,'desk',false)){
    await page.getByRole('radio',{name:'Wine'}).focus(); await page.keyboard.press('Space'); await page.waitForTimeout(800);
    if(!(await page.getByRole('radio',{name:'Wine'}).isChecked())) fail('keyboard: Space did not select wine');
    await page.getByRole('button',{name:'Done'}).focus(); await page.keyboard.press('Enter'); await page.waitForTimeout(3000);
    await shot(page,'desk-done');
    const share=await shareOf(ctx);
    const c=share&&await colorOf(ctx,share.name);
    if(c!=='wine') fail('keyboard: colour is '+c); else ok('keyboard: wine chosen and saved');
    if(share&&!(await guideHas(ctx,share.name))) fail('keyboard: the guide key has no '+share.name);
  }
  await remove(ctx);
  await ctx.browser().close();

  // ---- Touch, on the narrowest phone: Olive, then Done ----
  ({ctx,page}=await open({viewport:{width:360,height:740},hasTouch:true,isMobile:true,deviceScaleFactor:2},'servers'));
  if(await addShare(page,'phone',true)){
    const olive=page.getByRole('radio',{name:'Olive'});
    await olive.scrollIntoViewIfNeeded(); await olive.tap(); await page.waitForTimeout(800);
    const done=page.getByRole('button',{name:'Done'});
    await done.scrollIntoViewIfNeeded(); await done.tap(); await page.waitForTimeout(3000);
    await shot(page,'phone-done');
    const share=await shareOf(ctx);
    const c=share&&await colorOf(ctx,share.name);
    if(c!=='olive') fail('touch: colour is '+c); else ok('touch: olive chosen and saved');
  }
  await remove(ctx);
  await ctx.browser().close();

  // ---- Closed on the colour step: added, with its suggestion ----
  ({ctx,page}=await open({viewport:{width:1280,height:900}},'servers'));
  if(await addShare(page,'close',false)){
    await page.getByRole('button',{name:'Close'}).click(); await page.waitForTimeout(3000);
    const share=await shareOf(ctx);
    if(!share) fail('close: the share is gone');
    const c=share&&await colorOf(ctx,share.name);
    if(c!=='teal') fail('close: colour is '+c); else ok('close: added, keeping teal');
  }
  await remove(ctx);
  await ctx.browser().close();
  console.log(process.exitCode?'DONE with failures':'DONE all passed');
})().catch(e=>{console.log('FAIL',e);process.exitCode=1}).finally(()=>process.exit());
