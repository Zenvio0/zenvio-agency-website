import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("ARIA_ADMIN_ALLOWED_ORIGIN") ?? "https://zenvio-agency.haiderium213.workers.dev",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return reply(401, { error: "Sign-in required" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply(500, { error: "Server configuration incomplete" });

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await caller.auth.getUser(token);
  if (userError || !userData.user) return reply(401, { error: "Invalid session" });

  const { data: isAdmin, error: adminCheckError } = await caller.rpc("zenvio_is_super_admin");
  if (adminCheckError || isAdmin !== true) return reply(403, { error: "Super Admin access required" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON body" }); }
  const action = typeof body.action === "string" ? body.action : "";
  const adminDb = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  if (action === "list_installations") {
    const { data: installations, error: listError } = await adminDb
      .from("zenvio_aria_installations")
      .select("id, public_install_id, project_id, organization_id, enabled, revoked_at, created_at, zenvio_creative_projects(name), zenvio_organizations(name), zenvio_aria_admin_controls(globally_enabled, locked_fields)")
      .order("created_at", { ascending: false })
      .limit(200);
    if (listError) return reply(500, { error: "Could not load ARIA installations" });
    const { data: events, error: eventError } = await adminDb
      .from("zenvio_aria_audit_events")
      .select("id, organization_id, project_id, installation_id, actor_scope, action, details, created_at")
      .order("created_at", { ascending: false })
      .limit(100);
    if (eventError) return reply(500, { error: "Could not load ARIA audit history" });
    return reply(200, { ok: true, installations: installations ?? [], events: events ?? [] });
  }

  const installationId = typeof body.installation_id === "string" ? body.installation_id : "";
  if (!installationId) return reply(400, { error: "installation_id is required" });

  const { data: installation, error: lookupError } = await adminDb
    .from("zenvio_aria_installations")
    .select("id, project_id, organization_id, enabled, revoked_at")
    .eq("id", installationId)
    .maybeSingle();
  if (lookupError) return reply(500, { error: "Could not load installation" });
  if (!installation) return reply(404, { error: "Installation not found" });

  let patch: Record<string, unknown> | null = null;
  if (action === "enable") patch = { enabled: true, revoked_at: null };
  else if (action === "disable") patch = { enabled: false };
  else if (action === "revoke") patch = { enabled: false, revoked_at: new Date().toISOString() };
  else if (action === "restore") patch = { enabled: true, revoked_at: null };
  else if (action === "set_admin_config") {
    if (!body.admin_config || typeof body.admin_config !== "object" || Array.isArray(body.admin_config)) {
      return reply(400, { error: "admin_config must be an object" });
    }
    const allowedFields = new Set(["owner_enabled", "greeting", "tone", "knowledge", "services", "recommendations", "contact"]);
    const adminConfig = body.admin_config as Record<string, unknown>;
    const keys = Object.keys(adminConfig);
    if (keys.some(key => !allowedFields.has(key))) return reply(400, { error: "admin_config contains an unsupported field" });
    if (typeof adminConfig.greeting === "string" && adminConfig.greeting.length > 500) return reply(400, { error: "Greeting is too long" });
    if (typeof adminConfig.knowledge === "string" && adminConfig.knowledge.length > 12000) return reply(400, { error: "Knowledge text is too long" });
    const lockedFields = body.locked_fields === undefined ? [] : body.locked_fields;
    if (!Array.isArray(lockedFields) || lockedFields.length > allowedFields.size ||
      lockedFields.some(field => typeof field !== "string" || !allowedFields.has(field)) ||
      new Set(lockedFields).size !== lockedFields.length) {
      return reply(400, { error: "locked_fields must contain unique supported field names" });
    }
    const { error } = await adminDb.from("zenvio_aria_admin_controls").upsert({
      installation_id: installation.id,
      admin_config: adminConfig,
      locked_fields: lockedFields,
      updated_at: new Date().toISOString(),
    }, { onConflict: "installation_id" });
    if (error) return reply(500, { error: "Could not update protected configuration" });
  } else {
    return reply(400, { error: "Unsupported action" });
  }

  if (patch) {
    const { error } = await adminDb.from("zenvio_aria_installations").update({
      ...patch,
      updated_at: new Date().toISOString(),
    }).eq("id", installation.id);
    if (error) return reply(500, { error: "Could not update installation status" });
  }

  const { error: auditError } = await adminDb.from("zenvio_aria_audit_events").insert({
    organization_id: installation.organization_id,
    project_id: installation.project_id,
    installation_id: installation.id,
    actor_user_id: userData.user.id,
    actor_scope: "super_admin",
    action,
    details: { status_change: patch ?? null },
  });
  if (auditError) return reply(500, { error: "Action applied but audit logging failed; review required" });

  return reply(200, { ok: true, action, installation_id: installation.id });
});
