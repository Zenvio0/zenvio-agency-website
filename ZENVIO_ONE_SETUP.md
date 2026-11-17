# ZENVIO ONE — Foundation and MIRROR setup

This is an additive extension of the existing ZENVIO project. Existing `admin_users`, `leads`, admin login, and CRM records are not altered or deleted.

## Added files

- `one.html` — authenticated ZENVIO ONE workspace.
- `mirror.html` — authenticated MIRROR business digital-twin workspace.
- `supabase/migrations/20261117_zenvio_one_foundation.sql` — organization, department, task and event foundation.
- `supabase/migrations/20261118_zenvio_one_mirror.sql` — MIRROR profile and business-record schema.

## Apply database migrations

In the existing Supabase project, open SQL Editor and run these files as separate queries, in this order:

1. `supabase/migrations/20261117_zenvio_one_foundation.sql`
2. `supabase/migrations/20261118_zenvio_one_mirror.sql`

Confirm these tables exist:
- `zenvio_organizations`
- `zenvio_organization_members`
- `zenvio_departments`
- `zenvio_tasks`
- `zenvio_events`
- `zenvio_mirror_profiles`
- `zenvio_mirror_entities`

Both migrations are additive and enable organization-scoped Row Level Security. Do not disable RLS or put a service-role key in browser code.

## Deploy static assets

Deploy the updated repository static files to the existing Cloudflare Worker/static-assets setup. Keep the existing admin and CRM files.

- Public site: https://zenvio-agency.haiderium213.workers.dev/
- Existing admin: https://zenvio-agency.haiderium213.workers.dev/admin
- ZENVIO ONE workspace: https://zenvio-agency.haiderium213.workers.dev/one.html
- MIRROR: https://zenvio-agency.haiderium213.workers.dev/mirror.html

## First MIRROR test

1. Sign in with an existing Supabase Auth account.
2. Create an organization in `one.html` if one does not already exist.
3. Open `mirror.html` and select that organization.
4. Save the business profile and add sample records in People, Customers, Suppliers, Offerings, Workflows, Tools, Goals and Assets.
5. Confirm records remain visible after refresh.

MIRROR v0.2 stores structured, user-provided business facts. It does not invent facts, make predictions or autonomously operate the business. ANTICIPATE, SWARM, BLACKBOX, WHAT IF and EVOLVE are later milestones.

The browser app uses only the Supabase publishable key. Authorization is enforced by Supabase Auth and RLS.
