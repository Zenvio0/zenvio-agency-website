import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { disabledCapability } from "./capabilities.ts";
import { applyAdminLocks } from "./admin-config.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}
function tokens(value: string): string[] {
  return value.toLowerCase().match(/[a-z0-9]{3,}/g) ?? [];
}
function findKnowledgeAnswer(question: string, knowledge: string): string | null {
  const q = new Set(tokens(question));
  if (!q.size || !knowledge.trim()) return null;
  const blocks = knowledge.split(/\n+/).map(x => x.trim()).filter(Boolean);
  const ranked = blocks.map(block => {
    const words = tokens(block);
    const overlap = words.reduce((n, word) => n + (q.has(word) ? 1 : 0), 0);
    return { block, overlap };
  }).filter(x => x.overlap > 0).sort((a, b) => b.overlap - a.overlap);
  if (!ranked.length) return null;
  return ranked.slice(0, 3).map(x => x.block).join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON" }); }
  const installId = typeof body.installation_id === "string" ? body.installation_id : "";
  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!/^[0-9a-f-]{36}$/i.test(installId)) return reply(400, { error: "Invalid installation ID" });
  if (!message || message.length > 1200) return reply(400, { error: "Message must be between 1 and 1200 characters" });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const rateSalt = Deno.env.get("ARIA_RATE_LIMIT_SALT");
  if (!url || !serviceKey || !rateSalt) return reply(503, { error: "Assistant is not configured" });

  const adminDb = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: installation, error: installError } = await adminDb
    .from("zenvio_aria_installations")
    .select("id, enabled, revoked_at")
    .eq("public_install_id", installId)
    .maybeSingle();
  if (installError) return reply(503, { error: "Could not verify assistant installation" });
  if (!installation || !installation.enabled || installation.revoked_at) {
    return reply(403, { error: "This assistant is currently unavailable" });
  }

  const { data: controls, error: controlError } = await adminDb
    .from("zenvio_aria_admin_controls")
    .select("globally_enabled, locked_fields, admin_config")
    .eq("installation_id", installation.id)
    .maybeSingle();
  if (controlError) return reply(503, { error: "Could not verify assistant status" });
  if (controls?.globally_enabled === false) return reply(403, { error: "This assistant is currently unavailable" });

  const address = req.headers.get("cf-connecting-ip") ??
    (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
  const hashInput = new TextEncoder().encode(rateSalt + ":" + address);
  const hash = await crypto.subtle.digest("SHA-256", hashInput);
  const visitorHash = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("");
  const { data: allowed, error: rateError } = await adminDb.rpc("zenvio_aria_consume_rate_limit", {
    p_installation_id: installation.id,
    p_visitor_hash: visitorHash,
    p_limit: 15,
    p_window_seconds: 60,
  });
  if (rateError) return reply(503, { error: "Rate limiter unavailable" });
  if (allowed !== true) return reply(429, { error: "Please wait a moment before sending another message" });

  const { data: ownerConfig, error: configError } = await adminDb
    .from("zenvio_aria_owner_configs")
    .select("config")
    .eq("installation_id", installation.id)
    .maybeSingle();
  if (configError) return reply(503, { error: "Could not load assistant settings" });
  const config = applyAdminLocks(
    (ownerConfig?.config ?? {}) as Record<string, unknown>,
    (controls?.admin_config ?? {}) as Record<string, unknown>,
    controls?.locked_fields,
  );
  if (config.owner_enabled === false) return reply(403, { error: "This assistant has been disabled by the website owner" });
  const capabilityMessage = disabledCapability(message, config);
  if (capabilityMessage) return reply(200, { reply: capabilityMessage, mode: "capability_restricted" });

  if (config.services === false && config.recommendations === false && config.contact === false) {
    return reply(200, { reply: config.greeting ?? "Hello! How can I help you today?", mode: "greeting" });
  }

  const knowledge = typeof config.knowledge === "string" ? config.knowledge.slice(0, 12000) : "";
  const answer = findKnowledgeAnswer(message, knowledge);
  if (answer) return reply(200, { reply: answer, mode: "knowledge_match" });

  const greeting = typeof config.greeting === "string" ? config.greeting : "Hello! How can I help you today?";
  return reply(200, {
    reply: `Thanks for your question. I don't have that detail in my approved business information yet. ${greeting}`,
    mode: "safe_fallback",
  });
});
