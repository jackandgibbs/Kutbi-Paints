# Birla Opus Zero Price Configuration

## Overview
Birla Opus products are intentionally configured with **zero prices** in the cart. The final pricing is determined by the admin during order processing.

## Why Zero Prices?
This workflow is useful when:
- Prices vary based on negotiation or customer type
- Admin provides custom quotes after order placement
- Prices fluctuate and need to be confirmed at order time
- You want painters to place orders without seeing prices

## Current Setup

### Database Configuration
Birla Opus products have valid price structures, but all set to `0`:
```json
// Paint products
{"1L": 0, "4L": 0, "10L": 0, "20L": 0}

// Putty products
{"1kg": 0, "30kg": 0, "60kg": 0}
```

### App Behavior
1. Painters can browse and select Birla Opus products
2. Products show bucket sizes but no prices on product cards
3. Items can be added to cart with ₹0.00 amount
4. Cart total shows ₹0.00 for Birla Opus items
5. Orders are submitted to admin for final pricing

## Applying Zero Prices

If you need to ensure all Birla Opus products have zero prices:

```bash
# Run this SQL in Supabase SQL Editor
# File: set_birla_opus_zero_prices.sql
```

Or manually:
```sql
UPDATE products
SET prices = '{"1L": 0, "4L": 0, "10L": 0, "20L": 0}'::jsonb
WHERE brand = 'Birla Opus' AND category != 'Wall Putty';

UPDATE products
SET prices = '{"1kg": 0, "30kg": 0, "60kg": 0}'::jsonb
WHERE brand = 'Birla Opus' AND category = 'Wall Putty';
```

## Admin Workflow

When a painter places an order with Birla Opus products:

1. **Order received** with ₹0.00 for Birla Opus items
2. **Admin reviews** the order in Pending Bills screen
3. **Admin updates** the bill with actual prices
4. **Bill approved** and sent to painter
5. **Painter sees** final amount in their bills screen

## Changing to Show Prices

If you later want to display actual prices for Birla Opus:

1. Run the SQL from `fix_birla_opus_prices.sql` to set real prices
2. Restart the app to reload product data
3. Prices will now show in product listings and cart

## Files Reference

- ✅ `set_birla_opus_zero_prices.sql` - Set all Birla Opus to zero
- ✅ `fix_birla_opus_prices.sql` - Set default market prices
- ✅ `lib/services/cart_service.dart` - Handles zero prices without warnings
- ✅ `lib/features/painter/order_form_screen.dart` - Allows zero-price orders

## Testing

1. Open app and navigate to Birla Opus products
2. Select any product and add to cart
3. Verify cart shows ₹0.00 for that item
4. Place order and verify admin receives it

The zero-price workflow is now working as intended.

---
**Configuration:** Zero prices enabled for Birla Opus
**Date:** 2026-07-04
**Reason:** Admin determines final pricing during order processing
