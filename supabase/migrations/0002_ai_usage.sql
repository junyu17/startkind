-- Daily AI usage counter for server-side Free limit enforcement.
create table if not exists public.ai_usage (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null,
    endpoint text not null,
    created_at timestamptz not null default now()
);

alter table public.ai_usage enable row level security;
-- Users can read their own usage; inserts happen via the user's JWT from Edge Functions.
create policy "own usage" on public.ai_usage
    for select using (auth.uid() = user_id);
create policy "insert own usage" on public.ai_usage
    for insert with check (auth.uid() = user_id);

create index if not exists idx_ai_usage_user_day on public.ai_usage (user_id, day);
