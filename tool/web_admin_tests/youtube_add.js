// Web admin: Add a server → YouTube on the server (docker-youtube 5.2), against the fake Google
// (tool/fake_google_server.dart, which approves every code at once): the client step (Continue only
// with both fields; Upload JSON file fills them), the code step, the picker and the colour, worked
// with the keyboard on a computer, then a mouse, then touch on a phone. The YouTube server is removed
// after each round. Run from a folder with playwright installed, in the Playwright container on the
// ntv-offline network, against a server (Linux bundle --server built with
// --dart-define=NTV_GOOGLE_FAKE=http://127.0.0.1:8765) whose profile NTV_PROFILE is signed in, with
// NTV_ADMIN_PW set. CLIENT_FILE: a Google client JSON for "own-client" (written here if unset).
const {chromium}=require('playwright');
const fs=require('fs');
const B=process.env.NTV_BASE||'http://192.168.77.1:8484', pid=process.env.NTV_PROFILE, pw=process.env.NTV_ADMIN_PW;
const user=process.env.NTV_ADMIN||'admin';
const clientFile=process.env.CLIENT_FILE||'own-client.json';
if(!process.env.CLIENT_FILE) fs.writeFileSync(clientFile,JSON.stringify({installed:{client_id:'own-client',client_secret:'own-client-secret'}}));
const shot=(p,n)=>p.screenshot({path:'shots/yt-'+n+'.png'});
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
const ok=m=>console.log('OK',m);
const api=async(ctx,m,p,b,etag)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json',...(etag?{'If-Match':etag}:{})},data:b?JSON.stringify(b):undefined});
  let j=null;try{j=JSON.parse(await r.text())}catch{}return {s:r.status(),j}};
async function open(opts,path){
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',...opts}));
  const r=await api(ctx,'POST','session',{name:user,password:pw}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>fail('page error '+e.message));
  await page.goto(B+`/profiles/${pid}/${path}`,{timeout:60000}); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {ctx,page};
}
const labels=page=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.innerText||'').trim()));
const youTubeOf=async ctx=>((await api(ctx,'GET',`profiles/${pid}/servers`)).j.servers||[]).find(s=>s.kind==='youtube');
async function remove(ctx){
  const yt=await youTubeOf(ctx); if(!yt) return;
  const rev=(await ctx.request.fetch(B+`/api/v1/profiles/${pid}/logo`)).headers()['etag'];
  const del=await api(ctx,'DELETE',`profiles/${pid}/servers/${yt.key}`,null,rev);
  if(del.s!==200&&del.s!==204) fail('remove '+del.s);
}
const enabled=async l=>!(await l.getAttribute('aria-disabled'))&&!(await l.isDisabled().catch(()=>false));

// One round: [how] is 'keyboard', 'mouse' or 'touch'.
async function round(how,opts){
  const {ctx,page}=await open(opts,'servers');
  await remove(ctx);
  const press=async l=>{
    if(how==='touch') return l.tap();
    if(how==='mouse') return l.click();
    await l.focus(); await page.keyboard.press('Enter');
  };
  await press(page.getByRole('button',{name:'Add a server'})); await page.waitForTimeout(1500);
  await press(page.getByRole('button',{name:'YouTube',exact:true})); await page.waitForTimeout(2000);
  let all=await labels(page);
  if(!all.includes('Your own Google client')) {fail(how+': no client step '+JSON.stringify(all.slice(0,30))); return ctx.browser().close()}
  for(const s of ['Turn on YouTube Data API v3.','Create an OAuth client of the type TVs and Limited Input devices.'])
    if(!all.some(l=>l===s)) fail(how+': step missing: '+s);
  if(!all.some(l=>l.includes('coffeehauslabs.com/ntv/youtube-client'))) fail(how+': no guide link');
  const cont=page.getByRole('button',{name:'Continue'});
  if(await enabled(cont)) fail(how+': Continue enabled with empty fields'); else ok(how+': Continue waits for both fields');
  if(how==='mouse'){
    // Upload JSON file fills both fields.
    const [chooser]=await Promise.all([page.waitForEvent('filechooser'),page.getByRole('button',{name:'Upload JSON file'}).click()]);
    await chooser.setFiles(clientFile); await page.waitForTimeout(1500);
  } else {
    // A text field is focused (keyboard) or tapped, never sent Enter: Enter there moves on.
    const field=async name=>{const l=page.getByRole('textbox',{name}); if(how==='touch') await l.tap(); else await l.focus(); await page.waitForTimeout(400)};
    await field('Client ID'); await page.keyboard.type('own-client',{delay:80});
    if(how==='keyboard') await page.keyboard.press('Tab'); else await field('Client secret');
    await page.waitForTimeout(400);
    await page.keyboard.type('own-client-secret',{delay:80});
  }
  await page.waitForTimeout(800);
  if(!(await enabled(cont))) fail(how+': Continue still disabled'); else ok(how+(how==='mouse'?': the uploaded file filled both fields':': both fields typed'));
  await shot(page,how+'-client');
  await press(cont); await page.waitForTimeout(1500);
  await shot(page,how+'-code');
  // The fake approves at once: the code step may already have given way to the picker.
  for(let i=0;i<20&&!(await labels(page)).includes('YouTube channels');i++) await page.waitForTimeout(1000);
  all=await labels(page);
  if(!all.includes('YouTube channels')) {fail(how+': no picker '+JSON.stringify(all.slice(0,30))); return ctx.browser().close()}
  ok(how+': the code step led to the picker');
  const boxes=page.getByRole('checkbox');
  const n=await boxes.count();
  if(n<3) fail(how+': only '+n+' subscriptions');
  // Search narrows the list.
  const search=page.getByRole('textbox',{name:'Search your subscriptions'});
  if(how==='touch') await search.tap(); else await search.focus();
  await page.waitForTimeout(400);
  await page.keyboard.type('Blender',{delay:80}); await page.waitForTimeout(800);
  if(await boxes.count()!==1) fail(how+': search shows '+(await boxes.count())); else ok(how+': search narrows the list');
  for(let i=0;i<7;i++) await page.keyboard.press('Backspace');
  await page.waitForTimeout(800);
  // Pick the first two.
  for(const i of [0,1]){
    const b=page.getByRole('checkbox').nth(i);
    if(how==='keyboard'){await b.focus(); await page.keyboard.press('Space')} else await press(b);
    await page.waitForTimeout(300);
  }
  await press(page.getByRole('button',{name:'Done'})); await page.waitForTimeout(3000);
  await shot(page,how+'-colour');
  all=await labels(page);
  if(!all.some(l=>l.startsWith('Guide colour'))) fail(how+': no colour step');
  else {
    const wine=page.getByRole('radio',{name:'Wine'});
    if(!(await wine.count())||!(await wine.first().isChecked())) fail(how+': wine is not the suggestion'); else ok(how+': the colour starts at wine');
    const pick=page.getByRole('radio',{name:'Olive'});
    await pick.scrollIntoViewIfNeeded();
    if(how==='keyboard'){await pick.focus(); await page.keyboard.press('Space')} else await press(pick);
    await page.waitForTimeout(500);
    const done=page.getByRole('button',{name:'Done'}); await done.scrollIntoViewIfNeeded(); await press(done);
    await page.waitForTimeout(3000);
  }
  const yt=await youTubeOf(ctx);
  if(!yt) fail(how+': no YouTube server');
  else {
    if(yt.youtubeChannels!==2) fail(how+': '+yt.youtubeChannels+' channels'); else ok(how+': YouTube added with 2 channels');
    const color=((await api(ctx,'GET',`profiles/${pid}/colors`)).j.sources||[]).find(s=>s.name===yt.name)?.color;
    if(color!=='olive') fail(how+': colour '+color); else ok(how+': olive saved');
  }
  await shot(page,how+'-done');
  await remove(ctx);
  await ctx.browser().close();
}

(async()=>{
  fs.mkdirSync('shots',{recursive:true});
  await round('keyboard',{viewport:{width:1280,height:900}});
  await round('mouse',{viewport:{width:1280,height:900}});
  await round('touch',{viewport:{width:360,height:740},hasTouch:true,isMobile:true,deviceScaleFactor:2});
  console.log(process.exitCode?'DONE with failures':'DONE all passed');
})().catch(e=>{console.log('FAIL',e);process.exitCode=1}).finally(()=>process.exit());
