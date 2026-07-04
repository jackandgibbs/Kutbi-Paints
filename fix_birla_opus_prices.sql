-- ============================================================
-- Fix Birla Opus Products - Zero Price Issue
-- ============================================================
-- This SQL script checks and fixes Birla Opus products that have
-- null or empty prices in the database.
--
-- STEP 1: Diagnose the issue
-- ============================================================

-- Check all Birla Opus products and their prices
SELECT 
    id,
    name,
    brand,
    category,
    sub_category,
    bucket_sizes,
    prices,
    CASE 
        WHEN prices IS NULL THEN 'NULL'
        WHEN prices::text = '{}' THEN 'EMPTY'
        ELSE 'HAS_DATA'
    END as price_status
FROM products
WHERE brand = 'Birla Opus'
ORDER BY category, sub_category, name;

-- Count products with missing prices
SELECT 
    category,
    COUNT(*) as total_products,
    SUM(CASE WHEN prices IS NULL OR prices::text = '{}' THEN 1 ELSE 0 END) as missing_prices
FROM products
WHERE brand = 'Birla Opus'
GROUP BY category;

-- ============================================================
-- STEP 2: Fix the issue - Set default prices
-- ============================================================

-- Update Wall Putty products with standard pricing
UPDATE products
SET 
    bucket_sizes = '["1kg", "30kg", "60kg"]'::jsonb,
    prices = '{"1kg": 20, "30kg": 450, "60kg": 850}'::jsonb
WHERE brand = 'Birla Opus'
  AND category = 'Wall Putty'
  AND (prices IS NULL OR prices::text = '{}');

-- Update all other Birla Opus products (paints) with standard pricing
UPDATE products
SET 
    bucket_sizes = '["1L", "4L", "10L", "20L"]'::jsonb,
    prices = '{"1L": 400, "4L": 1500, "10L": 3500, "20L": 6600}'::jsonb
WHERE brand = 'Birla Opus'
  AND category != 'Wall Putty'
  AND (prices IS NULL OR prices::text = '{}');

-- ============================================================
-- STEP 3: Verify the fix
-- ============================================================

-- Check that all products now have prices
SELECT 
    id,
    name,
    category,
    bucket_sizes,
    prices
FROM products
WHERE brand = 'Birla Opus'
ORDER BY category, name;

-- Final verification count
SELECT 
    'Total Birla Opus Products' as description,
    COUNT(*) as count
FROM products
WHERE brand = 'Birla Opus'
UNION ALL
SELECT 
    'Products with valid prices' as description,
    COUNT(*) as count
FROM products
WHERE brand = 'Birla Opus'
  AND prices IS NOT NULL
  AND prices::text != '{}';

-- ============================================================
-- STEP 4 (OPTIONAL): Set more realistic prices by category
-- ============================================================
-- Uncomment and customize these queries if you want to set
-- different prices for different product categories/tiers

-- -- Luxury Interior/Exterior - Premium pricing
-- UPDATE products
-- SET prices = '{"1L": 550, "4L": 2000, "10L": 4700, "20L": 8800}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND sub_category LIKE '%Luxury%';

-- -- Premium products - Mid-tier pricing
-- UPDATE products
-- SET prices = '{"1L": 450, "4L": 1650, "10L": 3900, "20L": 7300}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND sub_category = 'Premium'
--   AND category IN ('Interior', 'Exterior');

-- -- Emulsion products - Standard pricing
-- UPDATE products
-- SET prices = '{"1L": 350, "4L": 1300, "10L": 3000, "20L": 5600}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND sub_category = 'Emulsion';

-- -- Oil Paint - Similar to emulsion
-- UPDATE products
-- SET prices = '{"1L": 380, "4L": 1400, "10L": 3200, "20L": 6000}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND category = 'Oil Paint';

-- -- Designer Finish - Premium pricing
-- UPDATE products
-- SET prices = '{"1L": 600, "4L": 2200, "10L": 5000, "20L": 9500}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND category = 'Designer Finish';

-- -- Alldry (Waterproofing) - Special pricing
-- UPDATE products
-- SET prices = '{"1L": 500, "4L": 1850, "10L": 4300, "20L": 8000}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND category = 'Alldry';

-- -- Allwood (Wood finish) - Premium pricing
-- UPDATE products
-- SET prices = '{"1L": 520, "4L": 1900, "10L": 4400, "20L": 8200}'::jsonb
-- WHERE brand = 'Birla Opus'
--   AND category = 'Allwood';
