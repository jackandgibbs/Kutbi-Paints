-- ============================================================
-- Kutbi Paints — Promotional Banners/Pamphlets Migration (FIXED)
-- Run this in your Supabase SQL Editor to fix RLS issues
-- ============================================================

-- Create the banners table if it doesn't exist
CREATE TABLE IF NOT EXISTS banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url text NOT NULL,
  title text,
  is_active boolean DEFAULT true,
  sort_order int DEFAULT 100,
  created_at timestamptz DEFAULT timezone('utc'::text, now())
);

-- Drop existing policies if any (in case you're re-running this)
DROP POLICY IF EXISTS "Allow public read access to active banners" ON banners;
DROP POLICY IF EXISTS "Allow authenticated users full access to banners" ON banners;

-- Disable RLS on the banners table
-- (Banners are admin-managed via app logic, not database-level security)
ALTER TABLE banners DISABLE ROW LEVEL SECURITY;

-- Refresh the schema
NOTIFY pgrst, 'reload schema';
