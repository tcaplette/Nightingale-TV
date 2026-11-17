// Run: docker run --rm -v <node_modules dir with playwright@1.56.1>:/pw/node_modules:ro -v $PWD/tool/web_admin_tests:/s:ro -v /tmp:/out
//   mcr.microsoft.com/playwright:v1.56.1-noble node /s/channels_invite.js <BASE> <CODE>
// <BASE>: the invite page's address, e.g. https://invites.example.org (no trailing slash)
// <CODE>: a live channels invite, e.g. from tool/share_peer share-channels <email> two.json --link
// channel-sharing 7.2: the invite page's preview of a `channels` invite link.
const { chromium } = require('/pw/node_modules/playwright');
(async () => {
  const [base, code] = process.argv.slice(2);
  if (!base || !code) {
    console.log('usage: node channels_invite.js <BASE> <CODE>');
    process.exit(2);
  }
  const browser = await chromium.launch();
  const page = await (await browser.newContext({ locale: 'en-US', viewport: { width: 412, height: 915 } })).newPage();
  await page.goto(`${base.replace(/\/+$/, '')}/ntv/i/${code}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  const text = await page.innerText('body');
  await page.screenshot({ path: '/out/channels_invite.png', fullPage: true });
  const checks = [
    ['Tyler shared 2 channels with you', text.includes('Tyler shared 2 channels with you')],
    ['90s Sitcoms', text.includes('90s Sitcoms')],
    ['Toon TV', text.includes('Toon TV')],
  ];
  for (const [what, ok] of checks) console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (checks.some(([, ok]) => !ok)) console.log('PAGE TEXT:\n' + text);
  await browser.close();
  process.exit(checks.every(([, ok]) => ok) ? 0 : 1);
})();
