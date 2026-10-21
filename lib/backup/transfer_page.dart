/// The page a phone or computer opens to move a backup (backup-restore
/// D12). Self-contained (no outside files or fonts), like the remote's, so
/// it works on a home network with no internet. Its links are relative to
/// the page's own tokened address.
const transferPageHtml = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#0b1650">
<title>Nightingale TV Backup</title>
<style>
  :root {
    --bg-top: #0e1d63; --bg-bottom: #050a24; --panel: #13236e; --cell: #1b3394;
    --line: #2c45a8; --accent: #ffd23f; --on-accent: #0b1650;
    --text: #ffffff; --dim: #aab8ee; --red: #ff6b4a; --green: #7ee08a;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; min-height: 100%; }
  body {
    background: linear-gradient(var(--bg-top), var(--bg-bottom)) fixed;
    color: var(--text);
    font: 17px/1.4 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    padding: max(20px, env(safe-area-inset-top)) 18px max(24px, env(safe-area-inset-bottom));
  }
  .wrap { max-width: 560px; margin: 0 auto; }
  h1 { color: var(--accent); font-size: 26px; font-weight: 900; text-transform: uppercase; letter-spacing: .03em; margin: 8px 0 6px; }
  p { color: var(--dim); margin: 0 0 18px; }
  .card { background: var(--panel); border: 2px solid var(--line); border-radius: 16px; padding: 18px; margin-bottom: 16px; }
  .card h2 { font-size: 19px; margin: 0 0 6px; }
  .card p { margin-bottom: 14px; font-size: 15px; }
  .button {
    display: block; width: 100%; text-align: center; text-decoration: none;
    font: inherit; font-weight: 800; color: var(--on-accent); background: var(--accent);
    border: 0; border-radius: 14px; padding: 16px 10px; cursor: pointer; touch-action: manipulation;
  }
  .button.secondary { color: var(--text); background: var(--cell); border: 2px solid var(--line); }
  .button:active { transform: scale(.98); }
  input[type=file] { display: none; }
  #status { min-height: 1.4em; margin: 12px 2px 0; font-weight: 700; }
  #status.ok { color: var(--green); } #status.err { color: var(--red); }
  .foot { color: var(--dim); font-size: 13px; text-align: center; margin-top: 22px; }
</style>
</head>
<body>
<div class="wrap">
  <h1>Nightingale TV</h1>
  <p>Move a backup between this TV and this device. Keep the TV's dialog open while you do.</p>
  <div class="card">
    <h2>Download backup</h2>
    <p>A backup of the TV's setup as it is now: profiles, channels, blocks and settings.</p>
    <a class="button" href="backup" download>Download backup</a>
  </div>
  <div class="card">
    <h2>Restore from a file</h2>
    <p>Send a <b>.ntvbackup</b> file to the TV. Nothing changes until you confirm it on the TV.</p>
    <label class="button secondary" for="file">Choose a backup file…</label>
    <input id="file" type="file" accept=".ntvbackup,application/octet-stream,application/gzip">
    <div id="status" role="status" aria-live="polite"></div>
  </div>
  <div class="foot">Only devices on your home network can open this page.</div>
</div>
<script>
  const input = document.getElementById('file');
  const status = document.getElementById('status');
  function show(text, kind) { status.textContent = text; status.className = kind || ''; }
  input.addEventListener('change', async () => {
    const file = input.files && input.files[0];
    input.value = '';
    if (!file) return;
    if (file.size > 32 * 1024 * 1024) { show('That file is too big to be a Nightingale TV backup.', 'err'); return; }
    show('Sending ' + file.name + '…');
    try {
      const r = await fetch('restore', {
        method: 'POST',
        headers: { 'x-nightingale-remote': '1', 'content-type': 'application/octet-stream' },
        body: file,
      });
      let body = {};
      try { body = await r.json(); } catch (_) {}
      if (r.ok) show('Check your TV to finish.', 'ok');
      else if (r.status === 404) show('The TV closed this page. Open it again from Backup & restore.', 'err');
      else show(body.error || 'The TV couldn’t take that file.', 'err');
    } catch (_) {
      show('Couldn’t reach the TV. Is it still showing the code?', 'err');
    }
  });
</script>
</body>
</html>
''';
