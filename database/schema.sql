-- Supabase PostgreSQL schema for Sports Attendance System.

create table if not exists groups (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    created_at timestamptz default now()
);

create table if not exists members (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    student_id text,
    gender text,
    phone text,
    group_id uuid references groups(id) on delete set null,
    is_active boolean default true,
    created_at timestamptz default now()
);

create table if not exists attendance_sessions (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    required_time timestamptz not null,
    end_time timestamptz not null,
    status text not null default 'active',
    created_by uuid,
    created_at timestamptz default now(),
    constraint attendance_sessions_status_check
        check (status in ('active', 'closed'))
);

create table if not exists session_members (
    id uuid primary key default gen_random_uuid(),
    session_id uuid references attendance_sessions(id) on delete cascade,
    member_id uuid references members(id) on delete cascade,
    status text not null default 'pending',
    checkin_time timestamptz,
    late_minutes integer default 0,
    created_at timestamptz default now(),
    constraint session_members_status_check
        check (status in ('pending', 'normal', 'late', 'absent')),
    constraint session_members_late_minutes_check
        check (late_minutes >= 0),
    constraint session_members_session_id_member_id_key
        unique (session_id, member_id)
);

create index if not exists members_group_id_idx
    on members (group_id);

create index if not exists session_members_session_id_idx
    on session_members (session_id);

create index if not exists session_members_member_id_idx
    on session_members (member_id);

create index if not exists attendance_sessions_status_idx
    on attendance_sessions (status);

create index if not exists attendance_sessions_created_at_idx
    on attendance_sessions (created_at);
