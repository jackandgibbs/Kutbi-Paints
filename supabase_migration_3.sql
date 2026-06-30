-- ============================================================
-- Kutbi Paints — Admin Stock Inventory (Cloud Storage)
-- Run this in your Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS admin_stock (
    id TEXT PRIMARY KEY DEFAULT 'main',
    data JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE admin_stock DISABLE ROW LEVEL SECURITY;
NOTIFY pgrst, 'reload schema';
