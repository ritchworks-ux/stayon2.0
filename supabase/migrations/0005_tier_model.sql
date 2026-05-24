-- Phase 3: Add subscription tier model to profiles

-- Add subscription tier to profiles
alter table public.profiles
  add column subscription_tier text default 'free' not null,
  add column prefer_cloud_storage boolean default false,
  add constraint valid_subscription_tier
    check (subscription_tier in ('free', 'premium'));

-- Create initial quota record when user signs up (via trigger)
create or replace function public.create_storage_quota()
returns trigger as $$
begin
  insert into public.storage_quotas (owner_id, tier, quota_limit_bytes, attachment_limit)
  values (
    new.id,
    'free',
    52428800,  -- 50 MB
    10         -- 10 items
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.create_storage_quota();
