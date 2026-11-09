// Web admin: build "90s Comedy TV" from the Comedy and 90s chips (genre-decade-channels 6.4).
// Run from a folder with playwright installed, in the Playwright container on the ntv-offline
// network, against a server whose profile (id in ./pid) is signed in to a library with 90s comedies.
const {chromium}=require('playwright');
const B='http://192.168.77.1:8484', pid=require('fs').readFileSync('pid','utf8').trim();
const api=async(ctx,m,p,b)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json'},data:b?JSON.stringify(b):undefined});return {s:r.status(),j:await r.json().catch(()=>null)}};
const shot=(p,n)=>p.screenshot({path:'shots/gd-'+n+'.png'});
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:1000}}));
  const r=await api(ctx,'POST','session',{name:'admin',password:process.env.ADMIN_PW}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  await page.goto(B+`/profiles/${pid}/channels`); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  await page.getByRole('button',{name:'New channel'}).click(); await page.waitForTimeout(2000);
  await page.getByRole('textbox',{name:'Name'}).fill('90s Comedy TV');
  const chip=async name=>{const c=page.getByRole('checkbox',{name,exact:true}).or(page.getByRole('button',{name,exact:true})).first(); await c.scrollIntoViewIfNeeded(); await c.click(); await page.waitForTimeout(600);};
  await chip('Comedy'); await chip('90s');
  await shot(page,'1-picked');
  const shows=page.getByRole('checkbox',{name:'Include shows',exact:true}).or(page.getByRole('button',{name:'Include shows',exact:true})).first();
  console.log('SHOWS', await shows.getAttribute('aria-checked'), await shows.getAttribute('aria-selected'));
  await page.getByRole('button',{name:'Add',exact:true}).click(); await page.waitForTimeout(3000); await shot(page,'2-added');
  const c=(await api(ctx,'GET',`profiles/${pid}/channels`)).j.channels.find(c=>c.name=='90s Comedy TV');
  console.log('CHANNEL', c&&JSON.stringify({id:c.id,source:c.source,n:c.view.playlistLength}));
  await ctx.browser().close();
})().catch(e=>{console.log('FAIL',String(e).slice(0,600));process.exit(1)});
