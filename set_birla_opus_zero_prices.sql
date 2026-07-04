-- ============================================================
-- Set Birla Opus Products to Zero Pricing
-- ============================================================
-- This SQL script sets all Birla Opus products to have valid
-- price entries of 0, instead of null/empty prices.
--
-- Use case: Pricing to be determined by admin during order placement
-- ============================================================

-- Wall Putty products - Zero pricing with valid structure
UPDATE products
SET 
    bucket_sizes = '["1kg", "30kg", "60kg"]'::jsonb,
    prices = '{"1kg": 0, "30kg": 0, "60kg": 0}'::jsonb
WHERE brand = 'Birla Opus'
  AND category = 'Wall Putty';

-- All other Birla Opus products (paints) - Zero pricing with valid structure
UPDATE products
SET 
    bucket_sizes = '["1L", "4L", "10L", "20L"]'::jsonb,
    prices = '{"1L": 0, "4L": 0, "10L": 0, "20L": 0}'::jsonb
WHERE brand = 'Birla Opus'
  AND category != 'Wall Putty';

-- Verify all Birla Opus products now have zero prices
SELECT 
    id,
    name,
    category,
    sub_category,
    bucket_sizes,
    prices
FROM products
WHERE brand = 'Birla Opus'
ORDER BY category, name;
