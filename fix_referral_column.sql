-- =============================================================
-- KUTBI PAINTS - MIGRATION: Add missing columns to users table
-- Run this in Supabase Dashboard → SQL Editor → New Query
-- =============================================================

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS business_name TEXT,
ADD COLUMN IF NOT EXISTS business_address TEXT,
ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'silver',
ADD COLUMN IF NOT EXISTS total_purchase_value DOUBLE PRECISION DEFAULT 0,
ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
