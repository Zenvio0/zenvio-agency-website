-- ZENVIO ONE SWARM v0.4 — additive, organization-scoped agent orchestration
create table if not exists public.zenvio_swarm_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  agent_key text not null check (agent_key in ('sales','finance','operations','marketing','support')),
  objective text not null check (char_length(trim(objective)) between 3 and 1000),
  plan jsonb not null default '[]'::jsonb check (jsonb_typeof(plan) = 'array'),
  status text not null default 'awaiting_approval' check (status in ('awaiting_approval','approved','rejected','completed','failed')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create table if not exists public.zenvio_swarm_approvals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  run_id uuid not null unique references public.zenvio_swarm_runs(id) on delete cascade,
  action_type text not null default 'create_tasks' check (action_type = 'create_tasks'),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_by uuid not null references auth.users(id) on delete restrict,
  decided_by uuid references auth.users(id) on delete set null,
  decision_note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index if not exists zenvio_swarm_runs_org_created_idx on public.zenvio_swarm_runs(organization_id,created_at desc);
create index if not exists zenvio_swarm_approvals_org_status_idx on public.zenvio_swarm_approvals(organization_id,status,created_at desc);
alter table public.zenvio_swarm_runs enable row level security;
alter table public.zenvio_swarm_approvals enable row level security;
drop policy if exists zenvio_swarm_runs_select on public.zenvio_swarm_runs;
create policy zenvio_swarm_runs_select on public.zenvio_swarm_runs for select to authenticated using (public.zenvio_is_member(organization_id));
drop policy if exists zenvio_swarm_runs_insert on public.zenvio_swarm_runs;
create policy zenvio_swarm_runs_insert on public.zenvio_swarm_runs for insert to authenticated with check (created_by=auth.uid() and public.zenvio_is_member(organization_id));
drop policy if exists zenvio_swarm_runs_update on public.zenvio_swarm_runs;
create policy zenvio_swarm_runs_update on public.zenvio_swarm_runs for update to authenticated using (public.zenvio_has_role(organization_id,array['owner','admin'])) with check (public.zenvio_has_role(organization_id,array['owner','admin']));
drop policy if exists zenvio_swarm_approvals_select on public.zenvio_swarm_approvals;
create policy zenvio_swarm_approvals_select on public.zenvio_swarm_approvals for select to authenticated using (public.zenvio_is_member(organization_id));
drop policy if exists zenvio_swarm_approvals_insert on public.zenvio_swarm_approvals;
create policy zenvio_swarm_approvals_insert on public.zenvio_swarm_approvals for insert to authenticated with check (requested_by=auth.uid() and public.zenvio_is_member(organization_id));
-- Approval decisions happen only through this checked transaction. The function verifies
-- organization ownership/admin role, creates the planned tasks, and records the decision atomically.
create or replace function public.zenvio_swarm_decide_approval(p_approval_id uuid,p_decision text,p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_approval public.zenvio_swarm_approvals%rowtype;
  v_run public.zenvio_swarm_runs%rowtype;
  v_item jsonb;
  v_created integer := 0;
  v_title text;
  v_priority text;
  v_department uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  select * into v_approval from public.zenvio_swarm_approvals where id=p_approval_id for update;
  if not found then raise exception 'Approval not found'; end if;
  if not public.zenvio_has_role(v_approval.organization_id,array['owner','admin']) then raise exception 'Only organization owners or admins can decide approvals'; end if;
  if v_approval.status <> 'pending' then raise exception 'This approval has already been decided'; end if;
  select * into v_run from public.zenvio_swarm_runs where id=v_approval.run_id for update;
  if not found or v_run.organization_id <> v_approval.organization_id then raise exception 'Related run not found'; end if;
  if p_decision='approved' then
    if jsonb_typeof(v_run.plan) <> 'array' or jsonb_array_length(v_run.plan) < 1 or jsonb_array_length(v_run.plan) > 12 then raise exception 'Plan must contain between 1 and 12 tasks'; end if;
    for v_item in select value from jsonb_array_elements(v_run.plan) loop
      v_title := trim(coalesce(v_item->>'title',''));
      if char_length(v_title) < 3 or char_length(v_title) > 200 then raise exception 'Invalid task title in plan'; end if;
      v_priority := coalesce(v_item->>'priority','normal');
      if v_priority not in ('low','normal','high','urgent') then v_priority := 'normal'; end if;
      v_department := null;
      if coalesce(v_item->>'department_id','') <> '' then
        select id into v_department from public.zenvio_departments where id=(v_item->>'department_id')::uuid and organization_id=v_run.organization_id;
      end if;
      insert into public.zenvio_tasks(organization_id,department_id,title,description,priority,created_by)
      values(v_run.organization_id,v_department,v_title,left(coalesce(v_item->>'description',''),2000),v_priority,auth.uid());
      v_created := v_created+1;
    end loop;
    update public.zenvio_swarm_runs set status='approved',decided_at=now() where id=v_run.id;
    update public.zenvio_swarm_approvals set status='approved',decided_by=auth.uid(),decision_note=left(p_note,1000),decided_at=now() where id=v_approval.id;
    insert into public.zenvio_events(organization_id,actor_user_id,event_type,entity_type,entity_id,summary,metadata)
    values(v_run.organization_id,auth.uid(),'swarm.plan_approved','swarm_run',v_run.id,'SWARM plan approved; created '||v_created||' tasks',jsonb_build_object('agent_key',v_run.agent_key,'tasks_created',v_created));
  else
    update public.zenvio_swarm_runs set status='rejected',decided_at=now() where id=v_run.id;
    update public.zenvio_swarm_approvals set status='rejected',decided_by=auth.uid(),decision_note=left(p_note,1000),decided_at=now() where id=v_approval.id;
    insert into public.zenvio_events(organization_id,actor_user_id,event_type,entity_type,entity_id,summary,metadata)
    values(v_run.organization_id,auth.uid(),'swarm.plan_rejected','swarm_run',v_run.id,'SWARM plan rejected',jsonb_build_object('agent_key',v_run.agent_key));
  end if;
  return jsonb_build_object('decision',p_decision,'tasks_created',v_created,'run_id',v_run.id);
end;
$$;
revoke all on function public.zenvio_swarm_decide_approval(uuid,text,text) from public;
grant execute on function public.zenvio_swarm_decide_approval(uuid,text,text) to authenticated;
grant select,insert on public.zenvio_swarm_runs to authenticated;
grant select,insert on public.zenvio_swarm_approvals to authenticated;
