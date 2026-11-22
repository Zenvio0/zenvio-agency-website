# Creative Studio — Backend Architecture & Security Plan

Status: design artifact only. No database schema or production service has been changed.

## Current verified foundation

- Supabase project: `bohblrqrkkfmqwvtulcs`.
- Existing organization membership table: `public.zenvio_organization_members`.
- Existing helpers observed in policies: `zenvio_is_member(uuid)`, `zenvio_has_role(uuid,text[])`, and `zenvio_is_super_admin()`.
- Existing `zenvio_aria_conversations` and `zenvio_aria_messages` tables are already present and have RLS policies.
- Existing `zenvio_workspace_modules` stores module-level organization configuration. It is not a suitable multi-project website store.
- Creative Studio now contains a cloud save/load/delete code path for `zenvio_creative_projects`, with localStorage fallback. It remains dormant until the migration is reviewed/applied and the new public tables are exposed to the Supabase Data API.
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
- `created_at`, `updated_at`

Installation status and revocation are server-controlled. Owners cannot re-enable a globally disabled or revoked installation from browser code.

### 3. `zenvio_aria_owner_configs`

Owner-editable visitor-facing settings kept separate from protected controls.

- `installation_id` UUID primary key
- `organization_id` UUID
- `config` JSONB (greeting, persona, knowledge base, allowed capabilities, voice preference)
- `updated_at`

Owners/admins can manage only installations belonging to their organization. The public chat function reads the approved config server-side; no public SELECT access is granted.

### 4. `zenvio_aria_admin_controls`

ZENVIO-only controls kept separate from owner settings.

- `installation_id` UUID primary key
- `globally_enabled` boolean
- `locked_fields` text[]
- `admin_config` JSONB
- `revoked_by` UUID nullable
- `updated_at`

No authenticated browser policies are granted. Only the trusted Super Admin Edge Function can change these controls.

### 5. `zenvio_aria_audit_events`

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

1. Finalize and review SQL migration in an isolated Supabase development project/branch.
2. Confirm the new `public` tables are explicitly enabled for the Supabase Data API. Since the 2026 Data API rollout, newly created public tables may not be automatically exposed; SQL `GRANT` statements and RLS do not by themselves switch on API exposure.
3. Run Supabase security advisors and test positive + negative RLS cases (member, owner, unrelated user, Super Admin, anonymous).
4. Implement and test Edge Functions without deploying them to production.
5. Complete installation creation, owner configuration UI, and Super Admin installation manager/audit timeline.
6. Add customer embed code using `public_install_id`, with no secret.
7. Only after explicit approval: apply production migration, deploy functions, and release the UI.

## Current implementation status

- A draft migration now defines project storage, ARIA installations, separate owner/admin configuration, audit events, and rate limiting. It has not been applied or tested against a development database.
- Edge Function source exists for Super Admin actions and public ARIA chat; neither function is deployed.
- Public ARIA currently uses deterministic keyword matching, not a generative AI model or voice engine.
- The installation creation UI, owner configuration UI, Super Admin installation manager, and end-to-end browser tests remain incomplete.
- Cloud project save/load/delete is coded with local fallback, but it cannot work until the migration is applied in a test environment and Data API exposure is configured.
