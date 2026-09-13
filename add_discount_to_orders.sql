-- ================================================================
-- SQL Migration for Kutbi-Paints: Orders Table Updates
-- Run this in: Supabase Dashboard -> SQL Editor -> Run
-- ================================================================

-- 1. Add missing columns to the 'orders' table
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS subtotal double precision DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS discount_amount double precision DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS discount_name text,
  ADD COLUMN IF NOT EXISTS deleted_by_user boolean DEFAULT false;

-- 2. Force PostgREST schema cache reload so the API picks up new columns immediately
NOTIFY pgrst, 'reload schema';
