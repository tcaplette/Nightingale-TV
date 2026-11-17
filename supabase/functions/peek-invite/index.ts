const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

// The caller's account, checked with Auth itself (works with any JWT signing key).
async function caller(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const r = await fetch(`${URL_}/auth/v1/user`, { headers: { Authorization: auth, apikey: ANON } });
  if (!r.ok) return null;
  const u = await r.json();
  return typeof u?.id === "string" ? u.id : null;
}

async function rpc(name: string, args: Record<string, unknown>): Promise<any> {
  const r = await fetch(`${URL_}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`${name}: ${r.status} ${await r.text()}`);
  return await r.json();
}

const CODE_RE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;

async function body(req: Request): Promise<Record<string, unknown>> {
  try { return await req.json(); } catch { return {}; }
}

// POST {code} → {status: ok, kind, from, channels?: [{name}]} | {status: own|gone|limited}
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  // Same cleaning as the app: any case, spaces, dots and the display dot.
  const code = String((await body(req)).code ?? "").replace(/[^A-Za-z0-9]/g, "").toUpperCase();
  if (!CODE_RE.test(code)) return json({ status: "gone" });
  try {
    return json(await rpc("peek_invite", { p_user: user, p_code: code }));
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);
  }
});
