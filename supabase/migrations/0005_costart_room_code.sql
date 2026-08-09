-- Human-enterable co-start room codes.
-- Room lookup by code happens through the join_co_start_by_code Edge Function
-- so RLS does not need to expose all active rooms to anonymous users.

alter table public.co_start_rooms
    add column if not exists room_code text;

create unique index if not exists co_start_rooms_room_code_idx
    on public.co_start_rooms(room_code)
    where room_code is not null;

create unique index if not exists co_start_participants_room_user_idx
    on public.co_start_participants(room_id, user_id);

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'co_start_rooms_room_code_format'
    ) then
        alter table public.co_start_rooms
            add constraint co_start_rooms_room_code_format
            check (room_code is null or room_code ~ '^[0-9]{6}$');
    end if;
end $$;
