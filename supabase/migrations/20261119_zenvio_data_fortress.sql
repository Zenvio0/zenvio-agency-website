-- ZENVIO DATA FORTRESS v0.1
-- Additive backup-control metadata only. Does NOT perform backups.
-- No existing ZENVIO tables, records, policies, or secrets are modified.
-- Apply only after reviewing this migration in Supabase SQL Editor.

begin;

create table if not exists public.zenvio_backup_policies (
  organization_id uuid primary key references public.zenvio_organizations(id) on delete cascade,
  enabled boolean not null default false,
  schedule_cron text not null default '0 2 * * *',
  timezone text not null default 'UTC',
  daily_retention_days integer not null default 30 check (daily_retention_days between 1 and 3650),
  weekly_retention_weeks integer not null default 12 check (weekly_retention_weeks between 1 and 520),
  monthly_retention_months integer not null default 12 check (monthly_retention_months between 1 and 120),
  immutable_retention_days integer not null default 7 check (immutable_retention_days between 0 and 3650),
  rpo_target_minutes integer not null default 1440 check (rpo_target_minutes between 1 and 525600),
  rto_target_minutes integer not null default 1440 check (rto_target_minutes between 1 and 525600),
  backup_scope jsonb not null default '{"database":true,"storage":true,"website_assets":true,"configuration":true}'::jsonb
    check (jsonb_typeof(backup_scope) = 'object'),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.zenvio_backup_destinations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  provider text not null check (provider in ('cloudflare_r2','s3_compatible','customer_managed')),
  label text not null check (char_length(trim(label)) between 2 and 120),
  bucket_name text,
  endpoint_host text,
  region text,
  credential_reference text,
  connection_status text not null default 'not_configured'
    check (connection_status in ('not_configured','pending_verification','connected','paused','revoked')),
  last_connection_check_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, label)
);

create table if not exists public.zenvio_backup_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  destination_id uuid,
  backup_type text not null check (backup_type in ('full','incremental','database','storage','website_assets','configuration')),
  trigger_type text not null default 'scheduled' check (trigger_type in ('scheduled','manual','recovery')),
  status text not null default 'queued'
    check (status in ('queued','running','uploaded','verified','failed','expired')),
  started_at timestamptz,
  completed_at timestamptz,
  verified_at timestamptz,
  object_count bigint check (object_count is null or object_count >= 0),
  bytes_written bigint check (bytes_written is null or bytes_written >= 0),
  checksum_sha256 text,
  manifest_version text,
  snapshot_reference text,
  safe_error_code text,
  safe_error_message text,
  created_at timestamptz not null default now(),
  foreign key (organization_id, destination_id)
    references public.zenvio_backup_destinations(organization_id, id) on delete restrict
);

create table if not exists public.zenvio_restore_tests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  backup_run_id uuid,
  status text not null default 'planned' check (status in ('planned','running','passed','failed')),
  started_at timestamptz,
  completed_at timestamptz,
  recovery_duration_seconds bigint check (recovery_duration_seconds is null or recovery_duration_seconds >= 0),
  restored_object_count bigint check (restored_object_count is null or restored_object_count >= 0),
  checksum_mismatch_count bigint check (checksum_mismatch_count is null or checksum_mismatch_count >= 0),
  summary text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (organization_id, backup_run_id)
    references public.zenvio_backup_runs(organization_id, id) on delete restrict
);

create index if not exists zenvio_backup_destinations_org_idx
  on public.zenvio_backup_destinations(organization_id, connection_status);
create index if not exists zenvio_backup_runs_org_created_idx
  on public.zenvio_backup_runs(organization_id, created_at desc);
create index if not exists zenvio_backup_runs_status_idx
  on public.zenvio_backup_runs(status, created_at desc);
create index if not exists zenvio_restore_tests_org_created_idx
  on public.zenvio_restore_tests(organization_id, created_at desc);

drop trigger if exists zenvio_backup_policies_touch on public.zenvio_backup_policies;
create trigger zenvio_backup_policies_touch
before update on public.zenvio_backup_policies
for each row execute function public.zenvio_touch_updated_at();

drop trigger if exists zenvio_backup_destinations_touch on public.zenvio_backup_destinations;
create trigger zenvio_backup_destinations_touch
before update on public.zenvio_backup_destinations
for each row execute function public.zenvio_touch_updated_at();

alter table public.zenvio_backup_policies enable row level security;
alter table public.zenvio_backup_destinations enable row level security;
alter table public.zenvio_backup_runs enable row level security;
alter table public.zenvio_restore_tests enable row level security;

revoke all on public.zenvio_backup_policies from anon, authenticated;
revoke all on public.zenvio_backup_destinations from anon, authenticated;
revoke all on public.zenvio_backup_runs from anon, authenticated;
revoke all on public.zenvio_restore_tests from anon, authenticated;

drop policy if exists zenvio_backup_policy_owner_read on public.zenvio_backup_policies;
create policy zenvio_backup_policy_owner_read on public.zenvio_backup_policies
for select to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_backup_policy_owner_insert on public.zenvio_backup_policies;
create policy zenvio_backup_policy_owner_insert on public.zenvio_backup_policies
for insert to authenticated
with check (
  created_by = auth.uid()
  and public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_backup_policy_owner_update on public.zenvio_backup_policies;
create policy zenvio_backup_policy_owner_update on public.zenvio_backup_policies
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_backup_destination_owner_read on public.zenvio_backup_destinations;
create policy zenvio_backup_destination_owner_read on public.zenvio_backup_destinations
for select to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_backup_destination_owner_insert on public.zenvio_backup_destinations;
create policy zenvio_backup_destination_owner_insert on public.zenvio_backup_destinations
for insert to authenticated
with check (
  created_by = auth.uid()
  and public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_backup_destination_owner_update on public.zenvio_backup_destinations;
create policy zenvio_backup_destination_owner_update on public.zenvio_backup_destinations
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_backup_destination_owner_delete on public.zenvio_backup_destinations;
create policy zenvio_backup_destination_owner_delete on public.zenvio_backup_destinations
for delete to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_backup_runs_owner_read on public.zenvio_backup_runs;
create policy zenvio_backup_runs_owner_read on public.zenvio_backup_runs
for select to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_restore_tests_owner_read on public.zenvio_restore_tests;
create policy zenvio_restore_tests_owner_read on public.zenvio_restore_tests
for select to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']));

-- Browser clients may read control metadata but cannot create or alter backup results.
grant select on public.zenvio_backup_policies to authenticated;
grant insert (organization_id, schedule_cron, timezone, daily_retention_days, weekly_retention_weeks, monthly_retention_months, immutable_retention_days, rpo_target_minutes, rto_target_minutes, backup_scope, created_by) on public.zenvio_backup_policies to authenticated;
grant update (schedule_cron, timezone, daily_retention_days, weekly_retention_weeks, monthly_retention_months, immutable_retention_days, rpo_target_minutes, rto_target_minutes, backup_scope) on public.zenvio_backup_policies to authenticated;
grant select on public.zenvio_backup_destinations to authenticated;
grant insert (organization_id, provider, label, bucket_name, endpoint_host, region, credential_reference, created_by) on public.zenvio_backup_destinations to authenticated;
grant update (label, bucket_name, endpoint_host, region, credential_reference) on public.zenvio_backup_destinations to authenticated;
grant delete on public.zenvio_backup_destinations to authenticated;
grant select on public.zenvio_backup_runs to authenticated;
grant select on public.zenvio_restore_tests to authenticated;

-- Super Admin receives aggregate operational health only, never customer file contents.
create or replace function public.zenvio_backup_platform_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare result jsonb;
begin
  if not public.zenvio_is_super_admin() then
    raise exception 'Super Admin access required';
  end if;

  select jsonb_build_object(
    'organizations', (select count(*) from public.zenvio_organizations),
    'policies_enabled', (select count(*) from public.zenvio_backup_policies where enabled),
    'destinations_connected', (select count(*) from public.zenvio_backup_destinations where connection_status = 'connected'),
    'runs_verified', (select count(*) from public.zenvio_backup_runs where status = 'verified'),
    'runs_failed', (select count(*) from public.zenvio_backup_runs where status = 'failed'),
    'restore_tests_passed', (select count(*) from public.zenvio_restore_tests where status = 'passed'),
    'restore_tests_failed', (select count(*) from public.zenvio_restore_tests where status = 'failed'),
    'workspaces', coalesce((
      select jsonb_agg(jsonb_build_object(
        'organization_id', o.id,
        'organization_name', o.name,
        'policy_enabled', coalesce(p.enabled, false),
        'destination_count', (
          select count(*) from public.zenvio_backup_destinations d
          where d.organization_id = o.id and d.connection_status = 'connected'
        ),
        'last_verified_backup', (
          select max(r.verified_at) from public.zenvio_backup_runs r
          where r.organization_id = o.id and r.status = 'verified'
        ),
        'last_restore_test', (
          select max(t.completed_at) from public.zenvio_restore_tests t
          where t.organization_id = o.id and t.status = 'passed'
        )
      ) order by o.created_at desc)
      from public.zenvio_organizations o
      left join public.zenvio_backup_policies p on p.organization_id = o.id
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

revoke all on function public.zenvio_backup_platform_overview() from public, anon;
grant execute on function public.zenvio_backup_platform_overview() to authenticated;

commit;
