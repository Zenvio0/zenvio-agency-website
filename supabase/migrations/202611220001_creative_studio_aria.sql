-- Creative Studio cloud persistence + ARIA ownership boundaries.
-- REVIEW ONLY: do not apply to production until tested on an isolated Supabase branch.
begin;

create table if not exists public.zenvio_creative_projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  unique (id, organization_id),
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  name text not null check (char_length(name) between 1 and 120),
  business_type text not null default '',
  project_data jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists zenvio_creative_projects_org_updated_idx
  on public.zenvio_creative_projects (organization_id, updated_at desc);

create table if not exists public.zenvio_aria_installations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null unique references public.zenvio_creative_projects(id) on delete cascade,
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  public_install_id uuid not null unique default gen_random_uuid(),
  enabled boolean not null default false,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint zenvio_aria_installations_project_org_fk
    foreign key (project_id, organization_id)
    references public.zenvio_creative_projects(id, organization_id)
    on delete cascade
);

-- Owner-editable configuration is isolated so clients cannot toggle/revoke an installation.
create table if not exists public.zenvio_aria_owner_configs (
  installation_id uuid primary key references public.zenvio_aria_installations(id) on delete cascade,
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  config jsonb not null default jsonb_build_object(
    'greeting','Hello! How can I help you today?',
    'tone','Warm and professional',
    'knowledge','',
    'services',true,
    'recommendations',true,
    'contact',true
  ),
  updated_at timestamptz not null default now()
);

-- ZENVIO-only controls are isolated from owner-editable configuration.
create table if not exists public.zenvio_aria_admin_controls (
  installation_id uuid primary key references public.zenvio_aria_installations(id) on delete cascade,
  globally_enabled boolean not null default true,
  locked_fields text[] not null default '{}'::text[],
  admin_config jsonb not null default '{}'::jsonb,
  revoked_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.zenvio_aria_audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  project_id uuid references public.zenvio_creative_projects(id) on delete set null,
  installation_id uuid references public.zenvio_aria_installations(id) on delete set null,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_scope text not null check (actor_scope in ('owner','super_admin','system')),
  action text not null check (char_length(action) between 1 and 100),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists zenvio_aria_audit_org_created_idx
  on public.zenvio_aria_audit_events (organization_id, created_at desc);

-- Private per-installation rate-limit counters; only trusted server code can access these.
create table if not exists public.zenvio_aria_rate_limits (
  installation_id uuid not null references public.zenvio_aria_installations(id) on delete cascade,
  visitor_hash text not null,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0 check (request_count >= 0),
  primary key (installation_id, visitor_hash)
);

alter table public.zenvio_aria_rate_limits enable row level security;
revoke all on public.zenvio_aria_rate_limits from anon, authenticated;

create or replace function public.zenvio_aria_consume_rate_limit(
  p_installation_id uuid,
  p_visitor_hash text,
  p_limit integer default 15,
  p_window_seconds integer default 60
) returns boolean
language plpgsql
security definer
set search_path = public
as $
declare
  allowed boolean := false;
begin
  if p_limit < 1 or p_window_seconds < 1 or length(p_visitor_hash) < 16 then
    return false;
  end if;

  insert into public.zenvio_aria_rate_limits as rl
    (installation_id, visitor_hash, window_started_at, request_count)
  values
    (p_installation_id, p_visitor_hash, now(), 1)
  on conflict (installation_id, visitor_hash) do update
    set window_started_at = case
          when rl.window_started_at <= now() - make_interval(secs => p_window_seconds) then now()
          else rl.window_started_at
        end,
        request_count = case
          when rl.window_started_at <= now() - make_interval(secs => p_window_seconds) then 1
          else rl.request_count + 1
        end
  returning request_count <= p_limit into allowed;

  return coalesce(allowed, false);
end;
$;

revoke all on function public.zenvio_aria_consume_rate_limit(uuid,text,integer,integer) from public, anon, authenticated;
grant execute on function public.zenvio_aria_consume_rate_limit(uuid,text,integer,integer) to service_role;

alter table public.zenvio_creative_projects enable row level security;
alter table public.zenvio_aria_installations enable row level security;
alter table public.zenvio_aria_admin_controls enable row level security;
alter table public.zenvio_aria_owner_configs enable row level security;
alter table public.zenvio_aria_audit_events enable row level security;

-- Projects: organization members can read; owners/admins can create/update/delete.
drop policy if exists zenvio_creative_projects_member_read on public.zenvio_creative_projects;
create policy zenvio_creative_projects_member_read on public.zenvio_creative_projects
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_creative_projects_owner_insert on public.zenvio_creative_projects;
create policy zenvio_creative_projects_owner_insert on public.zenvio_creative_projects
for insert to authenticated with check (
  created_by = (select auth.uid())
  and public.zenvio_has_role(organization_id, array['owner','admin']::text[])
);

drop policy if exists zenvio_creative_projects_owner_update on public.zenvio_creative_projects;
create policy zenvio_creative_projects_owner_update on public.zenvio_creative_projects
for update to authenticated
using (
  public.zenvio_has_role(organization_id, array['owner','admin']::text[])
)
with check (
  public.zenvio_has_role(organization_id, array['owner','admin']::text[])
);

drop policy if exists zenvio_creative_projects_owner_delete on public.zenvio_creative_projects;
create policy zenvio_creative_projects_owner_delete on public.zenvio_creative_projects
for delete to authenticated using (
  public.zenvio_has_role(organization_id, array['owner','admin']::text[])
);

-- Installations: owners manage visitor-facing configuration; public IDs are identifiers only.
drop policy if exists zenvio_aria_installations_member_read on public.zenvio_aria_installations;
create policy zenvio_aria_installations_member_read on public.zenvio_aria_installations
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_aria_installations_owner_insert on public.zenvio_aria_installations;
create policy zenvio_aria_installations_owner_insert on public.zenvio_aria_installations
for insert to authenticated with check (
  public.zenvio_has_role(organization_id, array['owner','admin']::text[])
  and exists (
    select 1 from public.zenvio_creative_projects p
    where p.id = project_id and p.organization_id = zenvio_aria_installations.organization_id
  )
);

-- Installation status/revocation is server-controlled. No client UPDATE policy exists.

drop policy if exists zenvio_aria_owner_configs_member_read on public.zenvio_aria_owner_configs;
create policy zenvio_aria_owner_configs_member_read on public.zenvio_aria_owner_configs
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_aria_owner_configs_owner_insert on public.zenvio_aria_owner_configs;
create policy zenvio_aria_owner_configs_owner_insert on public.zenvio_aria_owner_configs
for insert to authenticated with check (
  public.zenvio_has_role(organization_id, array['owner','admin']::text[])
  and exists (
    select 1 from public.zenvio_aria_installations i
    where i.id = installation_id and i.organization_id = zenvio_aria_owner_configs.organization_id
  )
);

drop policy if exists zenvio_aria_owner_configs_owner_update on public.zenvio_aria_owner_configs;
create policy zenvio_aria_owner_configs_owner_update on public.zenvio_aria_owner_configs
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']::text[]))
with check (public.zenvio_has_role(organization_id, array['owner','admin']::text[]));

-- Admin control rows deliberately have NO authenticated policies.
-- Only trusted server-side service role code may modify them.
-- Audit log: organization owners/admins can read; client-side writes are denied.
drop policy if exists zenvio_aria_audit_owner_read on public.zenvio_aria_audit_events;
create policy zenvio_aria_audit_owner_read on public.zenvio_aria_audit_events
for select to authenticated using (
  public.zenvio_has_role(organization_id, array['owner','admin']::text[])
  or public.zenvio_is_super_admin()
);

grant select, insert, update, delete on public.zenvio_creative_projects to authenticated;
grant select, insert on public.zenvio_aria_installations to authenticated;
grant select, insert, update on public.zenvio_aria_owner_configs to authenticated;
grant select on public.zenvio_aria_audit_events to authenticated;
revoke all on public.zenvio_aria_admin_controls from anon, authenticated;

commit;
