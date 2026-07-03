-- ============================================================
-- Kutbi Paints — Promotional Banners/Pamphlets Migration
-- Run this in your Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url text NOT NULL,
  title text,
  is_active boolean DEFAULT true,
  sort_order int DEFAULT 100,
  created_at timestamptz DEFAULT timezone('utc'::text, now())
);

ALTER TABLE banners DISABLE ROW LEVEL SECURITY;

NOTIFY pgrst, 'reload schema';
