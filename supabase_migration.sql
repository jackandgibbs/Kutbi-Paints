-- ============================================================
-- Kutbi Paints — Missing Columns Migration
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)
-- Go to: Project → SQL Editor → New Query → Paste & Run
-- ============================================================

-- 1. Add variant_stock column (JSONB to store per-size stock like {"1L": 5, "4L": 10})
ALTER TABLE products ADD COLUMN IF NOT EXISTS variant_stock jsonb;

-- 2. Add is_out_of_stock column (manual toggle for admin)
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_out_of_stock boolean DEFAULT false;

-- 3. Reload the PostgREST schema cache so the API recognizes the new columns
NOTIFY pgrst, 'reload schema';
