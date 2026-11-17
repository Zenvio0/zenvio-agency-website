-- ZENVIO ONE ANTICIPATE v0.3 — evidence-backed deterministic business signals
-- Additive only. No existing tables or records are altered.

create table if not exists public.zenvio_metric_observations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  metric_key text not null check (char_length(trim(metric_key)) between 2 and 80),
  metric_label text not null check (char_length(trim(metric_label)) between 2 and 120),
  observed_value numeric(18,4) not null,
  unit text not null default '',
  period_start date not null,
  period_end date not null,
  source_description text not null check (char_length(trim(source_description)) between 3 and 500),
  source_entity_id uuid references public.zenvio_mirror_entities(id) on delete set null,
  recorded_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

create index if not exists zenvio_metric_obs_org_key_period_idx
  on public.zenvio_metric_observations(organization_id, metric_key, period_end desc);

create table if not exists public.zenvio_anticipate_findings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  rule_code text not null check (char_length(rule_code) between 2 and 80),
  fingerprint text not null check (char_length(fingerprint) between 2 and 180),
  category text not null check (category in ('operations','finance','customers','suppliers','data_quality','opportunity')),
  severity text not null check (severity in ('info','low','medium','high','critical')),
  title text not null check (char_length(trim(title)) between 3 and 180),
  summary text not null check (char_length(trim(summary)) between 3 and 1200),
  evidence jsonb not null default '[]'::jsonb,
  impact_text text,
  confidence numeric(4,3) check (confidence is null or confidence between 0 and 1),
  status text not null default 'open' check (status in ('open','acknowledged','resolved','dismissed')),
  generated_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  unique (organization_id, rule_code, fingerprint)
);

create index if not exists zenvio_anticipate_findings_org_status_idx
  on public.zenvio_anticipate_findings(organization_id, status, generated_at desc);

alter table public.zenvio_metric_observations enable row level security;
alter table public.zenvio_anticipate_findings enable row level security;

drop policy if exists zenvio_metric_obs_select on public.zenvio_metric_observations;
create policy zenvio_metric_obs_select on public.zenvio_metric_observations
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_metric_obs_insert on public.zenvio_metric_observations;
create policy zenvio_metric_obs_insert on public.zenvio_metric_observations
for insert to authenticated with check (
  recorded_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_metric_obs_update on public.zenvio_metric_observations;
create policy zenvio_metric_obs_update on public.zenvio_metric_observations
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (recorded_by = auth.uid() and public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_metric_obs_delete on public.zenvio_metric_observations;
create policy zenvio_metric_obs_delete on public.zenvio_metric_observations
for delete to authenticated using (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_anticipate_findings_select on public.zenvio_anticipate_findings;
create policy zenvio_anticipate_findings_select on public.zenvio_anticipate_findings
for select to authenticated using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_anticipate_findings_insert on public.zenvio_anticipate_findings;
create policy zenvio_anticipate_findings_insert on public.zenvio_anticipate_findings
for insert to authenticated with check (
  public.zenvio_has_role(organization_id, array['owner','admin'])
);

drop policy if exists zenvio_anticipate_findings_update on public.zenvio_anticipate_findings;
create policy zenvio_anticipate_findings_update on public.zenvio_anticipate_findings
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

grant select, insert, update, delete on public.zenvio_metric_observations to authenticated;
grant select, insert, update on public.zenvio_anticipate_findings to authenticated;
