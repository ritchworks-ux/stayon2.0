-- StayOn migration 0001: profiles table
-- One row per authenticated user. RLS enforces owner-only access.

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  default_reminder_offsets int[] not null default '{7,1}',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Owner can read their own profile row.
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

-- Owner can insert their own profile row (used by client bootstrap).
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- Owner can update their own profile row.
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);
