// GET → {now: <ms since epoch>}: the shared clock for presence and watch-together.
Deno.serve(() =>
  new Response(JSON.stringify({ now: Date.now() }), {
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  })
);
