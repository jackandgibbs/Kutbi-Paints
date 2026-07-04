-- Migration 9: Brand cover image
-- Adds a dedicated cover image for each brand (separate from the logo).
-- The painter-side brand screen uses this as the large header image,
-- mirroring the Birla Opus layout for every brand.
-- Run this in your Supabase SQL editor.

ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS cover_image_url text;

NOTIFY pgrst, 'reload schema';
