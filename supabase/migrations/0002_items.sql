-- StayOn migration 0002: items table + indexes
--
-- Owner-scoped item records that drive the Home dashboard. RLS is added
-- in 0003_items_rls.sql immediately after this migration — do not write
-- from the client until both have been applied.
--
-- Idempotent: safe to re-run (uses `if not exists` + `or replace`).

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  category text not null check (category in (
    'warranty','subscription','id_license','insurance',
    'medicine','grocery','bill','document','other'
  )),
  date_type text not null check (date_type in ('expires','renews','due')),
  target_date date not null,
  notes text,
  assignee_label text,
  amount_minor int,
  currency_code text not null default 'PHP',
  status text not null default 'active'
    check (status in ('active','archived','trashed')),
  trashed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Dashboard sort + filter index.
create index if not exists items_owner_status_date_idx
  on public.items (owner_id, status, target_date);

-- Used by the Phase 6 Trash purge job.
create index if not exists items_trashed_at_idx
  on public.items (trashed_at)
  where status = 'trashed';

-- Auto-update `updated_at` on every UPDATE so the client never has to
-- send it (and can't fake it).
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists items_touch_updated_at on public.items;
create trigger items_touch_updated_at
  before update on public.items
  for each row execute function public.touch_updated_at();
