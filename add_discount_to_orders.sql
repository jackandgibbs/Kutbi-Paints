ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS subtotal double precision DEFAULT 0.0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS discount_amount double precision DEFAULT 0.0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS discount_name text;
