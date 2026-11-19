
# ZENVIO ONE — Complete Module Deployment Guide

Additive implementation. Existing ZENVIO `admin_users`, `leads`, admin login and CRM records must be preserved.

This guide documents the ZENVIO ONE modules and DATA FORTRESS foundation. Do not assume that a migration has been applied until it has been verified in the existing Supabase project.

## 1. Project Files

- `one.html` — authenticated organization workspace.
- `mirror.html` — MIRROR business digital twin.
- `anticipate.html` — ANTICIPATE evidence-based business signal review.
- `swarm.html` — SWARM controlled specialist workforce and approval queue.
- `modules.html` — BLACKBOX searchable memory, WHAT IF scenario simulator and EVOLVE outcome tracker.
- `backup.html` — DATA FORTRESS owner/admin backup health dashboard.

## 2. Database Migrations

Migration files:

- `supabase/migrations/20261117_zenvio_one_foundation.sql` — organization, department, task and event foundation.
- `supabase/migrations/20261118_zenvio_owner_management.sql` — owner management and Super Admin authorization foundation.
- `supabase/migrations/20261118_zenvio_one_mirror.sql` — MIRROR profile and business records.
- `supabase/migrations/20261118_zenvio_one_anticipate.sql` — measurements and findings.
- `supabase/migrations/20261118_zenvio_one_swarm.sql` — specialist plans, approval records and secure approval transaction.
- `supabase/migrations/20261118_zenvio_one_blackbox_whatif_evolve.sql` — company memory, scenario simulation and measured improvement tables.
## DATA FORTRESS v0.1 and PRIVATE CLOUD

- `backup.html` — owner/admin backup health dashboard (read-only metadata view).
- `private-cloud.html` — company Google Drive BYOG connection and 5 GB allocation status UI (connection milestone only).
- `PRIVATE_CLOUD_SETUP.md` — Cloudflare KV binding, OAuth, secrets, deployment and verification guide.
- `supabase/migrations/20261119_zenvio_data_fortress.sql` — backup policies, destination metadata, backup run history, restore-test history and Super Admin aggregate health function.
## 3. Required Migration Order

When deployment is approved, apply each migration as a separate query in the existing Supabase project's SQL Editor, in this exact order:

1. `20261117_zenvio_one_foundation.sql`
2. `20261118_zenvio_owner_management.sql`
3. `20261118_zenvio_one_mirror.sql`
4. `20261118_zenvio_one_anticipate.sql`
5. `20261118_zenvio_one_swarm.sql`
6. `20261118_zenvio_one_blackbox_whatif_evolve.sql`
7. `20261119_zenvio_data_fortress.sql`

Do not skip migrations or assume that a migration is already installed based only on the presence of its file in GitHub.

## 4. DATA FORTRESS Database Prerequisites

Before applying `20261119_zenvio_data_fortress.sql`, verify that the existing Supabase project contains:

### Required tables

- `zenvio_organizations`
- `zenvio_organization_members`
- `zenvio_backup_policies` (created by the DATA FORTRESS migration)
- `zenvio_backup_destinations` (created by the DATA FORTRESS migration)
- `zenvio_backup_runs` (created by the DATA FORTRESS migration)
- `zenvio_restore_tests` (created by the DATA FORTRESS migration)

### Required existing functions

Verify that these functions exist and have the expected signatures:

- `public.zenvio_touch_updated_at()` — used by DATA FORTRESS update triggers.
- `public.zenvio_has_role(uuid, text[])` — used by organization owner/admin RLS policies.
- `public.zenvio_is_super_admin()` — used by the Super Admin aggregate health function.

The migration also references `auth.users` and `auth.uid()`, provided by Supabase Auth.

If any required table or function is missing, stop and review the relevant earlier migration before proceeding. Do not create replacement functions or tables blindly.

## 5. Expected ZENVIO Tables

After all relevant migrations have been verified and applied, confirm the expected tables:

### ZENVIO ONE foundation

- `zenvio_organizations`
- `zenvio_organization_members`
- `zenvio_departments`
- `zenvio_tasks`
- `zenvio_events`

### MIRROR

- `zenvio_mirror_profiles`
- `zenvio_mirror_entities`

### ANTICIPATE

- `zenvio_metric_observations`
- `zenvio_anticipate_findings`

### SWARM

- `zenvio_swarm_runs`
- `zenvio_swarm_approvals`

### BLACKBOX / WHAT IF / EVOLVE

- `zenvio_blackbox_records`
- `zenvio_whatif_scenarios`
- `zenvio_evolve_items`

### DATA FORTRESS

- `zenvio_backup_policies`
- `zenvio_backup_destinations`
- `zenvio_backup_runs`
- `zenvio_restore_tests`

This list is a verification checklist, not proof that these tables already exist.

## 6. Security Requirements

- Keep Row Level Security enabled on organization-scoped tables.
- Do not disable RLS to fix access problems.
- Do not expose a Supabase service-role key in browser code.
- Keep external provider credentials in server-side secrets.
- Keep customer data isolated by organization.
- Browser users must not be able to create or alter backup-run or restore-test results.
- Super Admin backup overview must expose aggregate operational health only, not customer file contents.
- Preserve existing ZENVIO admin login, CRM data, leads and unrelated modules.

## 7. Cloudflare Worker Deployment

Deploy updated static assets to the existing Cloudflare Worker only after reviewing the changes.

Keep existing admin and CRM files and routes intact.

Existing public URLs:

- Public site: https://zenvio-agency.haiderium213.workers.dev/
- Admin: https://zenvio-agency.haiderium213.workers.dev/admin
- Workspace: https://zenvio-agency.haiderium213.workers.dev/one.html
- MIRROR: https://zenvio-agency.haiderium213.workers.dev/mirror.html
- ANTICIPATE: https://zenvio-agency.haiderium213.workers.dev/anticipate.html
- SWARM: https://zenvio-agency.haiderium213.workers.dev/swarm.html
- BLACKBOX / WHAT IF / EVOLVE: https://zenvio-agency.haiderium213.workers.dev/modules.html
- DATA FORTRESS: https://zenvio-agency.haiderium213.workers.dev/backup.html

## 8. SWARM v0.4

1. Open `/swarm.html` and select the ZENVIO organization.
2. Choose a specialist, write a business objective and generate a reviewable task plan.
3. Submit the plan. No tasks are created until an organization owner/admin approves it.
4. Approval calls the checked `zenvio_swarm_decide_approval` database function, which validates role and creates the planned tasks atomically. Rejection creates no tasks.
5. This milestone uses deterministic templates, not a paid AI model. It does not send messages, make payments or execute external actions.

## 9. BLACKBOX, WHAT IF and EVOLVE v0.5

- BLACKBOX stores searchable text records and source metadata; file upload and automatic email ingestion are not included.
- WHAT IF calculates scenario arithmetic from user-entered baseline values and assumptions; it is not a predictive model.
- EVOLVE records recommendations and measured outcomes; it does not automatically change business settings.

## 10. First ANTICIPATE Test

1. Sign in and select the ZENVIO organization.
2. Add at least two comparable dated revenue observations with the same currency and comparable period lengths, and/or expense observations. Include accurate source descriptions.
3. Keep real tasks and due dates updated in the workspace.
4. Run analysis and inspect evidence on each finding.
5. Acknowledge, resolve or dismiss findings after human review.

ANTICIPATE v0.3 uses deterministic rules. It detects overdue/urgent-blocked tasks and significant revenue declines/expense increases when comparable observations exist. It flags missing measurements. It is not an AI forecaster and does not claim causes. Results depend on source data quality. ANTICIPATE is not yet connected to accounting, CRM or external business systems automatically.

## 11. DATA FORTRESS v0.1 — Implementation Boundary

The first DATA FORTRESS milestone adds tenant-scoped backup control metadata and a read-only owner/admin dashboard.

It does not currently:

- Run scheduled backups.
- Connect an external backup storage provider.
- Upload or download customer backup files.
- Verify backup checksums.
- Perform automated restores.
- Guarantee RPO or RTO targets.

A backup must only be described as verified after a separate backup worker has created it, uploaded it to independent storage, verified its checksum and completed a successful restore test.

Do not enable a backup policy or describe a destination as connected until those capabilities have actually been implemented and tested.

The Super Admin RPC returns aggregate backup health only and never customer file contents.

## 12. Deployment and Safety Status

Before production activation:

1. Review the migration files.
2. Verify the existing Supabase migration history.
3. Verify all required tables and helper functions.
4. Confirm organization-scoped RLS policies.
5. Review Cloudflare Worker bindings and secrets.
6. Test the modules without modifying existing CRM records.
7. Confirm that no paid service or billing upgrade is required.

## PRIVATE CLOUD — Google Drive BYOG milestone

- Company owner/admin connects the company's Google account using Google OAuth.
- The Worker creates a dedicated `ZENVIO PRIVATE CLOUD` folder in that company's Google Drive.
- Encrypted refresh-token credentials and minimal connection metadata are held in Cloudflare Workers KV; company files remain in the company's Drive.
- The 5 GB allocation is an application target within the company's existing Google Drive capacity, not additional Google storage.
- This milestone does not yet upload or download files, run automated backups, restore files, or enforce the 5 GB cap.
- See `PRIVATE_CLOUD_SETUP.md` before configuring or deploying.

Do not execute database migrations, change Cloudflare billing plans, or merge deployment changes without explicit approval.