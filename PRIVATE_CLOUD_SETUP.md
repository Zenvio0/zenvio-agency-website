# ZENVIO PRIVATE CLOUD — Google Drive BYOG setup

## Current milestone
This branch adds:
- `private-cloud.html`: signed-in company workspace screen.
- `_worker.js`: Google OAuth authorization-code flow, Drive folder creation, encrypted refresh-token storage, connection status, folder usage inspection, and disconnect/revoke.
- `one.html`: navigation entry.

Customer documents are not uploaded to ZENVIO by this milestone. The Worker stores only encrypted Google refresh-token credentials and minimal connection metadata in Cloudflare Workers KV. The actual company files remain in the customer's Google Drive.

## Important boundary
- The 5 GB figure is an application allocation target, not additional Google storage.
- The company must have enough free space in its own Google account.
- This milestone creates the company's `ZENVIO PRIVATE CLOUD` Drive folder and reads its contents' metadata.
- File upload, download, automated backup, restore, and hard enforcement of the 5 GB ceiling are NOT implemented yet.
- Do not describe this as an active backup service until upload, integrity verification, and restore testing are implemented.
- Disconnect revokes the OAuth refresh token and removes ZENVIO's encrypted credential. It does not delete customer files/folder.

## Cloudflare setup (Workers Free KV)
1. In Cloudflare, open Workers & Pages → Storage & databases → Workers KV.
2. Create one namespace named `zenvio-private-cloud`.
3. Open Workers & Pages → `zenvio-agency` → Settings → Bindings.
4. Add a KV namespace binding:
   - Variable name: `PRIVATE_CLOUD_KV`
   - KV namespace: `zenvio-private-cloud`
5. Do not switch the account or Worker to a paid plan for this setup. The Workers Free plan includes limited KV usage; when free limits are reached, operations fail until the limit resets rather than automatically adding paid usage. Review the current account usage model before enabling.

## Worker secrets
Add these Worker secrets under Settings → Variables and Secrets:
- `GOOGLE_CLIENT_ID` — OAuth Web application client ID.
- `GOOGLE_CLIENT_SECRET` — OAuth client secret.
- `PRIVATE_CLOUD_ENCRYPTION_KEY` — base64-encoded random 32-byte AES-GCM key.

Generate an encryption key locally in Windows PowerShell (Node.js required):
```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```
Copy the output directly into the secret value. Never commit it, paste it into chat, or put it in HTML. Keep a secure offline recovery copy; losing this key makes stored credentials unreadable.

## Google Cloud OAuth setup
1. Open Google Cloud Console and create/select a project owned by ZENVIO.
2. Enable **Google Drive API**.
3. Configure the OAuth consent screen / Google Auth Platform.
4. Create an OAuth Client ID of type **Web application**.
5. Add this exact Authorized redirect URI:
   `https://zenvio-agency.haiderium213.workers.dev/api/private-cloud/callback`
6. Add the OAuth client ID and secret to the Cloudflare Worker secrets above.
7. During initial testing, add the test Gmail accounts as test users if the app is in Testing status.

Requested OAuth scopes:
- `openid`
- `email`
- `https://www.googleapis.com/auth/drive.file`

The app requests offline access so the Worker can refresh access without the user being present. Google may require OAuth app verification before general public use. Apps left in Testing can have refresh-token lifetime restrictions; do not treat a test-mode connection as production-ready. Check Google's current OAuth verification and testing requirements before onboarding real customers.

Official references:
- https://developers.google.com/identity/protocols/oauth2/web-server
- https://developers.google.com/workspace/drive/api/guides/api-specific-auth

## Deploy and test
1. Confirm the KV binding and all three secrets exist before deployment.
2. Deploy the same static-assets Worker with `_worker.js` and the full repository asset directory. Do not replace it with a script-only Worker.
3. Open `/private-cloud.html`, sign in to ZENVIO ONE, and select the company.
4. A company owner/admin selects **Connect Google Drive** and approves the requested permissions.
5. Verify that the Google Drive contains a folder named `ZENVIO PRIVATE CLOUD`.
6. Confirm the account email and folder usage appear in the ZENVIO page.
7. Test Disconnect. Confirm the ZENVIO page reports disconnected and the customer's Drive folder/files remain present.
8. Do not onboard customers until these tests pass.

## No-billing safeguards
- Do not activate Cloudflare R2.
- Do not upgrade Cloudflare Workers to a paid plan.
- Keep KV use within the Free plan limits. Cloudflare's published Free KV limits include 100,000 reads/day, 1,000 writes/day, 1,000 deletes/day, and 1 GB stored data. Exceeding a Free limit causes operations to fail until reset.
- No Google Cloud billing account is required for this OAuth/Drive API connection setup itself, but verify any console prompts and do not enable paid products.
