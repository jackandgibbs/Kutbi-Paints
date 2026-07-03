-- ============================================================
-- Kutbi Paints — Profile Picture Migration
-- Run this in your Supabase SQL Editor
-- ============================================================

-- Store the URL of each user's profile selfie (nullable).
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_url text;

-- Reload the PostgREST schema cache so the API recognizes the new column.
NOTIFY pgrst, 'reload schema';
