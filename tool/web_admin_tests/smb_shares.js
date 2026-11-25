// Web admin: an SMB share added, mapped, coloured and checked (smb-sources 9.2), by keyboard,
// mouse and touch. Run from a folder with playwright installed, in the Playwright container on
// the ntv-offline network, against a server (Linux bundle --server, or the Docker image) whose
// profile NTV_PROFILE has one media server and can reach the Samba test shares at SMB_HOST
// (default 127.0.0.1, the server's own address for them), with NTV_ADMIN_PW and SMB_PW set.
// The share is removed again at the end unless KEEP_SHARE=1. No answer of the API may hold the share's password.
const {chromium}=require('playwright');
const B=process.env.NTV_BASE||'http://192.168.77.1:8484', pid=process.env.NTV_PROFILE, pw=process.env.NTV_ADMIN_PW;
const smbPw=process.env.SMB_PW, host=process.env.SMB_HOST||'127.0.0.1';
const shot=(p,n)=>p.screenshot({path:'shots/'+n+'.png'});
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
const bodies=[];
const api=async(ctx,m,p,b,etag)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json',...(etag?{'If-Match':etag}:{})},data:b?JSON.stringify(b):undefined});
  const t=await r.text();bodies.push(t);let j=null;try{j=JSON.parse(t)}catch{}return {s:r.status(),j,etag:r.headers()['etag']}};
async function open(opts,path){
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',...opts}));
  const r=await api(ctx,'POST','session',{name:'admin',password:pw}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>fail('page error '+e.message));
  page.on('response',async res=>{if(res.url().includes('/api/'))try{bodies.push(await res.text())}catch{}});
  await page.goto(B+`/profiles/${pid}/${path}`,{timeout:60000}); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {ctx,page};
}
// The semantics nodes' labels, in order.
const labels=page=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.innerText||'')));
// The n-th button after the one labelled [after] (a folder's type dropdown follows its name).
async function buttonAfter(page,after){
  const all=page.getByRole('button'); const n=await all.count();
  for(let i=0;i<n-1;i++){if(((await all.nth(i).textContent())||'').trim()===after||(await all.nth(i).getAttribute('aria-label'))===after)return all.nth(i+1)}
  throw 'no button after '+after;
}
const shareOf=async ctx=>((await api(ctx,'GET',`profiles/${pid}/servers`)).j.servers||[]).find(s=>s.kind==='smb');
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  // ---- Keyboard and mouse, on a computer ----
  let {ctx,page}=await open({viewport:{width:1280,height:900}},'servers');
  await page.getByRole('button',{name:'Add a server'}).click(); await page.waitForTimeout(1500);
  await page.getByRole('button',{name:'SMB share'}).click(); await page.waitForTimeout(2500);
  await shot(page,'s1-find');
  // The address, typed and sent with Enter.
  await page.getByRole('textbox',{name:'Share address'}).click();
  await page.keyboard.type(`smb://${host}:1445/archive`,{delay:30}); await page.keyboard.press('Enter'); await page.waitForTimeout(4000);
  await shot(page,'s2-sign-in');
  if(!(await labels(page)).some(l=>l.startsWith('Sign in to archive'))) fail('no sign-in step');
  await page.getByRole('textbox',{name:'Username'}).click(); await page.keyboard.type('smbtest',{delay:40});
  await page.getByRole('textbox',{name:'Password'}).click(); await page.waitForTimeout(400);
  await page.keyboard.type(smbPw,{delay:60}); await page.keyboard.press('Enter'); await page.waitForTimeout(5000);
  await shot(page,'s3-folders');
  if(!(await labels(page)).some(l=>l==="What's in archive?")) fail('no folder step');
  // Formats as Movies, by mouse.
  await (await buttonAfter(page,'Formats')).click(); await page.waitForTimeout(800);
  await page.getByRole('menuitem',{name:'Movies',exact:true}).last().click(); await page.waitForTimeout(1500);
  // Home as Home videos, by keyboard: focus its dropdown, open it, pick.
  await (await buttonAfter(page,'Home')).focus(); await page.keyboard.press('Enter'); await page.waitForTimeout(800);
  for(let i=0;i<12;i++){const f=await page.evaluate(()=>{const e=document.activeElement;return (e&&(e.getAttribute('aria-label')||e.innerText))||''});
    if(f.trim()==='Home videos')break; await page.keyboard.press('ArrowDown'); await page.waitForTimeout(120)}
  await page.keyboard.press('Enter'); await page.waitForTimeout(1500);
  await shot(page,'s4-mapped');
  await page.getByRole('button',{name:'Done'}).click(); await page.waitForTimeout(8000);
  // Its guide colour last (server-color-on-add): Done keeps the suggestion.
  if(!(await labels(page)).some(l=>l.startsWith('Guide colour · '))) fail('no colour step');
  await page.getByRole('button',{name:'Done'}).click(); await page.waitForTimeout(3000);
  await shot(page,'s5-added');
  let share=await shareOf(ctx);
  if(!share) {fail('the share was not added');await ctx.browser().close();return}
  console.log('ADDED',share.name);
  const settings=(await api(ctx,'GET',`profiles/${pid}/servers/${share.key}/share`)).j;
  const mapped=Object.fromEntries((settings.folders||[]).map(f=>[f.path,f.type]));
  console.log('MAPPINGS',JSON.stringify(mapped));
  if(mapped.Formats!=='movies'||mapped.Home!=='homeVideos') fail('mappings '+JSON.stringify(mapped));
  // Its guide colour, by mouse: the colours section lists both servers.
  await page.reload(); await page.waitForTimeout(4000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
  let colors=(await api(ctx,'GET',`profiles/${pid}/colors`)).j;
  const mine=s=>(colors.sources||[]).find(x=>x.name===share.name);
  // The share's dropdown shows its colour now (the other server's differs).
  const labelOf=name=>colors.palette.find(c=>c.name===name).label;
  const others=(colors.sources||[]).filter(x=>x.name!==share.name).map(x=>x.color);
  if(others.includes(mine()?.color)) fail('two servers share a colour');
  await page.getByRole('button',{name:labelOf(mine().color)}).first().click().catch(()=>fail('no colour for the share'));
  await page.waitForTimeout(800); await page.getByRole('menuitem',{name:'Wine'}).last().click(); await page.waitForTimeout(1500);
  colors=(await api(ctx,'GET',`profiles/${pid}/colors`)).j;
  if(mine()?.color!=='wine') fail('colour '+JSON.stringify(mine()));
  await shot(page,'s6-colour');
  // The guide has its key.
  await page.goto(B+`/profiles/${pid}/guide`); await page.waitForTimeout(5000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
  await shot(page,'s7-guide');
  if(!(await labels(page)).some(l=>l.includes(share.name))) fail('the guide key has no '+share.name);
  await ctx.browser().close();

  // ---- Touch, on a phone ----
  ({ctx,page}=await open({viewport:{width:390,height:844},hasTouch:true,isMobile:true},'servers'));
  await shot(page,'t1-servers');
  await page.getByRole('button',{name:labelOf('wine')}).first().tap().catch(()=>fail('no colour to tap'));
  await page.waitForTimeout(800); await page.getByRole('menuitem',{name:'Olive'}).last().tap(); await page.waitForTimeout(1500);
  colors=(await api(ctx,'GET',`profiles/${pid}/colors`)).j;
  if(mine()?.color!=='olive') fail('touch colour '+JSON.stringify(mine()));
  await shot(page,'t2-colour');
  // Down the page to the share's Can't play section (built as it scrolls into view), opened.
  const section=page.getByRole('button',{name:/^Can't play \(\d+\)/});
  for(let i=0;i<20&&!(await section.count());i++){await page.mouse.move(195,600); await page.mouse.wheel(0,400); await page.waitForTimeout(400)}
  if(await section.count()){await section.first().tap(); await page.waitForTimeout(1200)} else fail("no Can't play section");
  const check=page.getByRole('button',{name:'Check again'});
  if(await check.count()){await check.first().tap(); await page.waitForTimeout(4000); await shot(page,'t3-check-again')} else fail('no Check again');
  // Taken away again (KEEP_SHARE=1 keeps it, for checks that follow).
  share=await shareOf(ctx);
  if(!process.env.KEEP_SHARE){
  // The profile's revision, as the web admin reads it.
  const rev=(await ctx.request.fetch(B+`/api/v1/profiles/${pid}/logo`)).headers()['etag'];
  const del=await api(ctx,'DELETE',`profiles/${pid}/servers/${share.key}`,null,rev);
  if(del.s!==200&&del.s!==204) fail('remove '+del.s);
  }
  await ctx.browser().close();
  if(bodies.some(b=>b.includes(smbPw))) fail('an answer holds the share password');
  console.log(process.exitCode?'FAILED':'PASSED', bodies.length,'answers checked');
})().catch(e=>fail(String(e))).finally(()=>process.exit());
