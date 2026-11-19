# ZENVIO ONE — Complete module deployment guide

Additive implementation. Existing ZENVIO `admin_users`, `leads`, admin login and CRM records are preserved.

## Files
- `one.html` — authenticated organization workspace.
- `mirror.html` — MIRROR business digital twin.
- `anticipate.html` — ANTICIPATE evidence-based business signal review.
- `swarm.html` — SWARM controlled specialist workforce and approval queue.
- `modules.html` — BLACKBOX searchable memory, WHAT IF scenario simulator and EVOLVE outcome tracker.
- `supabase/migrations/20261117_zenvio_one_foundation.sql` — organization, department, task and event foundation.
- `supabase/migrations/20261118_zenvio_one_mirror.sql` — MIRROR profile and business records.
- `supabase/migrations/20261118_zenvio_one_anticipate.sql` — measurements and findings.
- `supabase/migrations/20261118_zenvio_one_swarm.sql` — specialist plans, approval records and secure approval transaction.
- `supabase/migrations/20261118_zenvio_one_blackbox_whatif_evolve.sql` — company memory, scenario simulation and measured improvement tables.

## DATA FORTRESS v0.1
- `backup.html` — owner/admin backup health dashboard (read-only metadata view).
- `supabase/migrations/20261119_zenvio_data_fortress.sql` — backup policies, destination metadata, backup run history, restore-test history and Super Admin aggregate health function.
- This milestone creates the secure control-plane schema only. It does not run backups, connect a storage provider, or activate an RPO/RTO guarantee. Credentials must be configured as server-side Worker secrets; never store provider credentials in Supabase rows or browser code.

## Database migration order
In the existing Supabase project SQL Editor, run each migration as a separate query, in this order:
1. `20261117_zenvio_one_foundation.sql`
2. `20261118_zenvio_one_mirror.sql`
3. `20261118_zenvio_one_anticipate.sql`
4. `20261118_zenvio_one_swarm.sql`
5. `20261118_zenvio_one_blackbox_whatif_evolve.sql`
6. `20261119_zenvio_data_fortress.sql`

Confirm these tables exist:
- `zenvio_organizations`, `zenvio_organization_members`, `zenvio_departments`, `zenvio_tasks`, `zenvio_events`
- `zenvio_mirror_profiles`, `zenvio_mirror_entities`
- `zenvio_metric_observations`, `zenvio_anticipate_findings`
- `zenvio_swarm_runs`, `zenvio_swarm_approvals`
- `zenvio_blackbox_records`, `zenvio_whatif_scenarios`, `zenvio_evolve_items`

Migrations are additive and enable organization-scoped RLS. Do not disable RLS or expose a service-role key in browser code.

## Deploy
Deploy the updated repository static assets to the existing Cloudflare Worker. Keep existing admin and CRM files.
- Public site: https://zenvio-agency.haiderium213.workers.dev/
- Admin: https://zenvio-agency.haiderium213.workers.dev/admin
- Workspace: https://zenvio-agency.haiderium213.workers.dev/one.html
- MIRROR: https://zenvio-agency.haiderium213.workers.dev/mirror.html
- ANTICIPATE: https://zenvio-agency.haiderium213.workers.dev/anticipate.html
- SWARM: https://zenvio-agency.haiderium213.workers.dev/swarm.html
- BLACKBOX / WHAT IF / EVOLVE: https://zenvio-agency.haiderium213.workers.dev/modules.html
- DATA FORTRESS: https://zenvio-agency.haiderium213.workers.dev/backup.html

## SWARM v0.4
1. Open `/swarm.html` and select the ZENVIO organization.
2. Choose a specialist, write a business objective and generate a reviewable task plan.
3. Submit the plan. No tasks are created until an organization owner/admin approves it.
4. Approval calls the checked `zenvio_swarm_decide_approval` database function, which validates role and creates the planned tasks atomically. Rejection creates no tasks.
5. This milestone uses deterministic templates, not a paid AI model. It does not send messages, make payments or execute external actions.

## BLACKBOX, WHAT IF and EVOLVE v0.5
- BLACKBOX stores searchable text records and source metadata; file upload and automatic email ingestion are not included.
- WHAT IF calculates scenario arithmetic from user-entered baseline values and assumptions; it is not a predictive model.
- EVOLVE records recommendations and measured outcomes; it does not automatically change business settings.

## First ANTICIPATE test
1. Sign in and select the ZENVIO organization.
2. Add at least two comparable dated revenue observations with the same currency and comparable period lengths, and/or expense observations. Include accurate source descriptions.
3. Keep real tasks and due dates updated in the workspace.
4. Run analysis and inspect evidence on each finding.
5. Acknowledge, resolve or dismiss findings after human review.

ANTICIPATE v0.3 uses deterministic rules. It detects overdue/urgent-blocked tasks and significant revenue declines/expense increases when comparable observations exist. It flags missing measurements. It is not an AI forecaster and does not claim causes. Results depend on source data quality. ANTICIPATE is not yet connected to accounting, CRM or external business systems automatically.


## DATA FORTRESS implementation boundary
The first milestone adds tenant-scoped backup control metadata and a read-only owner/admin dashboard. A verified backup must be created by a separate scheduled backup worker, written to an independent storage account, checksum-verified, and followed by a successful restore test. Do not set a policy to enabled or describe a destination as connected until those steps are implemented and tested. The Super Admin RPC returns aggregate backup health only and never customer file contents.
