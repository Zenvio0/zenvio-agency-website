const SUPABASE_URL = "https://bohblrqrkkfmqwvtulcs.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_kDAD7Eo3LDNKO7T18niELA_qGFdq8D9";
const ANT_LING_MODEL = "Ling-3.2-flash";
const PRIMARY_MODEL = "gemini-3.1-flash-lite";
const BACKUP_MODEL = "gemini-2.5-flash-lite";
const MAX_PROMPT_CHARS = 12000;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
  });
}
function isQuotaOrTemporary(status, body) {
  const s = String(body || "").toLowerCase();
  return status === 429 || status >= 500 || s.includes("resource_exhausted") ||
    s.includes("quota") || s.includes("rate limit") || s.includes("model not found");
}
async function verifyMember(request, organizationId) {
  const auth = request.headers.get("authorization") || "";
  if (!auth.startsWith("Bearer ")) return { ok: false, status: 401, error: "Sign in required." };
  const token = auth.slice(7);
  const userRes = await fetch(SUPABASE_URL + "/auth/v1/user", {
    headers: { apikey: SUPABASE_PUBLISHABLE_KEY, authorization: "Bearer " + token }
  });
  if (!userRes.ok) return { ok: false, status: 401, error: "Your session is invalid or expired. Sign in again." };
  const user = await userRes.json();
  if (!user?.id) return { ok: false, status: 401, error: "Authentication required." };
  const url = SUPABASE_URL + "/rest/v1/zenvio_organization_members?select=organization_id,user_id&organization_id=eq." +
    encodeURIComponent(organizationId) + "&user_id=eq." + encodeURIComponent(user.id) + "&limit=1";
  const memberRes = await fetch(url, {
    headers: { apikey: SUPABASE_PUBLISHABLE_KEY, authorization: "Bearer " + token }
  });
  if (!memberRes.ok) return { ok: false, status: 403, error: "Could not verify organization membership." };
  const rows = await memberRes.json();
  if (!Array.isArray(rows) || rows.length === 0) return { ok: false, status: 403, error: "You are not a member of this organization." };
  return { ok: true, user };
}
function localFallback(message, moduleName) {
  const clean = message.trim();
  const words = clean.split(/\s+/).filter(Boolean);
  const topic = clean.length > 180 ? clean.slice(0, 180) + "…" : clean;
  return [
    "ZENVIO LOCAL MODE — Gemini free quota is currently unavailable.",
    "",
    "Request received: " + topic,
    "",
    "Suggested working structure:",
    "1. Define the objective and the decision that must be made.",
    "2. Separate confirmed facts from assumptions; do not treat missing data as fact.",
    "3. Identify the main risks, dependencies and constraints.",
    "4. Choose one measurable next action, assign an owner and a due date.",
    "",
    "This is a rule-based fallback, not a generative AI analysis. Add relevant company figures or records to get a more useful deterministic review.",
    "Module: " + (moduleName || "general") + " · Words received: " + words.length
  ].join("\n");
}
async function callGemini(model, apiKey, prompt) {
  const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" +
    encodeURIComponent(model) + ":generateContent?key=" + encodeURIComponent(apiKey);
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.35, maxOutputTokens: 1800 }
    })
  });
  const raw = await response.text();
  if (!response.ok) return { ok: false, status: response.status, body: raw.slice(0, 1800) };
  let parsed;
  try { parsed = JSON.parse(raw); } catch { return { ok: false, status: 502, body: "Invalid model response." }; }
  const answer = parsed?.candidates?.[0]?.content?.parts?.map(p => p.text || "").join("").trim();
  if (!answer) return { ok: false, status: 502, body: "The model returned no text." };
  return { ok: true, answer };
}
async function callAntLing(apiKey, systemPrompt, message) {
  const response = await fetch("https://api.ant-ling.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "authorization": "Bearer " + apiKey
    },
    body: JSON.stringify({
      model: ANT_LING_MODEL,
      stream: false,
      temperature: 0.35,
      max_tokens: 1800,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: message }
      ]
    })
  });
  const raw = await response.text();
  if (!response.ok) return { ok: false, status: response.status, body: raw.slice(0, 1800) };
  let parsed;
  try { parsed = JSON.parse(raw); } catch { return { ok: false, status: 502, body: "Invalid Ant Ling response." }; }
  const answer = parsed?.choices?.[0]?.message?.content;
  const textAnswer = typeof answer === "string" ? answer.trim() :
    Array.isArray(answer) ? answer.map(part => part?.text || "").join("").trim() : "";
  if (!textAnswer) return { ok: false, status: 502, body: "Ant Ling returned no text." };
  return { ok: true, answer: textAnswer };
}
async function handleIntelligence(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ error: "Request body must be valid JSON." }, 400); }
  const message = typeof body.message === "string" ? body.message.trim() : "";
  const organizationId = typeof body.organizationId === "string" ? body.organizationId : "";
  const moduleName = typeof body.module === "string" ? body.module.slice(0, 40) : "general";
  if (!message || message.length > MAX_PROMPT_CHARS) return json({ error: "Message must contain 1–12000 characters." }, 400);
  if (!/^[0-9a-f-]{36}$/i.test(organizationId)) return json({ error: "A valid organization is required." }, 400);
  const membership = await verifyMember(request, organizationId);
  if (!membership.ok) return json({ error: membership.error }, membership.status);

  const systemPrompt = "You are ZENVIO ONE, a careful business intelligence assistant. " +
    "Help with business planning, operations, finance, sales, marketing, customer support, strategy and analysis. " +
    "Never invent company facts, metrics, sources, events or research. Clearly label assumptions and unknowns. " +
    "If the user has not supplied company data, ask for it or give a general framework. " +
    "Do not claim to have accessed live websites, email, databases or external systems. " +
    "Do not send messages, make payments, change records or execute consequential actions. " +
    "Give practical, structured answers. The selected workspace module is: " + moduleName + ".";
  const prompt = systemPrompt + "\n\nUser request:\n" + message;
  const failures = [];
  if (env.ANT_LING_API_KEY) {
    const ling = await callAntLing(env.ANT_LING_API_KEY, systemPrompt, message);
    if (ling.ok) return json({ answer: ling.answer, mode: "ant_ling", model: ANT_LING_MODEL, fallback: false });
    failures.push({ provider: "ant_ling", model: ANT_LING_MODEL, status: ling.status });
  }
  const geminiKey = env.GEMINI_API_KEY;
  if (geminiKey) {
    for (const model of [PRIMARY_MODEL, BACKUP_MODEL]) {
      const result = await callGemini(model, geminiKey, prompt);
      if (result.ok) return json({ answer: result.answer, mode: "gemini", model, fallback: true, attempted: failures });
      failures.push({ provider: "gemini", model, status: result.status });
      if (!isQuotaOrTemporary(result.status, result.body)) break;
    }
  }
  return json({
    answer: localFallback(message, moduleName),
    mode: "local_fallback",
    reason: "Ant Ling and Gemini are unavailable or their secrets are not configured.",
    attempted: failures
  });
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith("/api/")) {
      const origin = request.headers.get("origin");
      if (origin) {
        try { if (new URL(origin).host !== url.host) return json({ error: "Origin not allowed." }, 403); }
        catch { return json({ error: "Invalid origin." }, 403); }
      }
      if (request.method === "OPTIONS") return new Response(null, {
        status: 204,
        headers: { "access-control-allow-origin": origin || url.origin, "access-control-allow-methods": "GET, POST, OPTIONS", "access-control-allow-headers": "authorization, content-type", "vary": "Origin" }
      });
      if (url.pathname === "/api/health" && request.method === "GET") {
        return json({ service: "ZENVIO ONE Intelligence", status: "online", ai: env.ANT_LING_API_KEY ? "ant_ling_primary" : (env.GEMINI_API_KEY ? "gemini_primary" : "local_fallback"), primary: ANT_LING_MODEL, backup: PRIMARY_MODEL + " → " + BACKUP_MODEL, providers: { antLing: !!env.ANT_LING_API_KEY, gemini: !!env.GEMINI_API_KEY } });
      }
      if (url.pathname === "/api/intelligence" && request.method === "POST") {
        try { return await handleIntelligence(request, env); }
        catch (error) { return json({ error: "Intelligence service error.", detail: String(error?.message || error) }, 500); }
      }
      return json({ error: "API route not found." }, 404);
    }
    if (env.ASSETS?.fetch) return env.ASSETS.fetch(request);
    return new Response("Static asset binding ASSETS is not configured. See GEMINI_DEPLOY.md.", { status: 503 });
  }
};