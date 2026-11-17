// Run: docker run --rm -v <node_modules dir with playwright@1.56.1>:/pw/node_modules:ro
//   -v $PWD/tool/web_admin_tests:/s:ro -v $PWD/invite_page:/site:ro -v /tmp:/out
//   mcr.microsoft.com/playwright:v1.56.1-noble node /s/invite_page.js
//   <ORIGIN> <INVITE_API> <friend> <channels> <watch> <markup> <gone>
// <ORIGIN>: the origin the backend's INVITE_ORIGIN allows, e.g. https://invites.example.org.
//   The page is served under it by request routing (from /site), so nothing is deployed.
// <INVITE_API>: https://<ref>.supabase.co/functions/v1/invite-preview
// Codes, from tool/share_peer: <friend> a live friend code of Tyler (@tyler)
//   (`invite <B>`); <channels> a live channels invite of Tyler's two channels, 90s Sitcoms
//   and Toon TV (`share-channels <B> two.json --link`); <watch> a live watch invite of
//   Tyler's (`party-host <B> two.json --link`); <markup> a live friend code of an account
//   named <b>Sam</b> (@sam); <gone> an unknown, used or expired code.
// self-hosted-sharing 5.3: the static invite page (invite_page/) shows each preview kind,
// the 404 and 429 states and the code to type, and inserts every value as text.
const fs = require('fs');
const path = require('path');
const { chromium } = require('/pw/node_modules/playwright');

const [origin, api, friend, channels, watch, markup, gone] = process.argv.slice(2);
if (!gone) {
  console.log('usage: node invite_page.js <ORIGIN> <INVITE_API> <friend> <channels> <watch> <markup> <gone>');
  process.exit(2);
}
const SITE = '/site';
const config = `window.NTV_INVITE = { INVITE_API: ${JSON.stringify(api)}, ` +
  `GET_APP_URL: "https://example.org/releases" };\n`;
const pretty = (c) => `${c.slice(0, 4)}·${c.slice(4)}`;
const results = [];
const check = (what, ok) => { results.push(ok); console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`); };

// A static host: files from /site, config.js generated, unknown paths answered with
// 404.html and status 404 (as GitHub Pages does). Works under a sub-path too (/repo/…).
async function serve(context, prefix = '') {
  await context.route(`${origin}/**`, async (route) => {
    const u = new URL(route.request().url());
    let p = u.pathname;
    if (prefix && p.startsWith(prefix)) p = p.slice(prefix.length);
    if (p === '/config.js') {
      return route.fulfill({ status: 200, contentType: 'text/javascript', body: config });
    }
    if (p.endsWith('/')) p += 'index.html';
    const file = path.join(SITE, path.normalize(p));
    if (file.startsWith(SITE + '/') && fs.existsSync(file) && fs.statSync(file).isFile()) {
      return route.fulfill({ status: 200, contentType: 'text/html', body: fs.readFileSync(file) });
    }
    return route.fulfill({ status: 404, contentType: 'text/html',
                           body: fs.readFileSync(path.join(SITE, '404.html')) });
  });
}

async function open(context, url, shot) {
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  const text = await page.innerText('body');
  await page.screenshot({ path: `/out/invite_page_${shot}.png`, fullPage: true });
  check(`${shot}: no script errors${errors.length ? ' — ' + errors.join('; ') : ''}`, errors.length === 0);
  return { page, text };
}

function codeChecks(name, text, code) {
  check(`${name}: shows the code ${pretty(code)}`, text.includes(pretty(code)));
  check(`${name}: says how to enter it`,
        text.includes('Open Nightingale TV → Sharing → Add friend → Enter a code'));
}

(async () => {
  check('404.html is identical to index.html',
        fs.readFileSync(path.join(SITE, '404.html')).equals(fs.readFileSync(path.join(SITE, 'index.html'))));
  const showTitle = await (async () => {
    const r = await fetch(`${api}?code=${watch}`);
    const j = r.ok ? await r.json() : {};
    return j.show && j.show.title;
  })();
  check(`watch invite has a show title (${showTitle})`, !!showTitle);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ locale: 'en-US', viewport: { width: 412, height: 915 } });
  await serve(ctx);

  let r = await open(ctx, `${origin}/ntv/i/${friend}`, 'friend');
  check('friend: "Tyler (@tyler) wants to be friends on Nightingale TV"',
        r.text.includes('Tyler (@tyler) wants to be friends on Nightingale TV'));
  check('friend: get-the-app link from config.js',
        (await r.page.getAttribute('#get-app', 'href')) === 'https://example.org/releases');
  codeChecks('friend', r.text, friend);

  r = await open(ctx, `${origin}/ntv/i/${channels}`, 'channels');
  check('channels: "Tyler shared 2 channels with you"', r.text.includes('Tyler shared 2 channels with you'));
  check('channels: lists 90s Sitcoms', r.text.includes('90s Sitcoms'));
  check('channels: lists Toon TV', r.text.includes('Toon TV'));
  codeChecks('channels', r.text, channels);

  r = await open(ctx, `${origin}/ntv/i/${watch}`, 'watch');
  check(`watch: "Tyler invited you to watch ${showTitle}"`,
        r.text.includes(`Tyler invited you to watch ${showTitle}`));
  codeChecks('watch', r.text, watch);

  r = await open(ctx, `${origin}/ntv/i/${markup}`, 'markup');
  check('markup: the name shows as the literal text <b>Sam</b>',
        r.text.includes('<b>Sam</b> (@sam) wants to be friends on Nightingale TV'));
  check('markup: no <b> element was made from the name',
        (await r.page.$$eval('#title b', (els) => els.length)) === 0);

  r = await open(ctx, `${origin}/ntv/i/${gone}`, 'gone');
  check('gone: "This invite has expired or was already used."',
        r.text.includes('This invite has expired or was already used.'));
  check('gone: no code shown', !r.text.includes(pretty(gone)));

  r = await open(ctx, `${origin}/index.html?code=${friend.toLowerCase()}`, 'query');
  check('?code= form: friend preview', r.text.includes('Tyler (@tyler) wants to be friends on Nightingale TV'));
  codeChecks('?code= form', r.text, friend);

  r = await open(ctx, `${origin}/ntv/i/NOT-A-CODE!`, 'invalid');
  check('invalid: "This link isn’t a valid invite."', r.text.includes('This link isn’t a valid invite.'));

  // A forced 429 from the preview function.
  const limited = await browser.newContext({ locale: 'en-US', viewport: { width: 412, height: 915 } });
  await serve(limited);
  await limited.route(`${api}**`, (route) => route.fulfill({
    status: 429, contentType: 'application/json', body: '{"error":"rate_limited"}',
    headers: { 'Access-Control-Allow-Origin': origin } }));
  r = await open(limited, `${origin}/ntv/i/${friend}`, 'limited');
  check('429: "Too many tries. Try again later."', r.text.includes('Too many tries. Try again later.'));
  codeChecks('429', r.text, friend);

  // A GitHub Pages project site: everything under /<repo>/.
  const sub = await browser.newContext({ locale: 'en-US', viewport: { width: 412, height: 915 } });
  await serve(sub, '/nightingale');
  r = await open(sub, `${origin}/nightingale/ntv/i/${channels}`, 'subpath');
  check('sub-path site: channels preview', r.text.includes('Tyler shared 2 channels with you'));

  await browser.close();
  const ok = results.every(Boolean);
  console.log(ok ? `all ${results.length} checks passed` : `${results.filter((x) => !x).length} check(s) failed`);
  process.exit(ok ? 0 : 1);
})();
