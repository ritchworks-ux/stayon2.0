-- Verify Phase 3 migrations are applied

-- Check if attachments table exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'attachments'
) as attachments_exists;

-- Check if storage_quotas table exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'storage_quotas'
) as storage_quotas_exists;

-- Check if cached_products table exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_name = 'cached_products'
) as cached_products_exists;

-- Check profiles has subscription_tier column
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_schema = 'public' AND table_name = 'profiles' 
  AND column_name = 'subscription_tier'
) as profiles_has_tier;

-- Check RLS is enabled on attachments
SELECT EXISTS (
  SELECT 1 FROM pg_tables 
  WHERE schemaname = 'public' AND tablename = 'attachments' 
  AND rowsecurity = true
) as attachments_rls_enabled;

-- Count RLS policies on attachments
SELECT COUNT(*) as attachment_policies
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'attachments';
