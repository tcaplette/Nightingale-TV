// Web admin: mark a pool as Bumpers, give a channel's own plan a bumper pool, and reload to
// confirm both stay (bumper-pools 6.4). Run from a folder with playwright installed, in the
// Playwright container on the ntv-offline network, against a server whose admin is "admin" /
// "web-admin-test-1" and whose profile id is in ./pid, signed in to a library with channels.
const {chromium}=require('playwright');
const B='http://192.168.77.1:8484', pid=require('fs').readFileSync('pid','utf8').trim();
const base=`profiles/${pid}`;
let etag=null;
const api=async(ctx,m,p,b)=>{const h={'X-Nightingale-TV':'1','Content-Type':'application/json'};if(m!='GET'&&etag)h['If-Match']=etag;
  const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:h,data:b?JSON.stringify(b):undefined});
  if(r.headers().etag)etag=r.headers().etag;return {s:r.status(),j:await r.json().catch(()=>null)}};
const shot=(p,n)=>p.screenshot({path:'shots/'+n+'.png'});
const fail=m=>{throw new Error(m)};
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:1400}}));
  const r=await api(ctx,'POST','session',{name:'admin',password:'web-admin-test-1'}); if(r.s!=200) fail('login '+r.s);
  let c=await api(ctx,'GET',`${base}/commercials`);
  let pool=c.j.pools.find(p=>p.name=='Station Idents');
  if(!pool){c=await api(ctx,'POST',`${base}/pools`,{name:'Station Idents'}); if(c.s!=200) fail('add pool '+c.s); pool=c.j.pools.find(p=>p.name=='Station Idents')}
  if(pool.kind=='bumpers'){await api(ctx,'GET',`${base}/commercials`);c=await api(ctx,'PUT',`${base}/pools/${pool.id}`,{kind:'commercials'});if(c.s!=200) fail('reset '+c.s)}
  const ch=c.j.channels[0];
  if(ch.plan){await api(ctx,'GET',`${base}/commercials`);c=await api(ctx,'PUT',`${base}/channels/${ch.id}/plan`,{plan:null});if(c.s!=200) fail('reset plan '+c.s)}
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  const open=async()=>{await page.goto(B+`/profiles/${pid}/commercials`);await page.waitForTimeout(3500);
    await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder');p&&p.click()});await page.waitForTimeout(1500)};
  await open(); await shot(page,'1-commercials');
  // Mark it, through the pool's menu.
  const rows=page.getByRole('button',{name:'Pool actions'});
  const n=await rows.count();
  await rows.nth(n-1).click(); await page.waitForTimeout(600); await shot(page,'2-menu');
  await page.getByRole('menuitem',{name:'Set type: Bumpers'}).click(); await page.waitForTimeout(2000); await shot(page,'3-marked');
  c=await api(ctx,'GET',`${base}/commercials`);
  if(c.j.pools.find(p=>p.id==pool.id).kind!='bumpers') fail('not marked');
  console.log('MARKED');
  // A channel's own plan picks it.
  await page.getByRole('button',{name:/Main setting/}).first().click(); await page.waitForTimeout(500);
  await page.getByRole('menuitem',{name:'Custom…'}).last().click(); await page.waitForTimeout(1200); await shot(page,'4-editor');
  // Role dropdowns don't list it; the Bumpers one does.
  await page.mouse.click(480,348); await page.waitForTimeout(500); // A 15 s pre-roll enables its dropdown.
  await page.mouse.click(640,415); await page.waitForTimeout(700); await shot(page,'5-role-dropdown');
  const roleItems=await page.getByRole('menuitem').allInnerTexts().catch(()=>[]); console.log('ROLE MENU',roleItems.length);
  if(!await page.getByRole('menuitem',{name:/All pools/}).count()) fail('the role dropdown did not open');
  if(await page.getByRole('menuitem',{name:/Station Idents/}).count()) fail('a role lists the bumper pool');
  await page.keyboard.press('Escape'); await page.waitForTimeout(500);
  await page.getByRole('button',{name:/All bumper pools/}).click(); await page.waitForTimeout(600); await shot(page,'6-bumper-dropdown');
  await page.getByRole('menuitem',{name:/Station Idents/}).click(); await page.waitForTimeout(600); await shot(page,'7-picked');
  await page.getByRole('button',{name:'Save'}).click(); await page.waitForTimeout(2000);
  // Reload: both stay, on the server and on the page.
  await open(); await shot(page,'8-reloaded');
  c=await api(ctx,'GET',`${base}/commercials`);
  const p=c.j.pools.find(p=>p.id==pool.id), plan=c.j.channels.find(x=>x.id==ch.id).plan;
  console.log('POOL',p.kind,'PLAN',JSON.stringify(plan&&plan.roles.pools));
  if(p.kind!='bumpers') fail('type lost');
  if(!plan||plan.roles.pools.bumpers!=pool.id) fail('plan lost');
  console.log('OK');
  await ctx.browser().close();
})().catch(e=>{console.log('FAIL',String(e).slice(0,500));process.exit(1)});
