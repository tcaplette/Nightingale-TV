// Web admin: build a custom channel by drag, keyboard and touch (custom-channels 8.4, 11.7).
// Run from a folder with playwright installed, in the Playwright container on the ntv-offline
// network, against a server signed in to a test Jellyfin holding a collection.
const {chromium}=require('playwright');
const B='http://192.168.77.1:8484', pid=require('fs').readFileSync('pid','utf8');
const api=async(ctx,m,p,b)=>{const r=await ctx.request.fetch(B+'/api/v1/'+p,{method:m,headers:{'X-Nightingale-TV':'1','Content-Type':'application/json'},data:b?JSON.stringify(b):undefined});return {s:r.status(),j:await r.json().catch(()=>null)}};
const cname=process.argv[2]||'';
async function open(opts){
  const ctx=await chromium.launch().then(b=>b.newContext({locale:'en-US',viewport:{width:1280,height:900},...opts}));
  const r=await api(ctx,'POST','session',{name:'admin',password:'web-admin-test-1'}); if(r.s!=200) throw 'login '+r.s;
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  await page.goto(B+`/profiles/${pid}/channels`); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {ctx,page};
}
// Row n of the folder browser, just under the drop box.
const rowY=async(p,n)=>{const b=await p.getByText('Drag a collection or folder here').first().boundingBox();return b.y+b.height+ 28 + 56*n + 24};
const dropX=async p=>(await p.getByText('Drag a collection or folder here').first().boundingBox()).x;
const at=async(p,text,touch)=>{const y=await rowY(p,0),x=(await dropX(p))+150;touch?await p.touchscreen.tap(x,y):await p.mouse.click(x,y)};
const shot=(p,n)=>p.screenshot({path:'shots/'+n+'.png'});
async function lineup(ctx,name){const r=await api(ctx,'GET',`profiles/${pid}/channels`);return r.j.channels.find(c=>c.name==name)}
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  // ---- By mouse, dragging ----
  let {ctx,page}=await open({});
  await page.getByRole('button',{name:'New channel'}).click(); await page.waitForTimeout(1500);
  await shot(page,'1-dialog');
  await page.getByRole('textbox',{name:'Name'}).fill('Dragged');
  await at(page,'Collections');
  await page.waitForTimeout(2000); await shot(page,'2-collections');
  const hb={x:(await dropX(page))+1,y:await rowY(page,1)-8,width:16,height:16};
  const drop=page.getByText('Drag a collection or folder here').first(); const db=await drop.boundingBox(); console.log('drop',db);
  await page.mouse.move(hb.x+hb.width/2,hb.y+hb.height/2); await page.mouse.down();
  await page.mouse.move(hb.x+40,hb.y-30,{steps:6}); await page.mouse.move(db.x+db.width/2,db.y+db.height/2,{steps:12}); await page.waitForTimeout(300); await page.mouse.up();
  await page.waitForTimeout(800); await shot(page,'3-dropped');
  await page.getByRole('button',{name:'Add',exact:true}).click(); await page.waitForTimeout(3000); await shot(page,'4-added');
  const d=await lineup(ctx,'Dragged'); console.log('DRAG',d&&{roots:d.source.roots,n:d.view.playlistLength,auto:d.auto});
  // Guide preview
  await page.goto(B+`/profiles/${pid}/guide`); await page.waitForTimeout(3000); await shot(page,'5-guide');
  const g=await api(ctx,'GET',`profiles/${pid}/guide`); const gr=g.j.channels.find(c=>c.name=='Dragged'); console.log('GUIDE',gr&&gr.airings.length, gr&&gr.airings[0]&&gr.airings[0].title);
  await ctx.browser().close();
  // ---- Keyboard only ----
  ({ctx,page}=await open({}));
  const tabTo=async(name,max=120)=>{for(let i=0;i<max;i++){await page.keyboard.press('Tab');await page.waitForTimeout(40);const a=await page.evaluate(()=>{const e=document.activeElement;return (e&&(e.getAttribute('aria-label')||e.innerText||''))||''});seen.push(a.slice(0,30));if(name.test(a))return a}throw 'no '+name+' in '+JSON.stringify(seen.slice(-40))};const seen=[];
  console.log('tab',await tabTo(/^New channel/)); await page.keyboard.press('Enter'); await page.waitForTimeout(1500);
  console.log('tab',await tabTo(/^Drag to add\nCollections/)); await page.keyboard.press('Enter'); await page.waitForTimeout(1500);
  console.log('tab',await tabTo(/^Add /)); await page.keyboard.press('Enter'); await page.waitForTimeout(500); await shot(page,'6-kb');
  console.log('tab',await tabTo(/^Add$/)); await page.keyboard.press('Enter'); await page.waitForTimeout(3000); await shot(page,'7-kb');
  const k=(await api(ctx,'GET',`profiles/${pid}/channels`)).j.channels.filter(c=>c.view.custom); console.log('KEYBOARD',k.map(c=>[c.name,c.view.playlistLength]));
  await ctx.browser().close();
  // ---- Touch ----
  ({ctx,page}=await open({hasTouch:true,isMobile:true,viewport:{width:412,height:915}}));
  await page.getByRole('button',{name:'New channel'}).tap(); await page.waitForTimeout(1500);
  await page.getByRole('textbox',{name:'Name'}).fill('Touched'); 
  await at(page,'Collections',true); await page.waitForTimeout(1500); await shot(page,'8-touch');
  await page.getByRole('button',{name:/^Add /}).first().tap(); await page.waitForTimeout(500);
  await page.getByRole('button',{name:'Add',exact:true}).tap(); await page.waitForTimeout(3000); await shot(page,'9-touch');
  const t=await lineup(ctx,'Touched'); console.log('TOUCH',t&&[t.view.playlistLength,t.source.roots]);
  await ctx.browser().close();
})().catch(e=>{console.log('FAIL',String(e).slice(0,500));process.exit(1)});
