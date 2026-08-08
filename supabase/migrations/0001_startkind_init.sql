-- StartKind - initial schema (Milestone 3: Supabase sync + AI proxy)
-- Mirrors the local SwiftData model from docs/DATA_MODEL.md.
-- Run with: supabase db push   (after `supabase link --project-ref <ref>`)

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.user_profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    locale text not null default 'en',
    timezone text not null default 'UTC',
    entitlement_state text not null default 'free',
    preferred_tone text not null default 'neutral',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.captures (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    source_type text not null,
    raw_text text not null,
    language text not null default 'en',
    created_at timestamptz not null default now()
);

create table if not exists public.task_items (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    capture_id uuid references public.captures(id) on delete set null,
    title text not null,
    category text not null default 'other',
    emotional_load text not null default 'medium',
    status text not null default 'active',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.next_steps (
    id uuid primary key default gen_random_uuid(),
    task_id uuid references public.task_items(id) on delete set null,
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    step_text text not null,
    stop_condition text not null,
    category text not null default 'other',
    shrink_level int not null default 0,
    estimated_minutes int not null default 10,
    target_minutes int not null default 10,
    status text not null default 'suggested',
    generated_by text not null default 'local_template',
    why_this_step text,
    created_at timestamptz not null default now(),
    started_at timestamptz,
    completed_at timestamptz
);

create table if not exists public.timer_sessions (
    id uuid primary key default gen_random_uuid(),
    next_step_id uuid references public.next_steps(id) on delete set null,
    user_id uuid not null references auth.users(id) on delete cascade,
    planned_minutes int not null,
    actual_seconds int not null default 0,
    outcome text not null default 'paused',
    co_start_mode text not null default 'none',
    category text not null default 'other',
    estimated_minutes int not null default 10,
    created_at timestamptz not null default now(),
    ended_at timestamptz
);

create table if not exists public.time_calibration_profiles (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    category text not null,
    estimate_multiplier double precision not null default 1.0,
    median_actual_minutes double precision,
    completion_rate double precision not null default 0,
    best_start_window text,
    sample_count int not null default 0,
    updated_at timestamptz not null default now(),
    unique (user_id, category)
);

create table if not exists public.recovery_capsules (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    task_id uuid references public.task_items(id) on delete set null,
    last_step_id uuid references public.next_steps(id) on delete set null,
    state_summary text not null,
    resume_step_text text not null,
    resume_title text not null,
    resume_stop_condition text not null,
    resume_timer_minutes int not null default 10,
    resume_category text not null default 'other',
    related_link text,
    related_draft text,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.admin_artifacts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    task_id uuid references public.task_items(id) on delete set null,
    artifact_type text not null default 'other',
    extracted_due_date timestamptz,
    extracted_amount text,
    extracted_contact text,
    extracted_url text,
    required_documents jsonb not null default '[]'::jsonb,
    one_next_step jsonb not null default '{}'::jsonb,
    confidence double precision not null default 0.5,
    created_at timestamptz not null default now()
);

create table if not exists public.co_start_rooms (
    id uuid primary key default gen_random_uuid(),
    host_user_id uuid not null references auth.users(id) on delete cascade,
    room_type text not null,
    duration_minutes int not null default 25,
    status text not null default 'scheduled',
    invite_token_hash text,
    created_at timestamptz not null default now(),
    starts_at timestamptz,
    ended_at timestamptz
);

create table if not exists public.co_start_participants (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.co_start_rooms(id) on delete cascade,
    user_id uuid references auth.users(id) on delete set null,
    display_name text not null,
    stated_step text not null default '',
    outcome text,
    joined_at timestamptz not null default now(),
    left_at timestamptz
);

-- Entitlement mirror (cross-device source of truth, written by Edge Function
-- or a webhook after StoreKit/Play validation).
create table if not exists public.entitlements (
    user_id uuid primary key references auth.users(id) on delete cascade,
    state text not null default 'free',
    updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security: a user can only access their own rows.
-- ---------------------------------------------------------------------------

alter table public.user_profiles enable row level security;
alter table public.captures enable row level security;
alter table public.task_items enable row level security;
alter table public.next_steps enable row level security;
alter table public.timer_sessions enable row level security;
alter table public.time_calibration_profiles enable row level security;
alter table public.recovery_capsules enable row level security;
alter table public.admin_artifacts enable row level security;
alter table public.co_start_rooms enable row level security;
alter table public.co_start_participants enable row level security;
alter table public.entitlements enable row level security;

-- Generic "own rows" policies. co_start_participants uses room ownership via
-- host_user_id on the room; participants are visible to the room host and self.
create policy "own profile" on public.user_profiles
    for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "own captures" on public.captures
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own tasks" on public.task_items
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own next steps" on public.next_steps
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own timer sessions" on public.timer_sessions
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own calibration" on public.time_calibration_profiles
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own capsules" on public.recovery_capsules
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own admin artifacts" on public.admin_artifacts
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own rooms" on public.co_start_rooms
    for all using (auth.uid() = host_user_id) with check (auth.uid() = host_user_id);

create policy "room participants" on public.co_start_participants
    for all using (
        auth.uid() = user_id
        or exists (select 1 from public.co_start_rooms r where r.id = room_id and r.host_user_id = auth.uid())
    ) with check (
        auth.uid() = user_id
        or exists (select 1 from public.co_start_rooms r where r.id = room_id and r.host_user_id = auth.uid())
    );

create policy "own entitlement" on public.entitlements
    for select using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger trg_touch_user_profiles before update on public.user_profiles
    for each row execute function public.touch_updated_at();
create trigger trg_touch_task_items before update on public.task_items
    for each row execute function public.touch_updated_at();
create trigger trg_touch_calibration before update on public.time_calibration_profiles
    for each row execute function public.touch_updated_at();
create trigger trg_touch_capsules before update on public.recovery_capsules
    for each row execute function public.touch_updated_at();
create trigger trg_touch_entitlements before update on public.entitlements
    for each row execute function public.touch_updated_at();
