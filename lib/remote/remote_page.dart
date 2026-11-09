import '../l10n/page_text.dart';
import '../l10n/tr.dart';
import '../ui/widgets/nightingale_mark.dart';

/// The phone remote page. Self-contained (no outside files or fonts), so it
/// works on a home network with no internet.
const _template = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="theme-color" content="#0b1650">
<title>@@title@@</title>
<style>
  :root {
    --bg-top: #0e1d63; --bg-bottom: #050a24; --panel: #13236e; --cell: #1b3394;
    --cell-hi: #2a4bc2; --line: #2c45a8; --accent: #ffd23f; --on-accent: #0b1650;
    --text: #ffffff; --dim: #aab8ee; --red: #ff6b4a;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; min-height: 100%; }
  body {
    background: linear-gradient(var(--bg-top), var(--bg-bottom)) fixed;
    color: var(--text);
    font: 16px/1.3 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    padding: max(12px, env(safe-area-inset-top)) 16px max(20px, env(safe-area-inset-bottom));
    user-select: none; -webkit-user-select: none;
  }
  .wrap { max-width: 440px; margin: 0 auto; }
  .now {
    background: var(--panel); border: 2px solid var(--line); border-radius: 16px;
    padding: 14px 16px; display: grid; grid-template-columns: auto 1fr; gap: 4px 14px; align-items: center;
  }
  .num {
    grid-row: span 3; background: var(--accent); color: var(--on-accent); border-radius: 12px;
    min-width: 64px; height: 64px; display: grid; place-items: center; font-weight: 900; font-size: 30px; padding: 0 8px;
  }
  .num svg { width: 44px; height: auto; }
  .chname { color: var(--accent); font-weight: 800; text-transform: uppercase; letter-spacing: .03em; font-size: 13px;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .title { font-weight: 800; font-size: 20px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--dim); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .bar { grid-column: 1 / -1; height: 6px; background: var(--cell); border-radius: 3px; overflow: hidden; margin-top: 6px; }
  .bar i { display: block; height: 100%; width: 0; background: var(--accent); }
  .who { display: flex; justify-content: space-between; color: var(--dim); font-size: 13px; margin: 10px 4px 14px; }
  .who b { color: var(--text); }
  .offline { color: var(--red); }
  .tabs { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 16px; }
  .tabs button { font-size: 15px; padding: 10px; }
  .tabs button[aria-selected="true"] { background: var(--accent); color: var(--on-accent); border-color: var(--accent); }
  button {
    font: inherit; font-weight: 700; color: var(--text); background: var(--cell);
    border: 2px solid var(--line); border-radius: 14px; padding: 14px 8px; cursor: pointer;
    touch-action: manipulation; transition: background .08s, transform .08s;
  }
  button:active, button.pressing { background: var(--accent); color: var(--on-accent); transform: scale(.96); }
  .row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 14px; }
  .pad {
    position: relative; width: min(300px, 82vw); aspect-ratio: 1; margin: 6px auto 18px;
    border-radius: 50%; background: var(--panel); border: 2px solid var(--line);
  }
  .pad button { position: absolute; border-radius: 12px; width: 31%; height: 31%; font-size: 26px; padding: 0; }
  .pad .up { top: 3%; left: 34.5%; } .pad .down { bottom: 3%; left: 34.5%; }
  .pad .left { left: 3%; top: 34.5%; } .pad .right { right: 3%; top: 34.5%; }
  .pad .ok { left: 31%; top: 31%; width: 38%; height: 38%; border-radius: 50%; background: var(--cell-hi); font-size: 22px; }
  .rocker { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 14px; }
  .rocker button { font-size: 18px; padding: 16px 8px; }
  .digits { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
  .digits button { font-size: 22px; padding: 14px 0; }
  .list { display: grid; gap: 8px; }
  .list button { display: grid; grid-template-columns: 54px 1fr; text-align: left; align-items: center; padding: 12px 14px; }
  .list .n { color: var(--accent); font-size: 22px; font-weight: 900; }
  .list .nm { font-weight: 800; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .list .on { grid-column: 2; color: var(--dim); font-weight: 500; font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .list .cur { border-color: var(--accent); }
  .pair { background: var(--panel); border: 2px solid var(--line); border-radius: 16px; padding: 22px 18px; text-align: center; margin-top: 24px; }
  .pair svg { width: 72px; height: auto; }
  .pair h1 { font-size: 22px; margin: 12px 0 8px; }
  .pair p { color: var(--dim); margin: 0 0 18px; }
  .pair form { display: grid; grid-template-columns: 1fr auto; gap: 10px; }
  .pair input {
    font: inherit; font-size: 26px; font-weight: 800; letter-spacing: .2em; text-align: center; min-width: 0;
    color: var(--text); background: var(--cell); border: 2px solid var(--line); border-radius: 14px; padding: 10px;
  }
  .pair input:focus { outline: none; border-color: var(--accent); }
  .pair button { padding: 12px 20px; background: var(--accent); color: var(--on-accent); border-color: var(--accent); }
  .pair .msg { color: var(--red); min-height: 1.3em; margin: 14px 0 0; }
  [hidden] { display: none !important; }
</style>
</head>
<body>
<div class="wrap">
  <section class="pair" id="pair" hidden>
    ''' + nightingaleMarkSvg + r'''
    <h1>@@pairTitle@@</h1>
    <p>@@pairHelp@@</p>
    <form id="pairform">
      <input id="code" inputmode="numeric" autocomplete="one-time-code" maxlength="7" placeholder="000 000" aria-label="@@pairingCode@@">
      <button type="submit">@@pair@@</button>
    </form>
    <p class="msg" id="pairmsg" role="alert"></p>
  </section>

  <div id="app" hidden>
  <section class="now" aria-live="polite">
    <div class="num" id="num">''' + nightingaleMarkSvg + r'''</div>
    <div class="chname" id="chname">Nightingale TV</div>
    <div class="title" id="title">@@connecting@@</div>
    <div class="sub" id="sub"></div>
    <div class="bar"><i id="bar"></i></div>
  </section>
  <div class="who"><span id="who"></span><span id="status"></span></div>

  <div class="tabs" role="tablist">
    <button role="tab" aria-selected="true" data-tab="remote">@@tabRemote@@</button>
    <button role="tab" aria-selected="false" data-tab="channels">@@tabChannels@@</button>
  </div>

  <section id="remote">
    <div class="row">
      <button data-key="guide">@@guide@@</button>
      <button data-key="menu">@@menu@@</button>
      <button data-key="info">@@info@@</button>
    </div>
    <div class="pad">
      <button class="up" data-key="up" data-repeat aria-label="@@up@@">▲</button>
      <button class="left" data-key="left" data-repeat aria-label="@@left@@">◀</button>
      <button class="ok" data-key="ok">@@ok@@</button>
      <button class="right" data-key="right" data-repeat aria-label="@@right@@">▶</button>
      <button class="down" data-key="down" data-repeat aria-label="@@down@@">▼</button>
    </div>
    <div class="row">
      <button data-key="back">@@back@@</button>
      <button data-key="last">@@lastCh@@</button>
      <button data-key="cc">@@cc@@</button>
    </div>
    <div class="rocker">
      <button data-key="chup" data-repeat>@@chUp@@</button>
      <button data-key="chdown" data-repeat>@@chDown@@</button>
    </div>
    <div class="digits">
      <button data-key="1">1</button><button data-key="2">2</button><button data-key="3">3</button>
      <button data-key="4">4</button><button data-key="5">5</button><button data-key="6">6</button>
      <button data-key="7">7</button><button data-key="8">8</button><button data-key="9">9</button>
      <span></span><button data-key="0">0</button><button data-key="ok">@@enter@@</button>
    </div>
  </section>

  <section id="channels" hidden>
    <div class="list" id="list"></div>
  </section>
  </div>
</div>
<script>
  /*TEXTS*/
  const $ = (id) => document.getElementById(id);
  // The bird fills the number box until a profile is watching.
  const mark = $('num').firstElementChild;
  let state = null;

  // This phone's key for this TV. localStorage is per address and port, so
  // per TV. Blocked storage keeps the key for this visit only.
  const KEY = 'nightingale-remote-key';
  const store = {
    get() { try { return localStorage.getItem(KEY); } catch (e) { return null; } },
    set(v) { try { localStorage.setItem(KEY, v); } catch (e) {} },
    clear() { try { localStorage.removeItem(KEY); } catch (e) {} },
  };
  let key = store.get();

  function headers() {
    const h = { 'Content-Type': 'application/json', 'X-Nightingale-Remote': '1' };
    if (key) h['X-Nightingale-Remote-Key'] = key;
    return h;
  }

  function showPairing(message) {
    $('app').hidden = true;
    $('pair').hidden = false;
    $('pairmsg').textContent = message || '';
  }

  function showRemote() {
    $('pair').hidden = true;
    $('app').hidden = false;
  }

  // The TV no longer knows this phone's key.
  function unpaired() {
    key = null;
    store.clear();
    showPairing(T.removed);
  }

  // A short name for the TV's paired-phones list, like "iPhone · Safari".
  function phoneName() {
    const ua = navigator.userAgent;
    const device = /iPad/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1) ? 'iPad'
      : /iPhone/.test(ua) ? 'iPhone'
      : /Android/.test(ua) ? (/Mobile/.test(ua) ? 'Android phone' : 'Android tablet')
      : /CrOS/.test(ua) ? 'Chromebook'
      : /Macintosh/.test(ua) ? 'Mac'
      : /Windows/.test(ua) ? 'Windows PC'
      : /Linux/.test(ua) ? 'Linux PC' : 'Phone';
    const browser = /EdgA?\/|EdgiOS/.test(ua) ? 'Edge'
      : /SamsungBrowser/.test(ua) ? 'Samsung Internet'
      : /Firefox|FxiOS/.test(ua) ? 'Firefox'
      : /OPR\//.test(ua) ? 'Opera'
      : /CriOS|Chrome/.test(ua) ? 'Chrome'
      : /Safari/.test(ua) ? 'Safari' : '';
    return browser && device !== 'iPad' ? device + ' · ' + browser : device;
  }

  async function pair(code) {
    $('pairmsg').textContent = '';
    try {
      const r = await fetch('/api/pair', { method: 'POST', headers: headers(), body: JSON.stringify({ code, name: phoneName() }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok || !j.key) { showPairing(j.error || T.couldntPair); return; }
      key = j.key;
      store.set(key);
      $('code').value = '';
      showRemote();
      refresh();
    } catch (e) {
      showPairing(T.cantReachWifi);
    }
  }

  $('pairform').addEventListener('submit', (e) => {
    e.preventDefault();
    const code = $('code').value.replace(/\D/g, '');
    if (code.length !== 6) { $('pairmsg').textContent = T.enterDigits; return; }
    pair(code);
  });

  async function post(path, body) {
    if (!key) { showPairing(); return; }
    try {
      const r = await fetch(path, { method: 'POST', headers: headers(), body: JSON.stringify(body) });
      if (r.status === 401) { unpaired(); return; }
      if (!r.ok) throw new Error(r.status);
      setOnline(true);
    } catch (e) { setOnline(false); }
    setTimeout(refresh, 350);
  }

  function press(key) {
    if (navigator.vibrate) navigator.vibrate(12);
    post('/api/key', { key });
  }

  // Tap sends one press; holding an arrow or CH repeats, like a real remote.
  document.querySelectorAll('[data-key]').forEach((b) => {
    let timer = null, repeat = null;
    const stop = () => { clearTimeout(timer); clearInterval(repeat); timer = repeat = null; b.classList.remove('pressing'); };
    b.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      b.classList.add('pressing');
      press(b.dataset.key);
      if (b.hasAttribute('data-repeat')) {
        timer = setTimeout(() => { repeat = setInterval(() => press(b.dataset.key), 180); }, 450);
      }
    });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach((t) => b.addEventListener(t, stop));
  });

  document.querySelectorAll('[data-tab]').forEach((t) => t.addEventListener('click', () => {
    document.querySelectorAll('[data-tab]').forEach((x) => x.setAttribute('aria-selected', x === t));
    $('remote').hidden = t.dataset.tab !== 'remote';
    $('channels').hidden = t.dataset.tab !== 'channels';
  }));

  function setOnline(ok) {
    $('status').textContent = ok ? '' : T.cantReachTv;
    $('status').className = ok ? '' : 'offline';
  }

  function fmt(t) {
    return new Date(t).toLocaleTimeString(LANG, { hour: 'numeric', minute: '2-digit', hour12: LANG === 'en' });
  }

  function render(s) {
    // The TV changed language: the page follows, still paired.
    if (s.language && s.language !== LANG) { location.reload(); return; }
    state = s;
    if (!s.profile) {
      $('num').replaceChildren(mark);
      $('chname').textContent = 'Nightingale TV';
      $('title').textContent = T.whosWatching;
      $('sub').textContent = T.pickProfile;
      $('who').textContent = '';
      $('bar').style.width = '0';
      $('list').replaceChildren();
      return;
    }
    const p = s.program, c = s.channel;
    $('num').textContent = c ? c.number : '–';
    $('chname').textContent = c ? c.name + (p && p.block ? ' · ' + p.block : '') : '';
    $('title').textContent = p ? p.title : T.tuning;
    $('sub').textContent = p ? (p.commercial ? T.commercialBreak + ' · ' : '') + p.subtitle + ' · ' + fmt(p.start) + ' – ' + fmt(p.end) : '';
    if (p) {
      const start = new Date(p.start), end = new Date(p.end), now = new Date(s.now);
      $('bar').style.width = Math.max(0, Math.min(100, 100 * (now - start) / (end - start))) + '%';
    }
    $('who').innerHTML = '';
    const who = document.createElement('span');
    const b = document.createElement('b'); b.textContent = s.kid ? T.kidName.replace('{name}', s.profile) : s.profile;
    const [before, after] = T.watching.split('{name}');
    who.append(before, b, after);
    $('who').append(who);

    const list = $('list');
    list.replaceChildren(...s.channels.map((ch) => {
      const btn = document.createElement('button');
      if (c && ch.number === c.number) btn.className = 'cur';
      const n = document.createElement('span'); n.className = 'n'; n.textContent = ch.number;
      const nm = document.createElement('span'); nm.className = 'nm'; nm.textContent = ch.name;
      const on = document.createElement('span'); on.className = 'on'; on.textContent = ch.now || '';
      btn.append(n, nm, on);
      btn.addEventListener('click', () => {
        if (navigator.vibrate) navigator.vibrate(12);
        post('/api/tune', { number: ch.number });
      });
      return btn;
    }));
  }

  async function refresh() {
    if (!key) return;
    try {
      const r = await fetch('/api/state', { cache: 'no-store', headers: headers() });
      if (r.status === 401) { unpaired(); return; }
      render(await r.json());
      setOnline(true);
    } catch (e) { setOnline(false); }
  }

  // The QR code carries a one-time code in the fragment, which never
  // reaches the server or its logs. It's cleared once read.
  const fromQr = /(?:^#|&)pair=(\d{6})/.exec(location.hash);
  if (fromQr) {
    history.replaceState(null, '', location.pathname + location.search);
    pair(fromQr[1]);
  } else if (key) {
    showRemote();
    refresh();
  } else {
    showPairing();
  }
  setInterval(() => { if (!document.hidden) refresh(); }, 3000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
</script>
</body>
</html>
''';

/// The page's text, in the language the TV is showing (design D9).
Map<String, String> remotePageTexts() => {
      'title': tr.remotePageTitle,
      'pairTitle': tr.remotePairTitle,
      'pairHelp': tr.remotePairHelp,
      'pairingCode': tr.remotePairingCode,
      'pair': tr.remotePair,
      'connecting': tr.remoteConnecting,
      'tabRemote': tr.remoteTabRemote,
      'tabChannels': tr.channels5,
      'guide': tr.guide2,
      'menu': tr.menu,
      'info': tr.remoteInfo,
      'up': tr.remoteUp,
      'left': tr.remoteLeft,
      'right': tr.remoteRight,
      'down': tr.remoteDown,
      'ok': tr.ok,
      'back': tr.back,
      'lastCh': tr.remoteLastCh,
      'cc': tr.remoteCc,
      'chUp': tr.remoteChUp,
      'chDown': tr.remoteChDown,
      'enter': tr.remoteEnter,
      'removed': tr.remoteRemovedFromTv,
      'couldntPair': tr.remoteCouldntPair,
      'cantReachWifi': tr.remoteCantReachWifi,
      'enterDigits': tr.remoteEnterDigits,
      'cantReachTv': tr.remoteCantReachTv,
      'whosWatching': tr.whosWatching,
      'pickProfile': tr.remotePickProfile,
      'tuning': tr.tuning2,
      'commercialBreak': tr.commercialBreak,
      'watching': tr.remoteWatching('{name}'),
      'kidName': tr.remoteKidName('{name}'),
    };

/// The page, in the language the TV is showing.
String remotePageHtml() => fillPage(_template, remotePageTexts());
