-- Phase 3: Attachments + Image Processing
-- Migration: Create attachments and storage_quotas tables

-- Attachment metadata
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,

  -- File metadata
  filename text not null,
  content_type text not null, -- image/jpeg, application/pdf, etc.
  file_size_bytes int not null,

  -- Storage location
  storage_path text not null, -- gs://bucket/users/{owner_id}/attachments/{id}
  storage_tier text not null default 'local', -- 'local' | 'cloud'

  -- Extraction metadata
  extraction_type text, -- 'barcode' | 'receipt' | 'warranty' | null
  extraction_data jsonb, -- Structured extracted fields
  extraction_confidence float, -- 0.0–1.0 for OCR
  extraction_reviewed_at timestamp,

  -- Timestamps
  created_at timestamp not null default now(),
  updated_at timestamp not null default now(),

  constraint filename_not_empty check (filename != ''),
  constraint valid_tier check (storage_tier in ('local', 'cloud')),
  constraint valid_type check (content_type in (
    'image/jpeg', 'image/png', 'application/pdf'
  ))
);

create index attachments_owner_id_idx on public.attachments(owner_id);
create index attachments_item_id_idx on public.attachments(item_id);

-- RLS Policies for attachments
alter table public.attachments enable row level security;

create policy "attachments_select_own"
  on public.attachments for select
  using (auth.uid() = owner_id);

create policy "attachments_insert_own"
  on public.attachments for insert
  with check (auth.uid() = owner_id);

create policy "attachments_update_own"
  on public.attachments for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "attachments_delete_own"
  on public.attachments for delete
  using (auth.uid() = owner_id);

-- Storage quota tracking
create table public.storage_quotas (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'free', -- 'free' | 'premium'
  total_bytes_used int not null default 0,
  quota_limit_bytes int not null default 52428800, -- 50 MB for free
  attachment_count int not null default 0,
  attachment_limit int not null default 10, -- 10 items for free
  updated_at timestamp not null default now()
);

alter table public.storage_quotas enable row level security;

create policy "storage_quotas_select_own"
  on public.storage_quotas for select
  using (auth.uid() = owner_id);

-- Cached products for barcode lookups (offline resilience)
create table public.cached_products (
  id uuid primary key default gen_random_uuid(),
  barcode text not null unique,
  product_data jsonb not null, -- Full Open Food Facts response
  created_at timestamp not null default now()
);

create index cached_products_barcode_idx on public.cached_products(barcode);
