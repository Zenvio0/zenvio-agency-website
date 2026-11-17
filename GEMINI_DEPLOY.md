# ZENVIO ONE — Gemini free-tier deployment

## What this adds
- `_worker.js`: same-origin API, Supabase session and organization membership checks, Gemini primary/backup routing, local rule-based fallback.
- `intelligence.html`: private signed-in AI chat workspace.
- `wrangler.toml`: Cloudflare Workers Static Assets configuration.

Existing HTML pages are served through the Cloudflare `ASSETS` binding. The Worker handles only `/api/*`; all other paths fall through to static assets.

## Security first
A Gemini API key was pasted into a chat. Revoke that exposed key in Google AI Studio and create a new one. Never commit a key or paste it into HTML.

In Cloudflare Dashboard:
1. Workers & Pages → `zenvio-agency` → Settings → Variables and Secrets.
2. Add a secret named `GEMINI_API_KEY`.
3. Paste the newly generated key into the secret value and save.
4. Deploy the updated Worker and static assets.

Do not add a Supabase service-role key. This Worker uses the existing Supabase publishable key plus the signed-in user's bearer token to verify the user's session and organization membership.

## Models and no-paid-fallback policy
- These model IDs are listed with Free Tier Standard token pricing in Google's current pricing documentation. Keep the Google AI Studio project on Free Tier and do not link a paid Cloud Billing account. Model selection alone cannot prevent charges if the project is upgraded to a paid tier.
- Primary: `gemini-3.1-flash-lite`
- Backup: `gemini-2.5-flash-lite`
- No paid model, Google Search grounding, Maps, or paid tool is called.
- If both models are unavailable, the endpoint returns a clearly labelled local rule-based fallback.
- The backup is attempted only when the primary is rate-limited, quota-limited, unavailable, or returns a server error.
- Free quotas are project/model-specific and not guaranteed. The model availability and pricing can change; verify the active Free Tier in Google AI Studio.

## Deploy
This repository is configured for Cloudflare Workers Static Assets with `directory = "."` and `binding = "ASSETS"`.
If deploying with Wrangler from the repository root:
```bash
npx wrangler deploy
```
If using the Cloudflare dashboard upload flow, use the same static asset root and include `_worker.js`; make sure the deployment has the `ASSETS` binding configured for the uploaded assets. Do not replace the existing worker with a script-only deployment that omits static assets.

## Test
- `/api/health` should return the service status and model order.
- Sign in at `/intelligence.html`, select an organization and send a test prompt.
- The response reports either `gemini` (with model name) or `local_fallback`.

## Important limitations
This is a secure chat endpoint, not yet an automatic connector to all company records or external web research. The assistant only knows the context provided in the chat prompt. Do not send sensitive personal, customer, financial or confidential information to a Gemini Free Tier project unless you accept Google's Free Tier data-use terms.
