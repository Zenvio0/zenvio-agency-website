# ZENVIO ONE — Universal Industry & Workspace Engine

## Purpose

The Universal Industry Engine configures a company's initial ZENVIO ONE workspace from the industry, sub-industry and business type selected during owner onboarding.

The catalogue is extensible. The initial seed contains 40 major industry groups and broad sub-industry coverage. A business type can be entered as free text; missing major industries or sub-industries can be suggested by an owner and reviewed by Super Admin.

## Files

- `supabase/migrations/20261119_zenvio_universal_industry_workspace_engine.sql` — industry directory, seeded taxonomy, workspace profile, module assignments, suggestions, reviewed industry changes and provisioning trigger.
- `one.html` — owner workspace onboarding and industry/sub-industry/business-type selection.
- `owner.html` — owner dashboard industry profile, enabled modules and configured dashboard layout.
- `industry-builder.html` — Super Admin directory builder, publishing controls, module defaults and request review.
- `super-admin.html` — link to the Industry Builder.

## Required migration order

Apply this migration only after the existing ZENVIO ONE foundation and owner-management migrations have been reviewed and applied:

1. `20261117_zenvio_one_foundation.sql`
2. `20261118_zenvio_owner_management.sql`
3. Existing approved MIRROR / ANTICIPATE / SWARM / BLACKBOX / WHAT IF / EVOLVE migrations.
4. `20261119_zenvio_universal_industry_workspace_engine.sql`

Do not infer that a migration has been applied just because its file exists in GitHub. Verify the Supabase migration history and prerequisites first.

## Owner onboarding

1. Owner signs in using the existing invited-owner account flow.
2. In `/one.html`, the owner creates a company workspace.
3. Owner selects a published major industry and a published sub-industry.
4. Owner enters the specific business type, e.g. Property Agency, Boutique Hotel or Cosmetic Dentistry Clinic.
5. Optional company location, website and description are saved to the workspace profile.
6. The database trigger provisions the workspace profile and initial module assignments from the selected catalogue entry.
7. The owner sees industry configuration, configured dashboard slots and enabled module list.

The existing owner invitation and authentication flow is preserved. This milestone adds the industry onboarding step to first workspace creation; it does not replace the account invitation mechanism.

## Industry Builder

Open `/industry-builder.html` using a Super Admin account.

- Create major industries and sub-industries.
- Set default modules for newly created workspaces.
- Set a dashboard layout key and ARIA configuration profile.
- Publish/unpublish and activate/deactivate catalogue entries.
- Review owner-submitted industry suggestions.
- Review workspace industry-change requests.

Directory changes affect new workspaces by default. Existing workspaces are not silently changed when a Super Admin edits a catalogue entry.

## Industry changes

Owners/admins submit an industry-change request from the workspace configuration section. The current workspace remains unchanged until Super Admin reviews it.

On approval, the database updates the workspace's industry and profile and adds the new industry's default modules. Existing owner-specific module choices are preserved. Old industry-default modules that no longer apply are disabled. Direct browser-side industry field changes are blocked by a database guard.

## Data model

- `zenvio_industry_catalog` — hierarchical industry and sub-industry directory.
- `zenvio_workspace_profiles` — company profile, selected taxonomy, dashboard layout and ARIA profile.
- `zenvio_workspace_modules` — per-organization module enablement and configuration.
- `zenvio_industry_suggestions` — owner suggestions awaiting Super Admin review.
- `zenvio_industry_change_requests` — explicit industry-change workflow.
- Existing `zenvio_organizations` — additive industry selection columns; existing organization records are preserved.

## Security

- Industry directory reads require an authenticated user; unpublished entries are visible only to Super Admin.
- Catalogue writes are guarded by Super Admin RLS policies.
- Workspace profiles and module assignments are organization-scoped.
- Owners/admins can manage their own workspace modules, not other organizations.
- Owner suggestions and change requests are scoped to the submitting user or organization.
- Industry changes require the Super Admin review RPC.
- No service-role key is added to browser code.

## Implementation boundary

This milestone implements the directory, onboarding selection, workspace metadata, module-default assignment, dashboard layout configuration slots, suggestion review and industry-change approval workflow.

It does **not** automatically implement every vertical-specific operational system. For example, a Healthcare dashboard slot named Appointments does not mean a complete patient scheduling/medical-record system exists. Each industry-specific operational engine, data model, integrations, compliance controls and ARIA knowledge pack must be implemented and tested separately before it is marketed as an active feature.

The ARIA profile is stored as configuration metadata in this milestone; it is not yet proof that every AI prompt/runtime automatically consumes the profile.

## Validation before activation

- Review the migration in full.
- Verify the prerequisite tables and helper functions.
- Test owner onboarding with a non-production test owner.
- Confirm organization membership is created by the existing organization trigger.
- Verify workspace profile/module rows are created.
- Test cross-organization access denial.
- Test owner suggestion and Super Admin approval.
- Test industry-change request, rejection and approval.
- Confirm no paid Cloudflare plan, R2 or new paid API is required.

Do not run SQL, merge the PR, deploy the Worker, or change billing without explicit approval.
