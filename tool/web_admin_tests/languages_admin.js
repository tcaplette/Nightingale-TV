// Web admin languages (app-languages 8.7): the default from the browser, the
// picker kept after a reload, a translated server error, and the profile
// Language field. Run from a folder with playwright installed against a server
// whose admin is "admin" / "web-admin-test-1" at $B. Needs a shared SHOTS dir.
const {chromium}=require('playwright');
const B=process.env.B||'http://127.0.0.1:8484', S=process.env.SHOTS||'.';
const H={'X-Nightingale-TV':'1'};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const ready=async p=>{await sleep(3500);await p.evaluate(()=>{const e=document.querySelector('flt-semantics-placeholder');e&&e.click()});await sleep(800)};
const words={de:'Anmelden',fr:'Se connecter',es:'Iniciar sesión',pt:'Entrar',it:'Accedi',en:'Sign in'};
const errors={de:'Falscher Benutzername oder falsches Passwort.',fr:"Nom d'utilisateur ou mot de passe incorrect.",es:'Usuario o contraseña incorrectos.',pt:'Usuário ou senha incorretos.',it:'Nome utente o password errati.',en:'Wrong user name or password.'};
(async()=>{
  const b=await chromium.launch();
  for(const [lang,locale] of [['en','en-US'],['de','de-DE'],['fr','fr-FR'],['es','es-ES'],['pt','pt-BR'],['it','it-IT']]){
    if(lang==='pt') await sleep(62000); // Five wrong passwords a minute lock the sign-in.
    const ctx=await b.newContext({locale,viewport:{width:1280,height:900}});
    const p=await ctx.newPage(); p.on('pageerror',e=>console.log('PAGEERR',e.message));
    await p.goto(B+'/'); await ready(p);
    if(await p.getAttribute('html','lang')!==lang) throw `${locale}: html lang ${await p.getAttribute('html','lang')}`;
    if(!(await p.getByRole('button',{name:words[lang]}).count())) throw `${locale}: no ${words[lang]}`;
    // A wrong password's message, from the server, in this language.
    const r=await ctx.request.post(B+'/api/v1/session',{headers:{...H,'Accept-Language':lang},data:{name:'admin',password:'nope-nope-nope'}});
    const j=await r.json();
    if(j.error!==errors[lang]) throw `${locale}: error "${j.error}"`;
    await p.screenshot({path:`${S}/admin-${lang}.png`});
    console.log(locale,'OK');
    await ctx.close();
  }
  // Picks, keeps after a reload, and leaves every profile alone.
  const ctx=await b.newContext({locale:'en-US',viewport:{width:1280,height:1000}});
  const p=await ctx.newPage(); p.on('pageerror',e=>console.log('PAGEERR',e.message));
  await p.goto(B+'/'); await ready(p);
  const login=await ctx.request.post(B+'/api/v1/session',{headers:H,data:{name:'admin',password:'web-admin-test-1'}});
  if(!login.ok()) throw 'login '+login.status();
  const before=await (await ctx.request.get(B+'/api/v1/profiles')).json();
  await p.goto(B+'/profiles'); await ready(p);
  await p.getByRole('button',{name:'Language'}).first().click(); await sleep(700);
  await p.getByRole('menuitem',{name:'Deutsch'}).click(); await sleep(1200);
  if(await p.getAttribute('html','lang')!=='de') throw 'picker did not change the page';
  await p.reload(); await ready(p);
  if(await p.getAttribute('html','lang')!=='de') throw 'not kept after a reload';
  if(!(await p.getByRole('button',{name:'Sprache'}).count())) throw 'page is not German after a reload';
  await p.screenshot({path:`${S}/admin-picked-de.png`});
  const after=await (await ctx.request.get(B+'/api/v1/profiles')).json();
  if(JSON.stringify(before.map(x=>x.language))!==JSON.stringify(after.map(x=>x.language))) throw 'profiles changed';
  console.log('picker OK');
  // The profile's Language field.
  await p.getByRole('button',{name:'Bearbeiten'}).first().click(); await sleep(1200);
  await p.screenshot({path:`${S}/admin-profile-dialog.png`});
  await p.getByRole('button',{name:/^Sprache/}).last().click(); await sleep(700);
  await p.getByRole('menuitem',{name:'Português (Brasil)'}).or(p.getByRole('option',{name:'Português (Brasil)'})).or(p.getByRole('button',{name:'Português (Brasil)'})).last().click(); await sleep(800);
  await p.getByRole('button',{name:'Speichern'}).click(); await sleep(1500);
  const saved=await (await ctx.request.get(B+'/api/v1/profiles')).json();
  if(saved[0].language!=='pt') throw 'profile language '+saved[0].language;
  console.log('profile field OK'); console.log('PASS'); process.exit(0);
})().catch(e=>{console.log('FAIL',e);process.exit(1)});
