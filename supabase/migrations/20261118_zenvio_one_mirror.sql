-- ZENVIO ONE MIRROR v0.2 — additive business digital-twin layer
-- Existing ZENVIO tables and records are untouched.

create table if not exists public.zenvio_mirror_profiles (
  organization_id uuid primary key references public.zenvio_organizations(id) on delete cascade,
  legal_name text,
  website text,
  industry text,
  country text,
  timezone text,
  currency text,
  business_size text,
  founded_year integer check (founded_year is null or founded_year between 1600 and 2200),
  description text,
  mission text,
  vision text,
  primary_contact text,
  contact_email text,
  phone text,
  address text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.zenvio_mirror_entities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  entity_type text not null check (entity_type in ('people','customers','suppliers','offerings','workflows','tools','goals','assets')),
  name text not null check (char_length(trim(name)) between 2 and 180),
  description text,
  status text not null default 'active' check (status in ('active','inactive','planned','archived')),
  owner_label text,
  value_numeric numeric(16,2),
  unit text,
  details jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id) on delete restrict,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists zenvio_mirror_entities_org_type_idx
  on public.zenvio_mirror_entities(organization_id, entity_type, created_at desc);

alter table public.zenvio_mirror_profiles enable row level security;
alter table public.zenvio_mirror_entities enable row level security;

drop policy if exists zenvio_mirror_profiles_select on public.zenvio_mirror_profiles;
create policy zenvio_mirror_profiles_select on public.zenvio_mirror_profiles
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_mirror_profiles_insert on public.zenvio_mirror_profiles;
create policy zenvio_mirror_profiles_insert on public.zenvio_mirror_profiles
for insert to authenticated with check (
  updated_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_mirror_profiles_update on public.zenvio_mirror_profiles;
create policy zenvio_mirror_profiles_update on public.zenvio_mirror_profiles
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (updated_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_mirror_entities_select on public.zenvio_mirror_entities;
create policy zenvio_mirror_entities_select on public.zenvio_mirror_entities
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_mirror_entities_insert on public.zenvio_mirror_entities;
create policy zenvio_mirror_entities_insert on public.zenvio_mirror_entities
for insert to authenticated with check (
  created_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_mirror_entities_update on public.zenvio_mirror_entities;
create policy zenvio_mirror_entities_update on public.zenvio_mirror_entities
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (updated_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_mirror_entities_delete on public.zenvio_mirror_entities;
create policy zenvio_mirror_entities_delete on public.zenvio_mirror_entities
for delete to authenticated using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop trigger if exists zenvio_mirror_entities_touch on public.zenvio_mirror_entities;
create trigger zenvio_mirror_entities_touch before update on public.zenvio_mirror_entities
for each row execute function public.zenvio_touch_updated_at();

grant select, insert, update on public.zenvio_mirror_profiles to authenticated;
grant select, insert, update, delete on public.zenvio_mirror_entities to authenticated;
