# Creative Studio — Backend Architecture & Security Plan

Status: design artifact only. No database schema or production service has been changed.

## Current verified foundation

- Supabase project: `bohblrqrkkfmqwvtulcs`.
- Existing organization membership table: `public.zenvio_organization_members`.
- Existing helpers observed in policies: `zenvio_is_member(uuid)`, `zenvio_has_role(uuid,text[])`, and `zenvio_is_super_admin()`.
- Existing `zenvio_aria_conversations` and `zenvio_aria_messages` tables are already present and have RLS policies.
- Existing `zenvio_workspace_modules` stores module-level organization configuration. It is not a suitable multi-project website store.
- Current Creative Studio project library uses browser localStorage. It is a prototype and does not sync across devices.
- Existing public browser key is a publishable key. Never put a service-role/secret key in HTML.

## Target data model

### 1. `zenvio_creative_projects`

One row per generated website project.

- `id` UUID primary key
- `organization_id` UUID → `zenvio_organizations.id`
- `created_by` UUID → `auth.users.id`
- `name` text
- `business_type` text
- `project_data` JSONB (pages, theme, page order, editable content)
- `status` text with constrained values (draft, active, archived)
- `created_at`, `updated_at`

Access: authenticated organization members can read projects; organization owners/admins can create, update and archive. RLS must check membership/role for every operation.

### 2. `zenvio_aria_installations`

One ARIA installation per customer website/project.

- `id` UUID primary key
- `project_id` UUID unique → `zenvio_creative_projects.id`
- `organization_id` UUID
- `public_install_id` UUID unique, safe to embed in a website (identifier, not an authorization secret)
- `enabled` boolean
- `revoked_at` timestamptz nullable
- `owner_config` JSONB (greeting, persona, knowledge base, allowed capabilities, voice preference)
- `admin_config` JSONB (ZENVIO-controlled settings)
- `admin_locked_fields` text[] (fields clients cannot override)
- `created_at`, `updated_at`

The public identifier is not a bearer secret. Public chat requests must go through an Edge Function that checks installation status and applies server-side rate limits. Do not expose private knowledge/configuration through a public SELECT policy.

### 3. `zenvio_aria_audit_events`

Append-only record of ownership and control changes.

- `id` UUID primary key
- `organization_id` UUID
- `project_id` UUID nullable
- `installation_id` UUID nullable
- `actor_user_id` UUID nullable
- `actor_scope` text (owner, super_admin, system)
- `action` text
- `details` JSONB
- `created_at` timestamptz

Owners can read only their organization’s audit events. Client browser code must not be able to insert privileged/system events or update/delete audit history. Super Admin events are written by a server-side function after verifying the caller.

## Security boundaries

1. RLS enabled on every new public table.
2. Organization membership and owner/admin checks use existing server-side database helpers; do not trust client-supplied organization IDs.
3. Owner writes are limited to owner-editable fields. Admin locks, global enable/disable, revocation, and ownership recovery are not writable by the browser.
4. Super Admin operations run through a server-side Edge Function. It validates the signed-in user against `zenvio_is_super_admin()` before using privileged credentials.
5. The Supabase service-role/secret key is never included in HTML, JavaScript bundles, generated customer websites, or public environment variables.
6. A revoked/disabled installation is rejected by the public ARIA endpoint even if the customer still has an old embed snippet.
7. Audit records are append-only from application roles.
8. Public ARIA chat has input length limits, rate limiting, origin checks as an additional signal (not sole authentication), and no unrestricted database access.

## Planned Edge Function surface

- `creative-projects`: authenticated CRUD using the caller's JWT and RLS.
- `aria-public-chat`: accepts public installation ID and visitor message; checks enabled/revoked state; loads only approved public knowledge; enforces limits; calls a configured model provider if one is available.
- `aria-admin`: authenticated Super Admin actions only; validates `zenvio_is_super_admin()`; enable/disable/revoke/restore, change protected config, and append audit event.
- `aria-owner-config`: owner/admin configuration updates; never accepts admin-only fields.

## Implementation sequence

1. Finalize and review SQL migration in a Supabase development database.
2. Run Supabase security advisors and test positive + negative RLS cases (member, owner, unrelated user, Super Admin, anonymous).
3. Implement and test Edge Functions without deploying them to production.
4. Add cloud project save/open to Creative Studio behind a feature flag; retain local export as fallback.
5. Add customer embed code using `public_install_id`, with no secret.
6. Add Super Admin installation manager and audit timeline.
7. Only after explicit approval: apply production migration, deploy functions, and release the UI.

## Not implemented yet

- No migration has been applied.
- No Edge Function has been deployed.
- No public AI endpoint is active.
- No website installation has been created or revoked.
- The current browser-local project library remains the only working save mechanism until the backend is reviewed and built.
