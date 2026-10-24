-- Synthetic fixtures only. Entire transaction MUST be rolled back.
begin;
set local statement_timeout = '20s';
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
do $$
declare
  sid uuid := gen_random_uuid();
  bad_sid uuid := gen_random_uuid();
  mid1 uuid := gen_random_uuid();
  mid2 uuid := gen_random_uuid();
  mid3 uuid := gen_random_uuid();
  p jsonb;
  bad jsonb;
  result jsonb;
begin
  insert into public.members(id, name) values
    (mid1, '__offline_rollback_fixture__'),
    (mid2, '__offline_rollback_fixture__'),
    (mid3, '__offline_rollback_fixture__');
  p := jsonb_build_object('version', 1, 'session', jsonb_build_object(
    'id', sid, 'title', '__offline_rollback_fixture__', 'status', 'closed',
    'required_time', now() - interval '2 hours',
    'end_time', now() - interval '1 hour',
    'created_at', now() - interval '3 hours',
    'closed_at', now() - interval '30 minutes'),
    'members', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'member_id', mid1,
        'status', 'normal', 'checkin_time', now() - interval '2 hours 1 minute',
        'late_minutes', 0, 'remark', 'fixture'),
      jsonb_build_object('id', gen_random_uuid(), 'member_id', mid2,
        'status', 'late', 'checkin_time', now() - interval '1 hour 59 minutes 30 seconds',
        'late_minutes', 1, 'remark', null),
      jsonb_build_object('id', gen_random_uuid(), 'member_id', mid3,
        'status', 'absent', 'checkin_time', null,
        'late_minutes', 0, 'remark', null)));
  result := public.sync_offline_attendance(p);
  if (result->>'session_id')::uuid <> sid or (result->>'already_synced')::boolean then
    raise exception 'TEST first sync failed';
  end if;
  result := public.sync_offline_attendance(p);
  if not (result->>'already_synced')::boolean
     or (select count(*) from public.session_members where session_id = sid) <> 3
     or (select count(*) from public.attendance_sessions where id = sid) <> 1
     or not exists(select 1 from public.session_members where session_id = sid
        and member_id = mid1 and checkin_time = now() - interval '2 hours 1 minute') then
    raise exception 'TEST idempotency or original time failed';
  end if;
  begin
    perform public.sync_offline_attendance(jsonb_set(p, '{members,0,remark}', '"changed"'));
    raise exception 'TEST changed snapshot accepted';
  exception when others then
    if sqlerrm <> 'OFFLINE_SNAPSHOT_CHANGED' then raise; end if;
  end;
  begin
    perform public.sync_offline_attendance(jsonb_set(p, '{session,status}', '"active"'));
    raise exception 'TEST active task accepted';
  exception when others then
    if sqlerrm <> 'OFFLINE_INVALID_SESSION' then raise; end if;
  end;
  begin
    perform public.sync_offline_attendance(jsonb_set(p, '{members,0,status}', '"pending"'));
    raise exception 'TEST pending member accepted';
  exception when others then
    if sqlerrm <> 'OFFLINE_INVALID_RESULT' then raise; end if;
  end;
  bad := jsonb_set(p, '{session,id}', to_jsonb(bad_sid::text));
  bad := jsonb_set(bad, '{members,0,id}', to_jsonb(gen_random_uuid()::text));
  bad := jsonb_set(bad, '{members,1,id}', to_jsonb(gen_random_uuid()::text));
  bad := jsonb_set(bad, '{members,2,id}', to_jsonb(gen_random_uuid()::text));
  bad := jsonb_set(bad, '{members,0,member_id}', to_jsonb(gen_random_uuid()::text));
  begin
    perform public.sync_offline_attendance(bad);
    raise exception 'TEST invalid foreign key accepted';
  exception when foreign_key_violation then null;
  end;
  if exists(select 1 from offline_private.sync_receipts where session_id = bad_sid)
     or exists(select 1 from public.attendance_sessions where id = bad_sid) then
    raise exception 'TEST partial upload left behind';
  end if;
  perform set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
  if exists(select 1 from offline_private.sync_receipts where session_id = sid) then
    raise exception 'TEST receipt ownership leak';
  end if;
  begin
    perform public.sync_offline_attendance(p);
    raise exception 'TEST another owner accepted';
  exception when others then
    if sqlerrm <> 'OFFLINE_ID_CONFLICT' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.sync_offline_attendance(p);
    raise exception 'TEST missing user accepted';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
set local role anon;
do $$
begin
  begin
    perform public.sync_offline_attendance('{}'::jsonb);
    raise exception 'TEST anon accepted';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
select 'PASS: atomic upload, original time, retry, frozen snapshot, ended-only, ownership, anon denial' as validation;
rollback;
