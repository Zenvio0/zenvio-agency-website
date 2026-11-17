-- ZENVIO ONE: Super Admin + self-service owner onboarding
-- Additive migration. Existing CRM, admin_users, organizations and records are preserved.
-- Bootstrap Super Admin: haiderium213@gmail.com (only if this email already exists in auth.users).

create table if not exists public.zenvio_super_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.zenvio_owner_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  invited_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz not null default now()
);

create table if not exists public.zenvio_owner_invites (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  revoked_at timestamptz
);

create index if not exists zenvio_owner_invites_email_idx on public.zenvio_owner_invites(lower(email));
create index if not exists zenvio_owner_invites_expiry_idx on public.zenvio_owner_invites(expires_at);

alter table public.zenvio_super_admins enable row level security;
alter table public.zenvio_owner_accounts enable row level security;
alter table public.zenvio_owner_invites enable row level security;

revoke all on public.zenvio_super_admins from anon, authenticated;
revoke all on public.zenvio_owner_accounts from anon, authenticated;
revoke all on public.zenvio_owner_invites from anon, authenticated;

create or replace function public.zenvio_is_super_admin()
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.zenvio_super_admins s where s.user_id = auth.uid()
  );
$$;

create or replace function public.zenvio_can_create_workspace()
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select public.zenvio_is_super_admin() or exists (
    select 1 from public.zenvio_owner_accounts a where a.user_id = auth.uid()
  );
$$;

-- Bootstrap the nominated Super Admin without changing or resetting any existing account.
insert into public.zenvio_super_admins(user_id, email)
select u.id, lower(u.email)
from auth.users u
where lower(u.email) = lower('haiderium213@gmail.com')
on conflict (user_id) do update set email = excluded.email;

-- Only invited owners and Super Admin can create organizations/workspaces.
drop policy if exists zenvio_org_insert on public.zenvio_organizations;
create policy zenvio_org_insert on public.zenvio_organizations
for insert to authenticated
with check (created_by = auth.uid() and public.zenvio_can_create_workspace());

create or replace function public.zenvio_super_admin_overview()
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
declare result jsonb;
begin
  if not public.zenvio_is_super_admin() then
    raise exception 'Super Admin access required';
  end if;
  select jsonb_build_object(
    'owners', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', a.user_id, 'email', a.email, 'accepted_at', a.accepted_at,
        'workspace_count', (select count(*) from public.zenvio_organizations o where o.created_by = a.user_id)
      ) order by a.accepted_at desc)
      from public.zenvio_owner_accounts a
    ), '[]'::jsonb),
    'invites', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'email', i.email, 'created_at', i.created_at,
        'expires_at', i.expires_at, 'accepted_at', i.accepted_at, 'revoked_at', i.revoked_at
      ) order by i.created_at desc)
      from public.zenvio_owner_invites i
    ), '[]'::jsonb),
    'workspaces', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'name', o.name, 'industry', o.industry, 'created_by', o.created_by, 'created_at', o.created_at
      ) order by o.created_at desc)
      from public.zenvio_organizations o
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

create or replace function public.zenvio_create_owner_invite(p_email text, p_token text)
returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare invite_id uuid; expiry timestamptz; normalized_email text;
begin
  if not public.zenvio_is_super_admin() then
    raise exception 'Super Admin access required';
  end if;
  normalized_email := lower(trim(coalesce(p_email, '')));
  if normalized_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Enter a valid owner email address';
  end if;
  if length(coalesce(p_token, '')) < 32 then
    raise exception 'Invalid invitation token';
  end if;
  if exists (select 1 from public.zenvio_owner_accounts a where lower(a.email) = normalized_email) then
    raise exception 'This email is already an active owner';
  end if;
  insert into public.zenvio_owner_invites(email, token_hash, invited_by)
  values (normalized_email, encode(digest(p_token, 'sha256'), 'hex'), auth.uid())
  returning id, expires_at into invite_id, expiry;
  return jsonb_build_object('id', invite_id, 'email', normalized_email, 'expires_at', expiry);
end;
$$;

create or replace function public.zenvio_accept_owner_invite(p_token text)
returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare inv public.zenvio_owner_invites%rowtype; current_email text;
begin
  if auth.uid() is null then raise exception 'Sign in or create your account first'; end if;
  current_email := lower(coalesce(auth.jwt()->>'email', ''));
  select * into inv
  from public.zenvio_owner_invites
  where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex')
    and revoked_at is null and accepted_at is null and expires_at > now()
  for update;
  if not found then raise exception 'Invitation is invalid, expired, already used or revoked'; end if;
  if current_email <> lower(inv.email) then
    raise exception 'Sign in with the exact email address that received this invitation';
  end if;
  insert into public.zenvio_owner_accounts(user_id, email, invited_by, accepted_at)
  values (auth.uid(), current_email, inv.invited_by, now())
  on conflict (user_id) do update set email = excluded.email;
  update public.zenvio_owner_invites set accepted_at = now() where id = inv.id;
  return jsonb_build_object('accepted', true, 'email', current_email);
end;
$$;

create or replace function public.zenvio_revoke_owner_invite(p_invite_id uuid)
returns boolean
language plpgsql security definer
set search_path = public, auth
as $$
begin
  if not public.zenvio_is_super_admin() then raise exception 'Super Admin access required'; end if;
  update public.zenvio_owner_invites
  set revoked_at = now()
  where id = p_invite_id and accepted_at is null and revoked_at is null;
  return found;
end;
$$;

revoke all on function public.zenvio_is_super_admin() from public, anon;
revoke all on function public.zenvio_can_create_workspace() from public, anon;
revoke all on function public.zenvio_super_admin_overview() from public, anon;
revoke all on function public.zenvio_create_owner_invite(text, text) from public, anon;
revoke all on function public.zenvio_accept_owner_invite(text) from public, anon;
revoke all on function public.zenvio_revoke_owner_invite(uuid) from public, anon;
grant execute on function public.zenvio_is_super_admin() to authenticated;
grant execute on function public.zenvio_can_create_workspace() to authenticated;
grant execute on function public.zenvio_super_admin_overview() to authenticated;
grant execute on function public.zenvio_create_owner_invite(text, text) to authenticated;
grant execute on function public.zenvio_accept_owner_invite(text) to authenticated;
grant execute on function public.zenvio_revoke_owner_invite(uuid) to authenticated;
