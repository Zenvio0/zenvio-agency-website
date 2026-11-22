-- Disposable PostgreSQL fixture for migration integration checks.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create table auth.users (
  id uuid primary key
);
create or replace function auth.uid()
returns uuid
language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create table public.zenvio_organizations (
  id uuid primary key,
  name text not null
);
create table public.zenvio_organization_members (
  user_id uuid not null references auth.users(id),
  organization_id uuid not null references public.zenvio_organizations(id),
  role text not null,
  primary key (user_id, organization_id)
);

create or replace function public.zenvio_is_member(p_organization_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.zenvio_organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
  )
$$;

create or replace function public.zenvio_has_role(p_organization_id uuid, p_roles text[])
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.zenvio_organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
      and m.role = any(p_roles)
  )
$$;

create or replace function public.zenvio_is_super_admin()
returns boolean
language sql stable
as $$
  select coalesce(current_setting('app.is_super_admin', true), 'false') = 'true'
$$;

grant usage on schema auth to authenticated, service_role;
grant execute on function auth.uid() to authenticated, service_role;
grant execute on function public.zenvio_is_member(uuid) to authenticated;
grant execute on function public.zenvio_has_role(uuid, text[]) to authenticated;
grant execute on function public.zenvio_is_super_admin() to authenticated;

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
insert into public.zenvio_organizations(id, name)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Test Workspace');
insert into public.zenvio_organization_members(user_id, organization_id, role)
values ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'owner');
