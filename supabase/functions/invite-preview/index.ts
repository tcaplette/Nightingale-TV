// Public invite preview for the invite page, https://<invite host>/ntv/i/<CODE> (design D8).
// Browsers may read it only from INVITE_ORIGIN (self-hosted-sharing D4); with that secret
// unset, no origin is allowed, while server-side fetches still work.
// A live `watch` invite adds show: {title} (watch-together); an ended party's invite is 404.
// GET ?code= → 200 {kind, from:{name, handle, station?}, channels?:[{name}], expires_at} | 404 | 429.
// Never an email. `channels` (in the sender's order) only for a channels invite (channel-sharing).
const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SALT = Deno.env.get("PREVIEW_SALT") ?? SERVICE;
const ORIGIN = (Deno.env.get("INVITE_ORIGIN") ?? "").trim();
const CODE_RE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/i;

const headers: Record<string, string> = {
  ...(ORIGIN ? { "Access-Control-Allow-Origin": ORIGIN } : {}),
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
  "Vary": "Origin",
};

function reply(status: number, body?: unknown): Response {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: body === undefined ? headers : { ...headers, "Content-Type": "application/json" },
  });
}

// Salted, per-day hash: the address itself is never stored.
async function ipHash(req: Request): Promise<string> {
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() ||
    req.headers.get("cf-connecting-ip") || "unknown";
  const day = new Date().toISOString().slice(0, 10);
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${SALT}|${day}|${ip}`));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return reply(204);
  if (req.method !== "GET") return reply(405);
  const code = new URL(req.url).searchParams.get("code") ?? "";
  const hash = await ipHash(req);
  try {
    const r = await fetch(`${URL_}/rest/v1/rpc/invite_preview`, {
      method: "POST",
      headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" },
      // A malformed code still counts as a hit, so it can't be used to dodge the limit.
      body: JSON.stringify({ p_code: CODE_RE.test(code) ? code.toUpperCase() : "------", p_ip_hash: hash }),
    });
    if (!r.ok) throw new Error(`${r.status} ${await r.text()}`);
    const out = await r.json();
    if (out.status === 200) return reply(200, out.body);
    return reply(out.status === 429 ? 429 : 404, { error: out.status === 429 ? "rate_limited" : "not_found" });
  } catch (e) {
    console.error(e);
    return reply(500, { error: "server" });
  }
});
