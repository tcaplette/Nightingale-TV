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

// POST {recipes: [{id, name, recipe}], to?: [userId], link?: bool}
//   → {status: ok, channels: [{id, version}], code?, expires_at?}
//   | {status: not_friends|too_big|bad_request|no_profile}
// Publishes the recipes under the caller (a changed one gets version + 1) and shares them with
// friends, or makes a `channels` invite. With neither, it only publishes (Keep updated).
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const user = await caller(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  const b = await body(req);
  const recipes = Array.isArray(b.recipes) ? b.recipes : [];
  const to = Array.isArray(b.to) ? b.to.map(String) : [];
  const link = b.link === true;
  const ok = recipes.length > 0 && recipes.every((r: any) =>
    r && typeof r === "object" && UUID_RE.test(String(r.id)) && typeof r.recipe === "object" && r.recipe !== null
  ) && to.every((id: string) => UUID_RE.test(id) && id !== user) && !(link && to.length > 0);
  if (!ok) return json({ status: "bad_request" });
  try {
    return json(await rpc("share_channels", {
      p_owner: user,
      p_recipes: recipes.map((r: any) => ({ id: r.id, name: String(r.name ?? ""), recipe: r.recipe })),
      p_to: to,
      p_link: link,
    }));
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);
  }
});
