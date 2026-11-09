// The phone remote in German, following a TV change to French with no new
// pairing, and the transfer page in Italian (app-languages 8.8). Run from a
// folder with playwright installed, in the Playwright container with host
// networking, beside integration_test/languages_remote_live_test.dart; $REMOTE_DIR is shared.
const {chromium}=require('playwright'), fs=require('fs');
const D=process.env.REMOTE_DIR;
const info=()=>JSON.parse(fs.readFileSync(D+'/info.json','utf8'));
const send=(n,c)=>fs.writeFileSync(D+'/command',n+' '+c);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const until=async(f,what)=>{for(let i=0;i<200;i++){try{const v=await f();if(v)return v}catch(e){}await sleep(150)}throw 'timed out: '+what};
(async()=>{
  await until(()=>fs.existsSync(D+'/info.json')&&info().code,'the app');
  const {port,code}=info();
  const b=await chromium.launch();
  const ctx=await b.newContext({locale:'en-US',viewport:{width:412,height:915}});
  const page=await ctx.newPage(); page.on('pageerror',e=>console.log('PAGEERR',e.message));
  await page.goto(`http://127.0.0.1:${port}/`);
  if(await page.getAttribute('html','lang')!=='de') throw 'lang is not de';
  await page.screenshot({path:D+'/remote-de-pair.png'});
  if(!(await page.getByText('Mit dem Fernseher koppeln').isVisible())) throw 'pairing page not German';
  await page.fill('#code',code); await page.click('#pairform button');
  await until(()=>page.isVisible('#remote'),'paired');
  for(const t of ['TV-Guide','Zurück','Menü']) if(!(await page.locator('#remote').getByText(t,{exact:true}).first().isVisible())) throw 'no '+t;
  await page.screenshot({path:D+'/remote-de.png'});
  console.log('German OK');
  send(1,'lang fr');
  await until(async()=>await page.getAttribute('html','lang')==='fr','page reloaded in French');
  await until(()=>page.isVisible('#remote'),'still paired');
  if(await page.isVisible('#pair')) throw 'asked to pair again';
  for(const t of ['Guide','Retour']) if(!(await page.locator('#remote').getByText(t,{exact:true}).first().isVisible())) throw 'no '+t;
  await page.screenshot({path:D+'/remote-fr.png'});
  console.log('follows the TV OK');
  send(2,'lang it');
  await until(()=>info().lang==='it','Italian');
  send(3,'transfer');
  const url=await until(()=>info().transfer,'transfer url');
  const p2=await ctx.newPage(); await p2.goto(url);
  if(await p2.getAttribute('html','lang')!=='it') throw 'transfer lang';
  if(!(await p2.getByText('Scarica backup').first().isVisible())) throw 'transfer not Italian';
  await p2.screenshot({path:D+'/transfer-it.png'});
  console.log('transfer OK');
  send(4,'done'); console.log('PASS'); process.exit(0);
})().catch(e=>{console.log('FAIL',e);try{send(9,'done')}catch(_){ }process.exit(1)});
