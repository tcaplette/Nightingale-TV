// Web admin: make a late-night block by keyboard, check the preview's count and the
// empty-result message, and that a kid profile gets no shortcut or minimum rating
// (late-night-drift 5.5). Run from a folder with playwright installed, in the Playwright
// container on the ntv-offline network, against a server whose admin is "admin" /
// "web-admin-test-1", with the grown-up profile's id in ./pid and a signed-in kid
// profile's id in ./kidpid.
const {chromium}=require('playwright');
const fs=require('fs');
const B='http://192.168.77.1:8484', pid=fs.readFileSync('pid','utf8'), kid=fs.readFileSync('kidpid','utf8');
const api=async(ctx,m,p,b)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json'},data:b?JSON.stringify(b):undefined});return {s:r.status(),j:await r.json().catch(()=>null)}};
async function open(path){
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:900}}));
  const r=await api(ctx,'POST','session',{name:'admin',password:'web-admin-test-1'}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  await page.goto(B+path); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {ctx,page};
}
const shot=(p,n)=>p.screenshot({path:'shots/late-'+n+'.png'});
const text=p=>p.evaluate(()=>document.body.innerText);
(async()=>{
  fs.mkdirSync('shots',{recursive:true});
  // ---- Keyboard only: the shortcut, the preview's count, saving ----
  let {ctx,page}=await open(`/profiles/${pid}/blocks`);
  const seen=[];
  const tabTo=async(name,max=150)=>{for(let i=0;i<max;i++){await page.keyboard.press('Tab');await page.waitForTimeout(40);const a=await page.evaluate(()=>{const e=document.activeElement;return (e&&(e.getAttribute('aria-label')||e.innerText||''))||''});seen.push(a.slice(0,30));if(name.test(a))return a}throw 'no '+name+' in '+JSON.stringify(seen.slice(-40))};
  console.log('tab',await tabTo(/New late-night block/)); await page.keyboard.press('Enter'); await page.waitForTimeout(4000);
  await shot(page,'1-editor');
  const t1=await text(page);
  console.log('EDITOR', /Late Night/.test(t1), (t1.match(/\d+ programs in its playlist\./)||['no count'])[0], /TV-MA \/ R and up/.test(t1));
  console.log('tab',await tabTo(/^Save/)); await page.keyboard.press('Enter'); await page.waitForTimeout(3000);
  await shot(page,'2-saved');
  const saved=(await api(ctx,'GET',`profiles/${pid}/blocks`)).j.blocks.find(b=>b.title=='Late Night');
  console.log('SAVED', saved&&{days:saved.days,start:saved.start,end:saved.end,floor:saved.source.ratingFloor,n:saved.view.playlistLength,describe:saved.view.describe});
  // ---- The empty-result message: NC-17 and up, by keyboard ----
  await page.goto(B+`/profiles/${pid}/blocks/late-night`); await page.waitForTimeout(4000);
  console.log('tab',await tabTo(/Minimum rating/)); await page.keyboard.press('Enter'); await page.waitForTimeout(800);
  for(let i=0;i<4;i++){await page.keyboard.press('ArrowDown');await page.waitForTimeout(120)}
  await page.keyboard.press('Enter'); await page.waitForTimeout(2500);
  await shot(page,'3-nc17');
  const t3=await text(page);
  console.log('EMPTY', (t3.match(/Nothing in this mix is rated [^.]+\. Choose a lower rating or other shows\./)||['no message'])[0], (t3.match(/\d+ programs in its playlist\./)||['no count'])[0]);
  await ctx.browser().close();
  // ---- Kid profile: no shortcut, no minimum rating ----
  ({ctx,page}=await open(`/profiles/${kid}/blocks`));
  await shot(page,'4-kid-list');
  const t4=await text(page); const kidBlocks=(await api(ctx,'GET',`profiles/${kid}/blocks`)).j;
  console.log('KID LIST', 'shortcut shown:', /New late-night block/.test(t4), 'kidProfile:', kidBlocks.kidProfile);
  await page.goto(B+`/profiles/${kid}/blocks/new`); await page.waitForTimeout(4000);
  await shot(page,'5-kid-editor');
  console.log('KID EDITOR', 'minimum shown:', /Minimum rating/.test(await text(page)), 'mix shown:', /A mix/.test(await text(page)));
  await ctx.browser().close();
})().catch(e=>{console.log('FAIL',e);process.exit(1)});
