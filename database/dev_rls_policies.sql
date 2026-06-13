-- Development-only RLS policies for Sports Attendance System.
-- These policies are intentionally permissive so the Web admin and Flutter app
-- can both read and write during local development.
--
-- IMPORTANT:
-- 1. Do not use these policies as-is in production.
-- 2. Production should replace them with stricter role-based policies.
-- 3. This file does not contain any Supabase URL, key, password, or secret.

alter table public.groups enable row level security;
alter table public.members enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.session_members enable row level security;

drop policy if exists dev_allow_anon_select_groups on public.groups;
drop policy if exists dev_allow_anon_insert_groups on public.groups;
drop policy if exists dev_allow_anon_update_groups on public.groups;
drop policy if exists dev_allow_anon_delete_groups on public.groups;
drop policy if exists dev_allow_authenticated_select_groups on public.groups;
drop policy if exists dev_allow_authenticated_insert_groups on public.groups;
drop policy if exists dev_allow_authenticated_update_groups on public.groups;
drop policy if exists dev_allow_authenticated_delete_groups on public.groups;

create policy dev_allow_anon_select_groups
on public.groups for select to anon using (true);
create policy dev_allow_anon_insert_groups
on public.groups for insert to anon with check (true);
create policy dev_allow_anon_update_groups
on public.groups for update to anon using (true) with check (true);
create policy dev_allow_anon_delete_groups
on public.groups for delete to anon using (true);
create policy dev_allow_authenticated_select_groups
on public.groups for select to authenticated using (true);
create policy dev_allow_authenticated_insert_groups
on public.groups for insert to authenticated with check (true);
create policy dev_allow_authenticated_update_groups
on public.groups for update to authenticated using (true) with check (true);
create policy dev_allow_authenticated_delete_groups
on public.groups for delete to authenticated using (true);

drop policy if exists dev_allow_anon_select_members on public.members;
drop policy if exists dev_allow_anon_insert_members on public.members;
drop policy if exists dev_allow_anon_update_members on public.members;
drop policy if exists dev_allow_anon_delete_members on public.members;
drop policy if exists dev_allow_authenticated_select_members on public.members;
drop policy if exists dev_allow_authenticated_insert_members on public.members;
drop policy if exists dev_allow_authenticated_update_members on public.members;
drop policy if exists dev_allow_authenticated_delete_members on public.members;

create policy dev_allow_anon_select_members
on public.members for select to anon using (true);
create policy dev_allow_anon_insert_members
on public.members for insert to anon with check (true);
create policy dev_allow_anon_update_members
on public.members for update to anon using (true) with check (true);
create policy dev_allow_anon_delete_members
on public.members for delete to anon using (true);
create policy dev_allow_authenticated_select_members
on public.members for select to authenticated using (true);
create policy dev_allow_authenticated_insert_members
on public.members for insert to authenticated with check (true);
create policy dev_allow_authenticated_update_members
on public.members for update to authenticated using (true) with check (true);
create policy dev_allow_authenticated_delete_members
on public.members for delete to authenticated using (true);

drop policy if exists dev_allow_anon_select_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_anon_insert_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_anon_update_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_anon_delete_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_authenticated_select_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_authenticated_insert_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_authenticated_update_attendance_sessions on public.attendance_sessions;
drop policy if exists dev_allow_authenticated_delete_attendance_sessions on public.attendance_sessions;

create policy dev_allow_anon_select_attendance_sessions
on public.attendance_sessions for select to anon using (true);
create policy dev_allow_anon_insert_attendance_sessions
on public.attendance_sessions for insert to anon with check (true);
create policy dev_allow_anon_update_attendance_sessions
on public.attendance_sessions for update to anon using (true) with check (true);
create policy dev_allow_anon_delete_attendance_sessions
on public.attendance_sessions for delete to anon using (true);
create policy dev_allow_authenticated_select_attendance_sessions
on public.attendance_sessions for select to authenticated using (true);
create policy dev_allow_authenticated_insert_attendance_sessions
on public.attendance_sessions for insert to authenticated with check (true);
create policy dev_allow_authenticated_update_attendance_sessions
on public.attendance_sessions for update to authenticated using (true) with check (true);
create policy dev_allow_authenticated_delete_attendance_sessions
on public.attendance_sessions for delete to authenticated using (true);

drop policy if exists dev_allow_anon_select_session_members on public.session_members;
drop policy if exists dev_allow_anon_insert_session_members on public.session_members;
drop policy if exists dev_allow_anon_update_session_members on public.session_members;
drop policy if exists dev_allow_anon_delete_session_members on public.session_members;
drop policy if exists dev_allow_authenticated_select_session_members on public.session_members;
drop policy if exists dev_allow_authenticated_insert_session_members on public.session_members;
drop policy if exists dev_allow_authenticated_update_session_members on public.session_members;
drop policy if exists dev_allow_authenticated_delete_session_members on public.session_members;

create policy dev_allow_anon_select_session_members
on public.session_members for select to anon using (true);
create policy dev_allow_anon_insert_session_members
on public.session_members for insert to anon with check (true);
create policy dev_allow_anon_update_session_members
on public.session_members for update to anon using (true) with check (true);
create policy dev_allow_anon_delete_session_members
on public.session_members for delete to anon using (true);
create policy dev_allow_authenticated_select_session_members
on public.session_members for select to authenticated using (true);
create policy dev_allow_authenticated_insert_session_members
on public.session_members for insert to authenticated with check (true);
create policy dev_allow_authenticated_update_session_members
on public.session_members for update to authenticated using (true) with check (true);
create policy dev_allow_authenticated_delete_session_members
on public.session_members for delete to authenticated using (true);

select
  tablename,
  policyname,
  roles,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'groups',
    'members',
    'attendance_sessions',
    'session_members'
  )
order by tablename, policyname;
