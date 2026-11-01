// Web admin: set a channel's CRT effect to Arcade and back to Main setting, set the main shape, and
// reload to confirm (retro-presentation 7.2). Run as bumper_pools.js is: from a folder with playwright
// installed, in the Playwright container on the ntv-offline network, against a server whose admin is
// "admin" / "web-admin-test-1" and whose profile id is in ./pid.
const {chromium}=require('playwright');
const B='http://192.168.77.1:8484', pid=require('fs').readFileSync('pid','utf8').trim();
const H={'X-Nightingale-TV':'1'};
(async()=>{
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:1600}}));
  const r=await ctx.request.post(B+'/api/v1/session',{headers:H,data:{name:'admin',password:'web-admin-test-1'}});
  if(!r.ok()) throw 'login '+r.status();
  const api=async p=>(await ctx.request.get(B+'/api/v1/'+p)).json();
  const list=await api(`profiles/${pid}/channels`), ch=list.channels.find(c=>c.number==3)||list.channels[0];
  const path=`profiles/${pid}/channels/${encodeURIComponent(ch.id)}`;
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  const open=async()=>{await page.goto(`${B}/${path}`);await page.waitForTimeout(3000);
    await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder');p&&p.click()});await page.waitForTimeout(1500);};
  const scroll=async()=>{await page.mouse.move(640,800);for(let i=0;i<40&&!(await page.getByRole('button',{name:/CRT effect/}).count());i++){await page.mouse.wheel(0,400);await page.waitForTimeout(150);}};
  const choose=async(text)=>{await page.getByRole('button',{name:/CRT effect/}).first().click();await page.waitForTimeout(600);
    await page.getByRole('menuitem',{name:text}).or(page.getByRole('option',{name:text})).or(page.getByRole('button',{name:text})).last().click();await page.waitForTimeout(1200);};
  await open(); await scroll(); await page.screenshot({path:'shots_retro_1.png'});
  await choose('Arcade');
  let now=await api(path); console.log('after Arcade: retro',JSON.stringify(now.retro),'view crt',now.view.retro.crt);
  if(now.retro?.crt!=='arcade') throw 'not saved';
  await open(); await scroll(); await page.screenshot({path:'shots_retro_2.png'});
  if(!(await page.getByRole('button',{name:/Arcade/}).count())) throw 'page does not show Arcade';
  await choose(/Main setting/);
  now=await api(path); console.log('after Main: retro',JSON.stringify(now.retro||{}));
  if(now.retro?.crt) throw 'still has its own';
  console.log('PASS'); process.exit(0);
})().catch(e=>{console.log('FAIL',e);process.exit(1)});
