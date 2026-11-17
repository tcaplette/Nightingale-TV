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

// POST {channel_name, state, invite?: [userId], link?: bool}
//   → {status: ok, party, code?, expires_at?} | {status: no_profile|not_friends|too_many|bad_request}
// Starts a watch party with the caller as host (watch-together D7). With `party` instead of
// `channel_name`, the host invites more to a party already on (the party row's Invite).
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  const b = await body(req);
  const invite = Array.isArray(b.invite) ? b.invite.map(String) : [];
  const link = b.link === true;
  if (!invite.every((id: string) => UUID_RE.test(id) && id !== user)) return json({ status: "bad_request" });
  try {
    if (typeof b.party === "string") {
      if (!UUID_RE.test(b.party)) return json({ status: "bad_request" });
      return json(await rpc("party_invite", { p_host: user, p_party: b.party, p_invite: invite, p_link: link }));
    }
    const state = b.state;
    if (typeof b.channel_name !== "string" || typeof state !== "object" || state === null) {
      return json({ status: "bad_request" });
    }
    return json(await rpc("start_party", {
      p_host: user, p_channel: b.channel_name.slice(0, 100), p_state: state, p_invite: invite, p_link: link,
    }));
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);
  }
});
