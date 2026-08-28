-- StartKind backend schema.
--
-- Personal history lives in the user's own iCloud (CloudKit) and never reaches
-- this database. Everything here is either an anonymous device record, an AI
-- quota counter, or short-lived shared co-start room state.

create table if not exists devices (
    id           uuid primary key default gen_random_uuid(),
    token_hash   text not null unique,
    entitlement  text not null default 'free',
    created_at   timestamptz not null default now(),
    last_seen_at timestamptz not null default now()
);

create table if not exists ai_usage (
    id         bigserial primary key,
    device_id  uuid not null references devices(id) on delete cascade,
    day        date not null,
    endpoint   text not null,
    created_at timestamptz not null default now()
);
create index if not exists idx_ai_usage_device_day on ai_usage (device_id, day);

create table if not exists costart_rooms (
    id               uuid primary key default gen_random_uuid(),
    host_device_id   uuid not null references devices(id) on delete cascade,
    -- UNIQUE closes the room-code collision the audit found: two hosts can no
    -- longer hold the same code at the same time.
    code             char(6) not null unique,
    duration_minutes int not null default 25,
    status           text not null default 'active',
    starts_at        timestamptz not null default now(),
    ended_at         timestamptz,
    created_at       timestamptz not null default now()
);
create index if not exists idx_costart_rooms_active on costart_rooms (code) where status = 'active';

create table if not exists costart_participants (
    id           uuid primary key default gen_random_uuid(),
    room_id      uuid not null references costart_rooms(id) on delete cascade,
    device_id    uuid not null references devices(id) on delete cascade,
    display_name text not null default '',
    stated_step  text not null default '',
    outcome      text,
    joined_at    timestamptz not null default now(),
    left_at      timestamptz,
    unique (room_id, device_id)
);

-- Rooms are ephemeral working sessions, not history. Reap anything past its
-- window so the table cannot grow without bound on a 2GB box.
create or replace function reap_stale_costart_rooms() returns void language sql as $$
    update costart_rooms
       set status = 'ended', ended_at = now()
     where status = 'active'
       and starts_at < now() - interval '2 hours';
    delete from costart_rooms where ended_at < now() - interval '7 days';
$$;
