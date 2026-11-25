// Web admin, live (docker-youtube 5.3): Add a server → YouTube with your own Google client file and a
// real Google account, 3 channels picked, then the Watch page: YouTube's player plays the channel at its
// scheduled point, the next video starts after one ends, and a hidden tab pauses and catches up. Run from
// a folder with playwright installed, in the Playwright container on a network WITH internet (YouTube
// must load), against the Docker image, with NTV_PROFILE signed in and NTV_ADMIN_PW set. CLIENT_FILE is
// Google's downloaded client JSON (type TVs and Limited Input devices). The script prints "CODE <code>":
// enter it at google.com/device with the test Google account; it waits up to 10 minutes.
const {chromium}=require('playwright');
const fs=require('fs');
const B=process.env.NTV_BASE||'http://127.0.0.1:8484', pid=process.env.NTV_PROFILE, pw=process.env.NTV_ADMIN_PW;
const user=process.env.NTV_ADMIN||'admin', clientFile=process.env.CLIENT_FILE;
const shot=(p,n)=>p.screenshot({path:'shots/live-'+n+'.png'});
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
const ok=m=>console.log('OK',m);
const api=async(ctx,m,p,b)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json'},data:b?JSON.stringify(b):undefined});
  let j=null;try{j=JSON.parse(await r.text())}catch{}return {s:r.status(),j}};
const labels=page=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.innerText||'').trim()));
const ytFrame=page=>page.frames().find(f=>f.url().includes('youtube.com/embed/'));
// The YouTube video element's state, from inside its frame.
const video=async page=>{const f=ytFrame(page); if(!f) return null;
  try{return await f.evaluate(()=>{const v=document.querySelector('video'); const p=document.querySelector('#movie_player');
    return v?{t:v.currentTime,paused:v.paused,d:v.duration,ad:!!(p&&p.classList.contains('ad-showing')),id:(p&&p.getVideoData&&p.getVideoData().video_id)||null}:null})}catch{return null}};
async function setHidden(page,hidden){
  await page.evaluate(h=>{Object.defineProperty(document,'visibilityState',{configurable:true,get:()=>h?'hidden':'visible'});
    Object.defineProperty(document,'hidden',{configurable:true,get:()=>h}); document.dispatchEvent(new Event('visibilitychange'))},hidden);
}
// Waits until the main video (not an ad) plays near what the server says is on now.
async function playsOnSchedule(ctx,page,cid,tag){
  for(let i=0;i<90;i++){
    const v=await video(page);
    const now=(await api(ctx,'GET',`profiles/${pid}/youtube/${cid}/now`)).j;
    if(v&&!v.ad&&!v.paused&&now&&v.id===now.videoId&&Math.abs(v.t-now.offsetSeconds)<8){
      ok(`${tag}: ${v.id} plays at ${v.t.toFixed(0)} s, scheduled ${now.offsetSeconds} s`); return {v,now};
    }
    await page.waitForTimeout(2000);
  }
  const v=await video(page); fail(tag+': not playing on schedule '+JSON.stringify(v)); return null;
}
(async()=>{
  fs.mkdirSync('shots',{recursive:true});
  const ctx=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']}).then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:900}}));
  const r=await api(ctx,'POST','session',{name:user,password:pw}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>fail('page error '+e.message));
  let yt=((await api(ctx,'GET',`profiles/${pid}/servers`)).j.servers||[]).find(s=>s.kind==='youtube');
  if(!yt){
    await page.goto(B+`/profiles/${pid}/servers`,{timeout:60000}); await page.waitForTimeout(3000);
    await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
    await page.getByRole('button',{name:'Add a server'}).click(); await page.waitForTimeout(1500);
    await page.getByRole('button',{name:'YouTube',exact:true}).click(); await page.waitForTimeout(2000);
    const [chooser]=await Promise.all([page.waitForEvent('filechooser'),page.getByRole('button',{name:'Upload JSON file'}).click()]);
    await chooser.setFiles(clientFile); await page.waitForTimeout(1500);
    await page.getByRole('button',{name:'Continue'}).click(); await page.waitForTimeout(4000);
    await shot(page,'code');
    const code=(await labels(page)).find(l=>/^[A-Z0-9]{3,5}-[A-Z0-9]{3,5}(-[A-Z0-9]{3,5})?$/.test(l));
    if(!code){fail('no code '+JSON.stringify((await labels(page)).slice(0,30))); return}
    console.log('CODE '+code);
    for(let i=0;i<300&&!(await labels(page)).includes('YouTube channels');i++) await page.waitForTimeout(2000);
    if(!(await labels(page)).includes('YouTube channels')){fail('no picker after the code'); return}
    ok('signed in with the own client; the picker shows');
    for(const i of [0,1,2]){await page.getByRole('checkbox').nth(i).click(); await page.waitForTimeout(300)}
    await page.getByRole('button',{name:'Done'}).click(); await page.waitForTimeout(4000);
    const done=page.getByRole('button',{name:'Done'}); if(await done.count()){await done.first().click(); await page.waitForTimeout(3000)}
    yt=((await api(ctx,'GET',`profiles/${pid}/servers`)).j.servers||[]).find(s=>s.kind==='youtube');
    if(!yt||yt.youtubeChannels!==3) fail('YouTube server '+JSON.stringify(yt)); else ok('3 YouTube channels added');
  }
  // Videos arrive with the refresh.
  let list=null;
  for(let i=0;i<60;i++){list=(await api(ctx,'GET',`profiles/${pid}/youtube/channels`)).j; if(list.channels.some(c=>c.now)) break; await page.waitForTimeout(5000)}
  const ch=list.channels.find(c=>c.now); if(!ch){fail('no channel has videos '+JSON.stringify(list)); return}
  await page.goto(B+`/profiles/${pid}/watch`); await page.waitForTimeout(4000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()}); await page.waitForTimeout(1500);
  await shot(page,'list');
  await page.getByText(`${ch.number}  ${ch.name}`).first().click(); await page.waitForTimeout(6000);
  const src=ytFrame(page)?.url()||''; if(!src.includes('youtube.com/embed/')) fail('no YouTube embed: '+src); else ok('YouTube\'s embedded player: '+src.split('?')[0]);
  // Choosing the channel is the viewer's click; a click on the picture would be YouTube's pause.
  const first=await playsOnSchedule(ctx,page,ch.id,'join');
  await shot(page,'playing');
  if(first){
    // Near the end: the next scheduled video follows.
    const f=ytFrame(page); await f.evaluate(()=>{const v=document.querySelector('video'); v.currentTime=v.duration-3});
    let next=null;
    for(let i=0;i<40;i++){await page.waitForTimeout(2000); const v=await video(page); if(v&&v.id&&v.id!==first.v.id&&!v.ad&&!v.paused){next=v;break}}
    if(next) ok(`after ${first.v.id} ended, ${next.id} plays`); else fail('no next video after the end '+JSON.stringify(await video(page)));
  }
  // Hidden tab: paused; shown: on schedule again.
  await setHidden(page,true); await page.waitForTimeout(3000);
  const hidden=await video(page);
  if(!hidden||!hidden.paused) fail('still playing while hidden '+JSON.stringify(hidden)); else ok('paused while the tab is hidden');
  await page.waitForTimeout(20000);
  await setHidden(page,false);
  await playsOnSchedule(ctx,page,ch.id,'shown again');
  await shot(page,'shown');
  // Esc from the page (keys inside YouTube's frame are YouTube's).
  await page.mouse.click(900,25); await page.keyboard.press('Escape'); await page.waitForTimeout(2000);
  if(ytFrame(page)) fail('the player stayed after Esc'); else ok('Esc: back to the list, player gone');
  console.log(process.exitCode?'DONE with failures':'DONE all passed');
})().catch(e=>{console.log('FAIL',e);process.exitCode=1}).finally(()=>process.exit());
