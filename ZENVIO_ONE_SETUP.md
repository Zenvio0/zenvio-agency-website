# ZENVIO ONE — Foundation setup

This is an additive foundation integrated into the existing ZENVIO admin project.

## What was added

- `one.html`: authenticated ZENVIO ONE foundation workspace.
- `supabase/migrations/20261117_zenvio_one_foundation.sql`: additive database migration.
- `admin.html`: navigation link to ZENVIO ONE.

The existing `admin_users`, `leads`, and existing admin login/CRM code are not modified by the migration. No existing records are deleted or rewritten.

## Apply the database migration

1. Open the Supabase project already used by ZENVIO.
2. Open **SQL Editor** and create a new query.
3. Copy the complete contents of `supabase/migrations/20261117_zenvio_one_foundation.sql`.
4. Run it once.
5. Confirm these tables exist:
   - `zenvio_organizations`
   - `zenvio_organization_members`
   - `zenvio_departments`
   - `zenvio_tasks`
   - `zenvio_events`

The migration enables Row Level Security and organization-scoped policies. Do not disable RLS or put a service-role key in browser code.

## Deploy the static files

Deploy the repository's updated static assets to the existing Cloudflare Worker/static-assets setup using the same deployment method already used for the agency site.

After deployment, open:

- Existing admin: `https://zenvio-agency.haiderium213.workers.dev/admin`
- ZENVIO ONE: `https://zenvio-agency.haiderium213.workers.dev/one.html`

The Admin navigation now contains a **ZENVIO ONE** link.

## First test

1. Sign in with an existing Supabase Auth account.
2. Create an organization (for the first internal test, use ZENVIO).
3. Add departments such as Sales, Operations, Finance.
4. Create a task and change its status.
5. Confirm the activity timeline records the changes.

## Current scope / limitations

This is Foundation v0.1: organization, department, task, and append-only activity tracking. It does not yet contain autonomous AI, predictive analytics, document ingestion, or what-if forecasting. Those modules will be developed after the foundation is deployed and verified.

The browser app uses only the existing Supabase publishable key. Authorization is enforced by Supabase Auth and RLS. Never expose a Supabase service-role key in frontend code.
