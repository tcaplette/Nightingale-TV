/// The phone remote page. Self-contained (no outside files or fonts), so it
/// works on a home network with no internet.
const remotePageHtml = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="theme-color" content="#0b1650">
<title>Nightingale TV Remote</title>
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
  [hidden] { display: none !important; }
</style>
</head>
<body>
<div class="wrap">
  <section class="now" aria-live="polite">
    <div class="num" id="num">TV</div>
    <div class="chname" id="chname">Nightingale TV</div>
    <div class="title" id="title">Connecting…</div>
    <div class="sub" id="sub"></div>
    <div class="bar"><i id="bar"></i></div>
  </section>
  <div class="who"><span id="who"></span><span id="status"></span></div>

  <div class="tabs" role="tablist">
    <button role="tab" aria-selected="true" data-tab="remote">Remote</button>
    <button role="tab" aria-selected="false" data-tab="channels">Channels</button>
  </div>

  <section id="remote">
    <div class="row">
      <button data-key="guide">Guide</button>
      <button data-key="menu">Menu</button>
      <button data-key="info">Info</button>
    </div>
    <div class="pad">
      <button class="up" data-key="up" data-repeat aria-label="Up">▲</button>
      <button class="left" data-key="left" data-repeat aria-label="Left">◀</button>
      <button class="ok" data-key="ok">OK</button>
      <button class="right" data-key="right" data-repeat aria-label="Right">▶</button>
      <button class="down" data-key="down" data-repeat aria-label="Down">▼</button>
    </div>
    <div class="row">
      <button data-key="back">Back</button>
      <button data-key="last">Last ch</button>
      <button data-key="cc">CC</button>
    </div>
    <div class="rocker">
      <button data-key="chup" data-repeat>CH +</button>
      <button data-key="chdown" data-repeat>CH −</button>
    </div>
    <div class="digits">
      <button data-key="1">1</button><button data-key="2">2</button><button data-key="3">3</button>
      <button data-key="4">4</button><button data-key="5">5</button><button data-key="6">6</button>
      <button data-key="7">7</button><button data-key="8">8</button><button data-key="9">9</button>
      <span></span><button data-key="0">0</button><button data-key="ok">Enter</button>
    </div>
  </section>

  <section id="channels" hidden>
    <div class="list" id="list"></div>
  </section>
</div>
<script>
  const headers = { 'Content-Type': 'application/json', 'X-Nightingale-Remote': '1' };
  const $ = (id) => document.getElementById(id);
  let state = null;

  async function post(path, body) {
    try {
      const r = await fetch(path, { method: 'POST', headers, body: JSON.stringify(body) });
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
    $('status').textContent = ok ? '' : 'Can\'t reach the TV';
    $('status').className = ok ? '' : 'offline';
  }

  function fmt(t) {
    return new Date(t).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  }

  function render(s) {
    state = s;
    if (!s.profile) {
      $('num').textContent = 'TV';
      $('chname').textContent = 'Nightingale TV';
      $('title').textContent = 'Who\'s watching?';
      $('sub').textContent = 'Pick a profile with the arrows and OK.';
      $('who').textContent = '';
      $('bar').style.width = '0';
      $('list').replaceChildren();
      return;
    }
    const p = s.program, c = s.channel;
    $('num').textContent = c ? c.number : '–';
    $('chname').textContent = c ? c.name + (p && p.block ? ' · ' + p.block : '') : '';
    $('title').textContent = p ? p.title : 'Tuning…';
    $('sub').textContent = p ? (p.commercial ? 'Commercial break · ' : '') + p.subtitle + ' · ' + fmt(p.start) + ' – ' + fmt(p.end) : '';
    if (p) {
      const start = new Date(p.start), end = new Date(p.end), now = new Date(s.now);
      $('bar').style.width = Math.max(0, Math.min(100, 100 * (now - start) / (end - start))) + '%';
    }
    $('who').innerHTML = '';
    const who = document.createElement('span');
    who.append('Watching: ');
    const b = document.createElement('b'); b.textContent = s.profile + (s.kid ? ' (kid)' : '');
    who.append(b);
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
    try {
      const r = await fetch('/api/state', { cache: 'no-store' });
      render(await r.json());
      setOnline(true);
    } catch (e) { setOnline(false); }
  }

  refresh();
  setInterval(() => { if (!document.hidden) refresh(); }, 3000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
</script>
</body>
</html>
''';
