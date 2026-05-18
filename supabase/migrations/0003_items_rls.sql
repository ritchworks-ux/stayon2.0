-- StayOn migration 0003: Row-Level Security on items
--
-- Enables RLS and adds four owner-only policies so a user can only ever
-- read or write their own item rows. Run this immediately after
-- 0002_items.sql — until this migration is applied, the items table is
-- accessible by anyone with the publishable key.
--
-- Idempotent: safe to re-run (drops each policy before re-creating).

alter table public.items enable row level security;

-- Owner can read their own items.
drop policy if exists "items_select_own" on public.items;
create policy "items_select_own" on public.items
  for select using (auth.uid() = owner_id);

-- Owner can insert items only with their own auth.uid() as owner_id.
-- The WITH CHECK clause is what forbids clients from impersonating
-- another user by setting a different owner_id at insert time.
drop policy if exists "items_insert_own" on public.items;
create policy "items_insert_own" on public.items
  for insert with check (auth.uid() = owner_id);

-- Owner can update their own items. Both USING and WITH CHECK on
-- auth.uid() ensure the row is theirs *before* and *after* the update,
-- which makes owner_id effectively immutable from the client.
drop policy if exists "items_update_own" on public.items;
create policy "items_update_own" on public.items
  for update using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Owner can hard-delete their own items. Phase 2 uses soft-delete
-- (status='trashed'); this policy enables the Phase 6 purge job and
-- any future "Empty trash" UI without another migration.
drop policy if exists "items_delete_own" on public.items;
create policy "items_delete_own" on public.items
  for delete using (auth.uid() = owner_id);
