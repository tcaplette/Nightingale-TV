// Web admin: the folder browser lists movies in their folders, and a movies-only folder opens
// (jellyfin-folder-browse 5.5). A new channel gets a single movie by mouse, a folder by keyboard
// and another movie by touch, and plays all of them. Run from a folder with playwright
// installed, in the Playwright container on the ntv-offline network, against a server signed in
// to the test-data.md Jellyfin (tool/idle_budget/seed), with NTV_ADMIN_PW and NTV_PROFILE set.
const {chromium}=require('playwright');
const B='http://192.168.77.1:8484', pid=process.env.NTV_PROFILE, pw=process.env.NTV_ADMIN_PW;
const api=async(ctx,m,p,b)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json'},data:b?JSON.stringify(b):undefined});return {s:r.status(),j:await r.json().catch(()=>null)}};
const shot=(p,n)=>p.screenshot({path:'shots/'+n+'.png'});
const name='Folder Picks '+Date.now();
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
async function open(opts,path='channels'){
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:900},...opts}));
  console.log('launched');
  const r=await api(ctx,'POST','session',{name:'admin',password:pw}); if(r.s!=200) throw 'login '+r.s;
  console.log('signed in');
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  await page.goto(B+`/profiles/${pid}/${path}`,{timeout:60000}); await page.waitForTimeout(3000);
  console.log('page open');
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {ctx,page};
}
// A browser row ("Drag to add\n<name>\n<detail>…") whose name and detail match re: the
// smallest such element, clicked or tapped in its middle (its name, not its Add button).
async function rowAt(page,re){
  const r=await page.evaluate(src=>{const m=new RegExp(src);let best=null;
    for(const e of document.querySelectorAll('flt-semantics')){const t=(e.getAttribute('aria-label')||e.innerText||'').replace(/^Drag to add\n/,'');
      if(!m.test(t))continue;const b=e.getBoundingClientRect();if(b.width&&(!best||b.width*b.height<best.width*best.height))best={x:b.x,y:b.y,width:b.width,height:b.height}}
    return best},re.source);
  if(!r) throw 'no row '+re;
  return {x:r.x+r.width*0.4,y:r.y+r.height/2};
}
const row=(page,re)=>({click:async()=>{const p=await rowAt(page,re);await page.mouse.click(p.x,p.y)},
  tap:async()=>{const p=await rowAt(page,re);await page.touchscreen.tap(p.x,p.y)},
  count:async()=>{try{await rowAt(page,re);return 1}catch{return 0}}});
// The semantics labels matching re, to see how rows are named.
const labels=(page,re)=>page.evaluate(src=>{const r=new RegExp(src);return [...document.querySelectorAll('flt-semantics')]
  .map(e=>e.getAttribute('aria-label')||e.innerText||'').filter(t=>r.test(t)).slice(0,12)},re.source);
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  let {ctx,page}=await open({hasTouch:true});
  await page.getByRole('button',{name:'New channel'}).click(); await page.waitForTimeout(1500);
  await page.getByRole('textbox',{name:'Name'}).fill(name);
  await shot(page,'f0-dialog');
  // Mouse: open Movies, then the movies-only folder, and add Die Hard from its name.
  await row(page,/^Movies(\n|$)/).click(); await page.waitForTimeout(4000); await shot(page,'f1-movies');
  const five=row(page,/5 inside/); if(!(await five.count())) fail('no "5 inside" folder');
  await five.click(); await page.waitForTimeout(1000); await shot(page,'f2-five');
  for(const t of ['Die Hard','Ghostbusters II','Inglourious Basterds']) if(!(await row(page,new RegExp('^'+t+'\nMovie')).count())) fail('missing '+t);
  await row(page,/^Die Hard/).click(); await page.waitForTimeout(800);
  // Touch: Ghostbusters II.
  await row(page,/^Ghostbusters II/).tap(); await page.waitForTimeout(800); await shot(page,'f3-added');
  // Back up to the library, then the keyboard: open the big folder, Tab to the trilogy's Add.
  await row(page,/› movies$/).click(); await page.waitForTimeout(1000);
  const seen=[];
  const tabTo=async(re)=>{for(let i=0;i<200;i++){await page.keyboard.press('Tab');await page.waitForTimeout(30);
    const a=await page.evaluate(()=>{const e=document.activeElement;return (e&&(e.getAttribute('aria-label')||e.innerText||''))||''});seen.push(a.slice(0,40));
    if(re.test(a))return a}
    fail('no '+re+' in '+JSON.stringify(seen.slice(-30)));return null};
  if(await tabTo(/^Drag to add\nmovies\n32 inside/)){await page.keyboard.press('Enter');await page.waitForTimeout(1500)}
  if(await tabTo(/^Add Back To The Future/)) await page.keyboard.press('Enter');
  await page.waitForTimeout(800); await shot(page,'f4-keyboard');
  await page.getByRole('button',{name:'Add',exact:true}).click(); await page.waitForTimeout(5000); await shot(page,'f5-created');
  const ch=(await api(ctx,'GET',`profiles/${pid}/channels`)).j.channels.find(c=>c.name==name);
  console.log('CHANNEL',ch&&{roots:ch.source.roots.map(r=>r.label),n:ch.view.playlistLength});
  if(!ch||ch.view.playlistLength!=5) fail('expected 5 programs (2 movies and a folder of 3)');
  await ctx.browser().close();
  // The pool picker lists the videos too.
  ({ctx,page}=await open({},'commercials'));
  await shot(page,'f6-commercials');
  // A pool to pick for (removed again below).
  await page.getByRole('button',{name:'New pool'}).click(); await page.waitForTimeout(2000);
  const menu=page.getByRole('button',{name:'Pool actions'}).first();
  if(await menu.count()){
    await menu.click(); await page.waitForTimeout(800); await shot(page,'f6-menu');
    await page.getByRole('menuitem',{name:'Choose folders…'}).click(); await page.waitForTimeout(1500);
    // Music Videos' storage folder holds only videos: it opens and lists them.
    await row(page,/^Music Videos(\n|$)/).click(); await page.waitForTimeout(4000); await shot(page,'f7-pool');
    await row(page,/\n10 inside/).click(); await page.waitForTimeout(1000);
    await shot(page,'f8-pool-videos');
    console.log('POOL',JSON.stringify(await labels(page,/\nVideo$/)));
    if(!(await labels(page,/\nVideo$/)).length) fail('the pool picker lists no videos');
    await page.getByRole('button',{name:'Cancel'}).click(); await page.waitForTimeout(500);
    await menu.click(); await page.waitForTimeout(500); await page.getByRole('menuitem',{name:'Delete'}).click(); await page.waitForTimeout(500);
    await page.getByRole('button',{name:'Delete'}).click(); await page.waitForTimeout(1000);
  } else fail('no pool to pick for');
  await ctx.browser().close();
})().catch(e=>{console.log('ERROR',e);process.exit(1)});
