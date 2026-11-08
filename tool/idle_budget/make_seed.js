// Makes the idle check's seed config (idle-cpu D4), run by make_seed.sh in
// the Playwright container: sets the first admin's password through the
// setup link, starts fresh with one profile, signs it in to the test server
// and waits until its channels are exported.
// Env: NTV_URL (the server, as the container reaches it), NTV_TOKEN (the
// setup link's token), NTV_ADMIN_PW, MS_URL, MS_USER, MS_PW (the test server).
const {request} = require('playwright');
const env = k => process.env[k] || (() => { throw new Error(`${k} isn't set`); })();
const B = env('NTV_URL');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const fail = m => { console.log('FAIL ' + m); process.exit(1); };

(async () => {
  const ctx = await request.newContext({baseURL: B});
  let etag = null;
  const api = async (method, path, body) => {
    const headers = {'X-Nightingale-TV': '1', 'Content-Type': 'application/json'};
    if (method !== 'GET' && etag) headers['If-Match'] = etag;
    const r = await ctx.fetch('/api/v1/' + path, {method, headers, data: body ? JSON.stringify(body) : undefined});
    if (r.headers().etag) etag = r.headers().etag;
    return {s: r.status(), j: await r.json().catch(() => null)};
  };

  let r = await api('POST', 'password', {token: env('NTV_TOKEN'), name: 'admin', password: env('NTV_ADMIN_PW')});
  if (r.s !== 200) fail(`admin password: ${r.s} ${JSON.stringify(r.j)}`);
  console.log('ADMIN made');

  await api('GET', 'profiles');
  r = await api('POST', 'profiles', {name: 'Idle check'});
  if (r.s !== 200) fail(`start fresh: ${r.s} ${JSON.stringify(r.j)}`);
  const id = r.j.id;
  console.log('PROFILE ' + id);

  const step = async (body) => {
    const x = await api('POST', `profiles/${id}/sign-in`, body);
    if (x.s !== 200) fail(`sign-in ${body.action}: ${x.s} ${JSON.stringify(x.j)}`);
    return x.j;
  };
  let s = await step({action: 'start'});
  s = await step({action: 'connect', address: env('MS_URL')});
  for (let i = 0; s.busy && i < 60; i++) { await sleep(500); s = (await api('GET', `profiles/${id}/sign-in`)).j; }
  if (s.stage === 'method') s = await step({action: 'choosePassword'});
  if (s.stage !== 'password') fail(`expected the password step, got ${s.stage} ${s.error || ''}`);
  s = await step({action: 'password', user: env('MS_USER'), password: env('MS_PW')});
  for (let i = 0; !s.finished && i < 120; i++) {
    if (s.error) fail('sign-in: ' + s.error);
    await sleep(500);
    s = (await api('GET', `profiles/${id}/sign-in`)).j;
  }
  if (!s.finished) fail('sign-in never finished');
  console.log('SIGNED IN');

  // Export and its channels: up once the library has synced.
  for (let i = 0; i < 600; i++) {
    const st = (await api('GET', 'status')).j;
    const p = st && st.profiles.find(p => p.id === id);
    if (p && p.exported && p.url && !p.problem) {
      const lineup = await ctx.fetch(p.url.replace(/^http:\/\/[^/:]+/, B.replace(/:\d+$/, '')) + '/lineup.json').catch(() => null);
      const n = lineup && lineup.ok() ? (await lineup.json()).length : 0;
      if (n > 0) { console.log(`EXPORTED port ${p.port}, ${n} channels`); process.exit(0); }
    }
    if (i % 20 === 0) console.log(`waiting for the export (${p ? p.problem || 'starting' : 'no profile'})`);
    await sleep(1000);
  }
  fail('the export never came up');
})().catch(e => fail(e.message));
