-- ZENVIO ONE foundation (additive only)
-- Safe to apply alongside the existing admin_users and leads tables.
-- No existing tables or records are altered or deleted.

create extension if not exists pgcrypto;

create table if not exists public.zenvio_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 160),
  industry text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.zenvio_organization_members (
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member','viewer')),
  joined_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table if not exists public.zenvio_departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 100),
  description text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists public.zenvio_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  department_id uuid references public.zenvio_departments(id) on delete set null,
  title text not null check (char_length(trim(title)) between 2 and 200),
  description text,
  status text not null default 'open' check (status in ('open','in_progress','blocked','done','cancelled')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  due_at timestamptz,
  assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.zenvio_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (char_length(event_type) between 2 and 80),
  entity_type text,
  entity_id uuid,
  summary text not null check (char_length(summary) between 2 and 500),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists zenvio_org_members_user_idx on public.zenvio_organization_members(user_id);
create index if not exists zenvio_departments_org_idx on public.zenvio_departments(organization_id);
create index if not exists zenvio_tasks_org_status_idx on public.zenvio_tasks(organization_id, status, created_at desc);
create index if not exists zenvio_events_org_created_idx on public.zenvio_events(organization_id, created_at desc);

create or replace function public.zenvio_is_member(p_org uuid)
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.zenvio_organization_members m
    where m.organization_id = p_org and m.user_id = auth.uid()
  );
$$;

create or replace function public.zenvio_has_role(p_org uuid, p_roles text[])
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.zenvio_organization_members m
    where m.organization_id = p_org
      and m.user_id = auth.uid()
      and m.role = any(p_roles)
  );
$$;

create or replace function public.zenvio_add_owner_membership()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
begin
  insert into public.zenvio_organization_members(organization_id, user_id, role)
  values (new.id, new.created_by, 'owner')
  on conflict (organization_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists zenvio_org_owner_membership on public.zenvio_organizations;
create trigger zenvio_org_owner_membership
after insert on public.zenvio_organizations
for each row execute function public.zenvio_add_owner_membership();

create or replace function public.zenvio_touch_updated_at()
returns trigger language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists zenvio_tasks_touch on public.zenvio_tasks;
create trigger zenvio_tasks_touch before update on public.zenvio_tasks
for each row execute function public.zenvio_touch_updated_at();

drop trigger if exists zenvio_org_touch on public.zenvio_organizations;
create trigger zenvio_org_touch before update on public.zenvio_organizations
for each row execute function public.zenvio_touch_updated_at();

alter table public.zenvio_organizations enable row level security;
alter table public.zenvio_organization_members enable row level security;
alter table public.zenvio_departments enable row level security;
alter table public.zenvio_tasks enable row level security;
alter table public.zenvio_events enable row level security;

drop policy if exists zenvio_org_select on public.zenvio_organizations;
create policy zenvio_org_select on public.zenvio_organizations
for select to authenticated using (public.zenvio_is_member(id));

drop policy if exists zenvio_org_insert on public.zenvio_organizations;
create policy zenvio_org_insert on public.zenvio_organizations
for insert to authenticated with check (created_by = auth.uid());

drop policy if exists zenvio_org_update on public.zenvio_organizations;
create policy zenvio_org_update on public.zenvio_organizations
for update to authenticated
using (public.zenvio_has_role(id, array['owner','admin']))
with check (public.zenvio_has_role(id, array['owner','admin']));

drop policy if exists zenvio_members_select on public.zenvio_organization_members;
create policy zenvio_members_select on public.zenvio_organization_members
for select to authenticated using (user_id = auth.uid() or public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_members_insert on public.zenvio_organization_members;
create policy zenvio_members_insert on public.zenvio_organization_members
for insert to authenticated with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_members_update on public.zenvio_organization_members;
create policy zenvio_members_update on public.zenvio_organization_members
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_departments_select on public.zenvio_departments;
create policy zenvio_departments_select on public.zenvio_departments
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_departments_insert on public.zenvio_departments;
create policy zenvio_departments_insert on public.zenvio_departments
for insert to authenticated with check (
  created_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_departments_update on public.zenvio_departments;
create policy zenvio_departments_update on public.zenvio_departments
for update to authenticated using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_departments_delete on public.zenvio_departments;
create policy zenvio_departments_delete on public.zenvio_departments
for delete to authenticated using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_tasks_select on public.zenvio_tasks;
create policy zenvio_tasks_select on public.zenvio_tasks
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_tasks_insert on public.zenvio_tasks;
create policy zenvio_tasks_insert on public.zenvio_tasks
for insert to authenticated with check (created_by = auth.uid() and public.zenvio_is_member(organization_id));

drop policy if exists zenvio_tasks_update on public.zenvio_tasks;
create policy zenvio_tasks_update on public.zenvio_tasks
for update to authenticated
using (created_by = auth.uid() or public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_tasks_delete on public.zenvio_tasks;
create policy zenvio_tasks_delete on public.zenvio_tasks
for delete to authenticated using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_events_select on public.zenvio_events;
create policy zenvio_events_select on public.zenvio_events
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_events_insert on public.zenvio_events;
create policy zenvio_events_insert on public.zenvio_events
for insert to authenticated with check (
  actor_user_id = auth.uid() and public.zenvio_is_member(organization_id)
);

-- Event history is intentionally append-only for authenticated clients.
revoke update, delete on public.zenvio_events from authenticated;

grant select, insert, update on public.zenvio_organizations to authenticated;
grant select, insert, update, delete on public.zenvio_organization_members to authenticated;
grant select, insert, update, delete on public.zenvio_departments to authenticated;
grant select, insert, update, delete on public.zenvio_tasks to authenticated;
grant select, insert on public.zenvio_events to authenticated;
