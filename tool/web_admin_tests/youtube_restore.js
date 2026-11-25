// Web admin (docker-youtube 5.4): a TV backup with YouTube channels on Nightingale TV's client, restored
// on the server, keeps its YouTube channels with their numbers; YouTube shows Needs sign-in, and Sign in
// again opens the Client ID and Client secret step. Run from a folder with playwright installed, in the
// Playwright container, against the Docker image, with NTV_ADMIN_PW set and BACKUP_FILE the backup
// (three YouTube channels, 701–703, on server s2). As after any restore, the profile first signs in to
// its media server again: MS_URL, MS_USER, MS_PW (the test server).
const {chromium}=require('playwright');
const fs=require('fs');
const B=process.env.NTV_BASE||'http://127.0.0.1:8484', pw=process.env.NTV_ADMIN_PW, user=process.env.NTV_ADMIN||'admin';
const file=process.env.BACKUP_FILE;
const shot=(p,n)=>p.screenshot({path:'shots/restore-'+n+'.png'});
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
const ok=m=>console.log('OK',m);
const api=async(ctx,m,p,b,raw)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1',...(raw?{'Content-Type':'application/octet-stream'}:{'Content-Type':'application/json'})},data:raw||(b?JSON.stringify(b):undefined)});
  let j=null;try{j=JSON.parse(await r.text())}catch{}return {s:r.status(),j}};
const labels=page=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.innerText||'').trim()));
(async()=>{
  fs.mkdirSync('shots',{recursive:true});
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:900}}));
  const r=await api(ctx,'POST','session',{name:user,password:pw}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>fail('page error '+e.message));
  await page.goto(B+'/backups',{timeout:60000}); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
  const [chooser]=await Promise.all([page.waitForEvent('filechooser'),page.getByRole('button',{name:/Restore from a file/}).click()]);
  await chooser.setFiles(file); await page.waitForTimeout(3000);
  await shot(page,'confirm');
  const go=page.getByRole('button',{name:/^Restore/}).last(); await go.click();
  for(let i=0;i<60;i++){await page.waitForTimeout(2000); const s=(await api(ctx,'GET','status')).j; if(s&&s.started&&(s.profiles||[]).length) break}
  await page.waitForTimeout(3000);
  const profiles=(await api(ctx,'GET','profiles')).j||[];
  const mom=profiles.find(p=>p.name==='Mom'); if(!mom){fail('no Mom after the restore '+JSON.stringify(profiles)); return}
  await api(ctx,'POST',`profiles/${mom.id}/unlock`,{pin:'1234'});
  // The media server's sign-in, as the restored profile asks.
  const step=async b=>(await api(ctx,'POST',`profiles/${mom.id}/sign-in`,b)).j;
  let st=await step({action:'start'});
  st=await step({action:'connect',address:process.env.MS_URL});
  for(let i=0;st.busy&&i<60;i++){await page.waitForTimeout(500); st=(await api(ctx,'GET',`profiles/${mom.id}/sign-in`)).j}
  if(st.stage==='method') st=await step({action:'choosePassword'});
  st=await step({action:'password',user:process.env.MS_USER,password:process.env.MS_PW});
  for(let i=0;!st.finished&&i<120;i++){await page.waitForTimeout(500); st=(await api(ctx,'GET',`profiles/${mom.id}/sign-in`)).j}
  if(!st.finished){fail('media server sign-in '+JSON.stringify(st)); return}
  ok('Mom signed in to the media server again');
  await page.waitForTimeout(5000);
  const servers=(await api(ctx,'GET',`profiles/${mom.id}/servers`)).j;
  const yt=(servers?.servers||[]).find(s=>s.kind==='youtube');
  if(!yt) fail('no YouTube server '+JSON.stringify(servers)); else if(yt.state!=='needsSignIn') fail('YouTube is '+yt.state); else ok('YouTube: Needs sign-in');
  const chans=(await api(ctx,'GET',`profiles/${mom.id}/youtube/channels`)).j;
  const nums=(chans?.channels||[]).map(c=>c.number).sort();
  if(JSON.stringify(nums)!=='[701,702,703]') fail('channels '+JSON.stringify(nums)); else ok('all 3 YouTube channels kept: 701, 702, 703');
  if(!(chans?.notes||[]).some(n=>n.kind==='signIn')) fail('Watch has no sign-in note'); else ok('Watch says to sign in again');
  await page.goto(B+`/profiles/${mom.id}/servers`); await page.waitForTimeout(4000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
  await shot(page,'servers');
  await page.getByRole('button',{name:'Sign in again'}).last().click(); await page.waitForTimeout(2500);
  const all=await labels(page);
  await shot(page,'sign-in-again');
  if(all.includes('Your own Google client')&&page.getByRole('textbox',{name:'Client ID'})&&await page.getByRole('textbox',{name:'Client secret'}).count())
    ok('Sign in again opens the Client ID and Client secret step');
  else fail('Sign in again shows '+JSON.stringify(all.slice(0,30)));
  console.log(process.exitCode?'DONE with failures':'DONE all passed');
})().catch(e=>{console.log('FAIL',e);process.exitCode=1}).finally(()=>process.exit());
