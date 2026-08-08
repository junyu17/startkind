-- Co-Start guest flow: allow room members to see each other and the room.
-- Guests join via anonymous auth; participants in the same room can read all
-- participants + the room row (for near-real-time status via polling).

drop policy if exists "own rooms" on public.co_start_rooms;
drop policy if exists "room participants" on public.co_start_participants;

-- Rooms: visible to host or any participant in the room; writes by host only.
create policy "rooms visible to host or participants" on public.co_start_rooms
    for select using (
        host_user_id = auth.uid()
        or exists (select 1 from public.co_start_participants p where p.room_id = co_start_rooms.id and p.user_id = auth.uid())
    );
create policy "host inserts rooms" on public.co_start_rooms
    for insert with check (host_user_id = auth.uid());
create policy "host updates rooms" on public.co_start_rooms
    for update using (host_user_id = auth.uid()) with check (host_user_id = auth.uid());
create policy "host deletes rooms" on public.co_start_rooms
    for delete using (host_user_id = auth.uid());

-- Participants: room members see all participants in their rooms; insert/update/delete own.
create policy "participants visible to room members" on public.co_start_participants
    for select using (
        user_id = auth.uid()
        or exists (select 1 from public.co_start_rooms r where r.id = room_id and r.host_user_id = auth.uid())
        or exists (select 1 from public.co_start_participants p where p.room_id = co_start_participants.room_id and p.user_id = auth.uid())
    );
create policy "insert own participant" on public.co_start_participants
    for insert with check (user_id = auth.uid());
create policy "update own participant" on public.co_start_participants
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "delete own participant" on public.co_start_participants
    for delete using (user_id = auth.uid());
