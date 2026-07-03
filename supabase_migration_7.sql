-- Migration 7: Add commission column to orders table
-- Run this in Supabase SQL Editor

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS commission numeric(10, 2) NOT NULL DEFAULT 0;
