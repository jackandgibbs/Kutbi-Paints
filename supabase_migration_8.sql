-- Migration 8: Painter bank details verification
-- Run this in your Supabase SQL editor.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS bank_account_number  text,
  ADD COLUMN IF NOT EXISTS bank_passbook_url     text,
  ADD COLUMN IF NOT EXISTS bank_status           text NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS bank_rejection_seen   boolean NOT NULL DEFAULT false;

-- bank_status values:
--   'none'     → painter has never submitted bank details
--   'pending'  → submitted, waiting for admin review
--   'approved' → admin approved
--   'rejected' → admin rejected (painter must re-submit)
