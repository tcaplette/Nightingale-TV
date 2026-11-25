// Web admin: the Servers page names what can be added, and Add a server shows the address field,
// Connect, Sign in with Plex and SMB share in that order, with no chips (server-kinds-wording 3.5).
// SMB share is opened by keyboard on a computer and by touch on a phone. Run from a folder with playwright installed, in the Playwright container on the
// ntv-offline network, against a server whose profile is NTV_PROFILE, with NTV_ADMIN_PW set.
const {chromium}=require('playwright');
const B=process.env.NTV_BASE||'http://192.168.77.1:8484', pid=process.env.NTV_PROFILE, pw=process.env.NTV_ADMIN_PW;
const shot=(p,n)=>p.screenshot({path:'shots/sk-'+n+'.png'});
const fail=m=>{console.log('FAIL',m);process.exitCode=1};
const ok=m=>console.log('OK',m);
const help="You can add Jellyfin, Emby, Plex, and SMB shares (a NAS, or a computer's shared folder).";
async function open(opts){
  const browser=await chromium.launch();
  const ctx=await browser.newContext({locale:'en-US',...opts});
  const r=await ctx.request.fetch(B+'/api/v1/session',{method:'POST',headers:{'X-Nightingale-TV':'1','Content-Type':'application/json'},data:JSON.stringify({name:'admin',password:pw})});
  if(r.status()!=200) throw 'login '+r.status();
  const page=await ctx.newPage(); page.on('pageerror',e=>fail('page error '+e.message));
  await page.goto(B+`/profiles/${pid}/servers`,{timeout:60000}); await page.waitForTimeout(3000);
  await page.evaluate(()=>{const p=document.querySelector('flt-semantics-placeholder'); p&&p.click()});
  await page.waitForTimeout(1500);
  return {browser,page};
}
const labels=page=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.innerText||'').trim()));
// The focused element, inside the flutter-view's shadow root where the text field's input lives.
const active=page=>page.evaluate(()=>{let e=document.activeElement;while(e&&e.shadowRoot&&e.shadowRoot.activeElement)e=e.shadowRoot.activeElement;
  return e?(e.tagName+' '+(e.getAttribute('aria-label')||e.innerText||'')).trim():''});
async function addServer(page,tag){
  if(!(await page.evaluate(h=>[...document.querySelectorAll('flt-semantics')].some(e=>((e.getAttribute('aria-label')||'')+(e.textContent||'')).includes(h)),help))) fail(tag+': no line naming the kinds on Servers'); else ok(tag+': Servers names the kinds');
  await shot(page,tag+'-servers');
  await page.getByRole('button',{name:'Add a server'}).click(); await page.waitForTimeout(2500);
  if(await page.getByRole('radio').count()) fail(tag+': chips are still there');
  const boxes=[];
  for(const [role,name] of [['textbox','Server address'],['button','Connect'],['button','Sign in with Plex'],['button','SMB share']]){
    // The field's name also carries its example address.
    const l=page.getByRole(role,{name,exact:role!=='textbox'});
    if(await l.count()!==1){fail(tag+': no '+name);continue}
    boxes.push([name,(await l.boundingBox()).y]);
  }
  if(boxes.some((b,i)=>i&&b[1]<=boxes[i-1][1])) fail(tag+': order is '+boxes.map(b=>b[0]).join(', ')); else ok(tag+': '+boxes.map(b=>b[0]).join(' > '));
  await shot(page,tag+'-add');
}
(async()=>{
  require('fs').mkdirSync('shots',{recursive:true});
  // ---- Keyboard, on a computer ----
  let {browser,page}=await open({viewport:{width:1280,height:900}});
  await addServer(page,'desk');
  // Tab from the address field to SMB share; Enter opens the share step.
  let f='';
  for(let i=0;i<6&&!(f=await active(page)).includes('SMB share');i++){await page.keyboard.press('Tab'); await page.waitForTimeout(300)}
  if(!f.includes('SMB share')) fail('Tab never reached SMB share: '+f);
  await page.keyboard.press('Enter'); await page.waitForTimeout(2500);
  if(!(await labels(page)).includes('Add a share')) fail('keyboard: no share step'); else ok('keyboard: SMB share opens the share step');
  await shot(page,'desk-share');
  await browser.close();
  // ---- Touch, on the narrowest phone ----
  ({browser,page}=await open({viewport:{width:360,height:740},hasTouch:true,isMobile:true,deviceScaleFactor:2}));
  await addServer(page,'phone');
  await page.getByRole('button',{name:'SMB share',exact:true}).tap(); await page.waitForTimeout(2500);
  if(!(await labels(page)).includes('Add a share')) fail('touch: no share step'); else ok('touch: SMB share opens the share step');
  await shot(page,'phone-share');
  await browser.close();
  console.log(process.exitCode?'DONE with failures':'DONE all passed');
})().catch(e=>{console.log('FAIL',e);process.exit(1)});
