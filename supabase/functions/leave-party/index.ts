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

async function body(req: Request): Promise<Record<string, unknown>> {
  try { return await req.json(); } catch { return {}; }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// POST {party, reason?: "host-gone"} → {status: ok, ended} | {status: not_member|bad_request}
// The caller leaves; the host leaving ends the party for everyone. A member's `host-gone`
// ends it when the host hasn't written for 60 seconds.
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  const b = await body(req);
  const party = String(b.party ?? "");
  if (!UUID_RE.test(party)) return json({ status: "bad_request" });
  try {
    return json(await rpc("leave_party", {
      p_user: user, p_party: party, p_reason: b.reason === "host-gone" ? "host-gone" : "leave",
    }));
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);
  }
});
