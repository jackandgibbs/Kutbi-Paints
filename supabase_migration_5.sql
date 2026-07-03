-- ============================================================
-- Kutbi Paints — Brands & Brand Categories Migration (idempotent)
-- Safe to run multiple times. Run this in your Supabase SQL Editor.
-- ============================================================

-- 1. Ensure brands table exists with all required columns.
--    If the table already exists (possibly with id as uuid), this is a no-op.
CREATE TABLE IF NOT EXISTS brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  logo_url text,
  sort_order int DEFAULT 100,
  created_at timestamptz DEFAULT timezone('utc'::text, now())
);
ALTER TABLE brands ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 100;

-- 2. Ensure brand_categories table exists.
CREATE TABLE IF NOT EXISTS brand_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  brand text NOT NULL,
  name text NOT NULL,
  created_at timestamptz DEFAULT timezone('utc'::text, now()),
  UNIQUE(brand, name)
);

-- 2b. Make description nullable in case it exists as NOT NULL (we don't use it).
ALTER TABLE brands ALTER COLUMN description DROP NOT NULL;

-- 3. Disable RLS on both tables (safe no-op if already disabled).
ALTER TABLE brands DISABLE ROW LEVEL SECURITY;
ALTER TABLE brand_categories DISABLE ROW LEVEL SECURITY;

-- 4. Add a unique constraint on name if it doesn't exist yet.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'brands'::regclass AND contype = 'u'
    AND conname = 'brands_name_key'
  ) THEN
    ALTER TABLE brands ADD CONSTRAINT brands_name_key UNIQUE (name);
  END IF;
END $$;

-- 5. Seed the 4 built-in brands — skips any that already exist by name.
INSERT INTO brands (id, name, logo_url, sort_order)
SELECT gen_random_uuid(), 'Asian Paints', 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/ap.png', 1
WHERE NOT EXISTS (SELECT 1 FROM brands WHERE name = 'Asian Paints');

INSERT INTO brands (id, name, logo_url, sort_order)
SELECT gen_random_uuid(), 'Berger', 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/berger.png', 2
WHERE NOT EXISTS (SELECT 1 FROM brands WHERE name = 'Berger');

INSERT INTO brands (id, name, logo_url, sort_order)
SELECT gen_random_uuid(), 'Birla Opus', 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/opus.png', 3
WHERE NOT EXISTS (SELECT 1 FROM brands WHERE name = 'Birla Opus');

INSERT INTO brands (id, name, logo_url, sort_order)
SELECT gen_random_uuid(), 'Tools', NULL, 4
WHERE NOT EXISTS (SELECT 1 FROM brands WHERE name = 'Tools');

NOTIFY pgrst, 'reload schema';
