# ZENVIO ONE — Foundation, MIRROR and ANTICIPATE setup

Additive implementation. Existing ZENVIO `admin_users`, `leads`, admin login and CRM records are preserved.

## Files
- `one.html` — authenticated organization workspace.
- `mirror.html` — MIRROR business digital twin.
- `anticipate.html` — ANTICIPATE evidence-based business signal review.
- `supabase/migrations/20261117_zenvio_one_foundation.sql` — organization, department, task and event foundation.
- `supabase/migrations/20261118_zenvio_one_mirror.sql` — MIRROR profile and business records.
- `supabase/migrations/20261118_zenvio_one_anticipate.sql` — measurements and findings.

## Database migration order
In the existing Supabase project SQL Editor, run each migration as a separate query, in this order:
1. `20261117_zenvio_one_foundation.sql`
2. `20261118_zenvio_one_mirror.sql`
3. `20261118_zenvio_one_anticipate.sql`

Confirm these tables exist:
- `zenvio_organizations`, `zenvio_organization_members`, `zenvio_departments`, `zenvio_tasks`, `zenvio_events`
- `zenvio_mirror_profiles`, `zenvio_mirror_entities`
- `zenvio_metric_observations`, `zenvio_anticipate_findings`

Migrations are additive and enable organization-scoped RLS. Do not disable RLS or expose a service-role key in browser code.

## Deploy
Deploy the updated repository static assets to the existing Cloudflare Worker. Keep existing admin and CRM files.
- Public site: https://zenvio-agency.haiderium213.workers.dev/
- Admin: https://zenvio-agency.haiderium213.workers.dev/admin
- Workspace: https://zenvio-agency.haiderium213.workers.dev/one.html
- MIRROR: https://zenvio-agency.haiderium213.workers.dev/mirror.html
- ANTICIPATE: https://zenvio-agency.haiderium213.workers.dev/anticipate.html

## First ANTICIPATE test
1. Sign in and select the ZENVIO organization.
2. Add at least two comparable dated revenue observations with the same currency and comparable period lengths, and/or expense observations. Include accurate source descriptions.
3. Keep real tasks and due dates updated in the workspace.
4. Run analysis and inspect evidence on each finding.
5. Acknowledge, resolve or dismiss findings after human review.

ANTICIPATE v0.3 uses deterministic rules. It detects overdue/urgent-blocked tasks and significant revenue declines/expense increases when comparable observations exist. It flags missing measurements. It is not an AI forecaster and does not claim causes. Results depend on source data quality. ANTICIPATE is not yet connected to accounting, CRM or external business systems automatically.
