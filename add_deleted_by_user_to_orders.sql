-- Migration: Add deleted_by_user to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS deleted_by_user boolean DEFAULT false;
