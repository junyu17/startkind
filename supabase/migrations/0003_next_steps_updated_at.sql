-- Add updated_at to next_steps so status changes (started/completed/skipped/paused)
-- can sync across devices with last-write-wins.
alter table public.next_steps add column if not exists updated_at timestamptz not null default now();

create trigger trg_touch_next_steps before update on public.next_steps
    for each row execute function public.touch_updated_at();
