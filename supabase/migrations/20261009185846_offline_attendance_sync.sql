-- Explicit, ended-only offline sync. Existing core tables/RLS remain unchanged.
-- Receipt lives outside the exposed public schema. No service_role is needed.
create schema offline_private;
revoke all on schema offline_private from public, anon;
grant usage on schema offline_private to authenticated;

create table offline_private.sync_receipts (
  session_id uuid primary key,
  owner_id uuid not null,
  payload_hash text not null,
  created_at timestamptz not null default now()
);
alter table offline_private.sync_receipts enable row level security;
revoke all on offline_private.sync_receipts from public, anon, authenticated;
grant select, insert on offline_private.sync_receipts to authenticated;
create policy offline_receipt_select on offline_private.sync_receipts
  for select to authenticated using (owner_id = (select auth.uid()));
create policy offline_receipt_insert on offline_private.sync_receipts
  for insert to authenticated with check (owner_id = (select auth.uid()));

create function public.sync_offline_attendance(p_payload jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_session jsonb;
  v_id uuid;
  v_required timestamptz;
  v_end timestamptz;
  v_created timestamptz;
  v_closed timestamptz;
  v_hash text;
  v_receipt offline_private.sync_receipts%rowtype;
  v_count integer;
  v_inserted integer;
  v_member record;
begin
  if v_owner is null then
    raise exception 'OFFLINE_LOGIN_REQUIRED' using errcode = '42501';
  end if;
  if jsonb_typeof(p_payload) is distinct from 'object'
     or (p_payload->>'version') is distinct from '1'
     or jsonb_typeof(p_payload->'session') is distinct from 'object'
     or jsonb_typeof(p_payload->'members') is distinct from 'array' then
    raise exception 'OFFLINE_INVALID_PAYLOAD';
  end if;
  if octet_length(p_payload::text) > 8388608 then
    raise exception 'OFFLINE_PAYLOAD_TOO_LARGE';
  end if;
  v_session := p_payload->'session';
  v_id := (v_session->>'id')::uuid;
  v_required := (v_session->>'required_time')::timestamptz;
  v_end := (v_session->>'end_time')::timestamptz;
  v_created := (v_session->>'created_at')::timestamptz;
  v_closed := (v_session->>'closed_at')::timestamptz;
  if v_id is null or nullif(btrim(v_session->>'title'), '') is null
     or (v_session->>'status') is distinct from 'closed'
     or v_required is null or v_end is null or v_created is null or v_closed is null
     or v_end <= v_required or v_closed < v_created
     or v_closed > now() + interval '5 minutes' then
    raise exception 'OFFLINE_INVALID_SESSION';
  end if;
  v_count := jsonb_array_length(p_payload->'members');
  if v_count < 1 or v_count > 5000 then
    raise exception 'OFFLINE_INVALID_MEMBER_COUNT';
  end if;
  if (select count(distinct x.id) from jsonb_to_recordset(p_payload->'members')
      as x(id uuid)) <> v_count
     or (select count(distinct x.member_id) from jsonb_to_recordset(p_payload->'members')
      as x(member_id uuid)) <> v_count then
    raise exception 'OFFLINE_DUPLICATE_OR_MISSING_MEMBER';
  end if;
  for v_member in
    select * from jsonb_to_recordset(p_payload->'members') as x(
      id uuid, member_id uuid, status text, checkin_time timestamptz,
      late_minutes integer, remark text
    )
  loop
    if v_member.status is null or v_member.status not in ('normal', 'late', 'absent')
       or v_member.late_minutes is null or v_member.late_minutes < 0 then
      raise exception 'OFFLINE_INVALID_RESULT';
    end if;
    if v_member.status = 'absent' then
      if v_member.checkin_time is not null or v_member.late_minutes <> 0 then
        raise exception 'OFFLINE_INVALID_ABSENCE';
      end if;
    else
      if v_member.checkin_time is null
         or v_member.checkin_time < v_created
         or v_member.checkin_time > v_closed
         or v_member.checkin_time > v_end then
        raise exception 'OFFLINE_INVALID_CHECKIN_TIME';
      end if;
      if v_member.status = 'normal' and
         (v_member.checkin_time > v_required or v_member.late_minutes <> 0) then
        raise exception 'OFFLINE_INVALID_NORMAL';
      end if;
      if v_member.status = 'late' and
         (v_member.checkin_time <= v_required or
          v_member.late_minutes <> greatest(1,
            floor(extract(epoch from (v_member.checkin_time - v_required)) / 60)::integer)) then
        raise exception 'OFFLINE_INVALID_LATE';
      end if;
    end if;
  end loop;

  v_hash := encode(sha256(convert_to(p_payload::text, 'UTF8')), 'hex');
  -- A unique INSERT serializes retries; the receipt and all data commit together.
  insert into offline_private.sync_receipts(session_id, owner_id, payload_hash)
  values (v_id, v_owner, v_hash) on conflict (session_id) do nothing;
  get diagnostics v_inserted = row_count;
  select * into v_receipt from offline_private.sync_receipts where session_id = v_id;
  if not found or v_receipt.owner_id <> v_owner then
    raise exception 'OFFLINE_ID_CONFLICT';
  end if;
  if v_inserted = 0 then
    if v_receipt.payload_hash <> v_hash then
      raise exception 'OFFLINE_SNAPSHOT_CHANGED';
    end if;
    if not exists(select 1 from public.attendance_sessions
      where id = v_id and created_by = v_owner) then
      raise exception 'OFFLINE_UPLOADED_SESSION_REMOVED';
    end if;
    return jsonb_build_object('session_id', v_id, 'already_synced', true);
  end if;

  -- INSERT only: never overwrite an existing online task or its results.
  insert into public.attendance_sessions(
    id, title, required_time, end_time, status, created_by, created_at
  ) values (
    v_id, btrim(v_session->>'title'), v_required, v_end, 'closed', v_owner, v_created
  );
  insert into public.session_members(
    id, session_id, member_id, status, checkin_time, late_minutes, remark, created_at
  )
  select x.id, v_id, x.member_id, x.status, x.checkin_time,
    x.late_minutes, x.remark, v_created
  from jsonb_to_recordset(p_payload->'members') as x(
    id uuid, member_id uuid, status text, checkin_time timestamptz,
    late_minutes integer, remark text
  );
  return jsonb_build_object('session_id', v_id, 'already_synced', false);
end;
$$;
revoke all on function public.sync_offline_attendance(jsonb)
  from public, anon, authenticated;
grant execute on function public.sync_offline_attendance(jsonb) to authenticated;
notify pgrst, 'reload schema';
