-- Run after the migration. Fails the job on any violated expectation.
do $$
declare
  rls_enabled boolean;
begin
  select c.relrowsecurity into rls_enabled
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'zenvio_aria_admin_controls';
  if rls_enabled is distinct from true then
    raise exception 'RLS is not enabled on ARIA admin controls';
  end if;

  if has_table_privilege('authenticated', 'public.zenvio_aria_admin_controls', 'SELECT') then
    raise exception 'Authenticated users must not have table privileges on admin controls';
  end if;
  if has_table_privilege('authenticated', 'public.zenvio_aria_installations', 'UPDATE') then
    raise exception 'Authenticated users must not update installation status';
  end if;
  if has_function_privilege('authenticated', 'public.zenvio_aria_consume_rate_limit(uuid,text,integer,integer)', 'EXECUTE') then
    raise exception 'Authenticated users must not execute the private rate limiter';
  end if;
  if not has_function_privilege('service_role', 'public.zenvio_aria_consume_rate_limit(uuid,text,integer,integer)', 'EXECUTE') then
    raise exception 'Service role must be able to execute the rate limiter';
  end if;
end
$$;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

insert into public.zenvio_creative_projects
  (id, organization_id, name, business_type, project_data)
values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'Test website', 'Architecture', '{}'::jsonb);

insert into public.zenvio_aria_installations
  (id, project_id, organization_id)
values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');

insert into public.zenvio_aria_owner_configs
  (installation_id, organization_id, config)
values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   '{"owner_enabled": false, "greeting": "Welcome"}'::jsonb);

update public.zenvio_aria_owner_configs
set config = jsonb_set(config, '{owner_enabled}', 'true'::jsonb)
where installation_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

do $$
declare
  n integer;
begin
  select count(*) into n from public.zenvio_creative_projects;
  if n <> 1 then raise exception 'Workspace owner should read their project'; end if;
  if (select config->>'owner_enabled' from public.zenvio_aria_owner_configs
      where installation_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') <> 'true' then
    raise exception 'Workspace owner should update owner ARIA settings';
  end if;
end
$$;

-- A different authenticated user must not see the workspace project.
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$
declare n integer;
begin
  select count(*) into n from public.zenvio_creative_projects;
  if n <> 0 then raise exception 'Unrelated user can read another workspace project'; end if;
end
$$;

reset role;
set role service_role;
update public.zenvio_aria_installations
set enabled = true
where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

do $$
declare allowed boolean;
begin
  for i in 1..15 loop
    allowed := public.zenvio_aria_consume_rate_limit(
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      repeat('a', 64),
      15,
      60
    );
    if allowed is distinct from true then raise exception 'Rate limiter blocked a request below the configured limit'; end if;
  end loop;
  allowed := public.zenvio_aria_consume_rate_limit(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    repeat('a', 64),
    15,
    60
  );
  if allowed is distinct from false then raise exception 'Rate limiter did not block request 16'; end if;
end
$$;

reset role;
do $$
begin
  if (select enabled from public.zenvio_aria_installations
      where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') is distinct from true then
    raise exception 'Trusted service role could not enable installation';
  end if;
end
$$;

select 'Creative Studio migration and RLS integration tests passed' as result;
