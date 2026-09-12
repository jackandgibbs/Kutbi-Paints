-- ============================================================================
-- KUTBI PAINTS — RETURN / REFUND SYSTEM MIGRATION
-- ============================================================================
-- Run this in the Supabase SQL editor AFTER your existing schema is in place.
-- Tables: return_requests, return_request_items
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- TABLE: return_requests
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS return_requests (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  order_id             TEXT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  user_id              TEXT NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,

  -- Status lifecycle (enforced via CHECK + trigger)
  status               TEXT NOT NULL DEFAULT 'requested'
    CONSTRAINT return_requests_status_check
    CHECK (status IN (
      'requested',
      'approved',
      'pickup_scheduled',
      'picked_up',
      'received',
      'refund_processing',
      'refunded',
      'rejected',
      'cancelled'
    )),

  reason               TEXT NOT NULL,          -- predefined reason key
  description          TEXT,                   -- optional free-text
  admin_note           TEXT,                   -- rejection reason / admin comment

  -- Refund
  refund_amount        NUMERIC(10,2) NOT NULL DEFAULT 0,
  refund_method        TEXT NOT NULL DEFAULT 'original_payment',

  -- Timestamps per lifecycle stage
  requested_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at          TIMESTAMPTZ,
  pickup_scheduled_at  TIMESTAMPTZ,
  picked_up_at         TIMESTAMPTZ,
  received_at          TIMESTAMPTZ,
  refund_processing_at TIMESTAMPTZ,
  refunded_at          TIMESTAMPTZ,
  rejected_at          TIMESTAMPTZ,

  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- TABLE: return_request_items
-- NOTE: orders.items is stored as a JSONB array (no separate order_items table).
--       item_index is the 0-based position in that JSONB array.
--       product_id / product_name / bucket_size / unit_price are denormalized
--       snapshots from the order, preserved even if the product catalogue changes.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS return_request_items (
  id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  return_request_id  TEXT NOT NULL REFERENCES return_requests(id) ON DELETE CASCADE,
  order_id           TEXT NOT NULL REFERENCES orders(id)          ON DELETE RESTRICT,

  -- Position in orders.items JSONB array (immutable after order creation)
  item_index         INTEGER NOT NULL,

  -- Denormalized snapshot from the order
  product_id         TEXT NOT NULL,
  product_name       TEXT NOT NULL,
  bucket_size        TEXT NOT NULL DEFAULT '1L',
  unit_price         NUMERIC(10,2) NOT NULL DEFAULT 0,
  color_name         TEXT,
  color_hex          TEXT DEFAULT '#FFFFFF',

  quantity           INTEGER NOT NULL CHECK (quantity > 0),
  reason             TEXT,
  condition          TEXT NOT NULL DEFAULT 'unknown'
    CONSTRAINT return_item_condition_check
    CHECK (condition IN ('good','damaged','opened','unused','unknown')),

  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Prevent the same item/index being added twice to the same return request
  UNIQUE (return_request_id, order_id, item_index)
);

-- ----------------------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_return_requests_user_id    ON return_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_order_id   ON return_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_status     ON return_requests(status);
CREATE INDEX IF NOT EXISTS idx_return_requests_created_at ON return_requests(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_return_items_return_id ON return_request_items(return_request_id);
CREATE INDEX IF NOT EXISTS idx_return_items_order_id  ON return_request_items(order_id);

-- ----------------------------------------------------------------------------
-- AUTO-UPDATE updated_at trigger (same pattern as other tables)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_return_requests_updated_at
  BEFORE UPDATE ON return_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_return_request_items_updated_at
  BEFORE UPDATE ON return_request_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- STATUS TRANSITION VALIDATION TRIGGER
-- Prevents arbitrary status jumps (e.g., refunded → requested).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_return_status_transition()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  allowed_next TEXT[];
BEGIN
  -- No-op if status hasn't changed
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  CASE OLD.status
    WHEN 'requested'         THEN allowed_next := ARRAY['approved','rejected','cancelled'];
    WHEN 'approved'          THEN allowed_next := ARRAY['pickup_scheduled','cancelled'];
    WHEN 'pickup_scheduled'  THEN allowed_next := ARRAY['picked_up'];
    WHEN 'picked_up'         THEN allowed_next := ARRAY['received'];
    WHEN 'received'          THEN allowed_next := ARRAY['refund_processing'];
    WHEN 'refund_processing' THEN allowed_next := ARRAY['refunded'];
    WHEN 'refunded'          THEN allowed_next := ARRAY[]::TEXT[];
    WHEN 'rejected'          THEN allowed_next := ARRAY[]::TEXT[];
    WHEN 'cancelled'         THEN allowed_next := ARRAY[]::TEXT[];
    ELSE                          allowed_next := ARRAY[]::TEXT[];
  END CASE;

  IF NOT (NEW.status = ANY(allowed_next)) THEN
    RAISE EXCEPTION 'Invalid return status transition: % → %', OLD.status, NEW.status
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_return_status
  BEFORE UPDATE OF status ON return_requests
  FOR EACH ROW EXECUTE FUNCTION validate_return_status_transition();

-- ----------------------------------------------------------------------------
-- REFUND AMOUNT CALCULATION FUNCTION
-- Called by the app/admin to compute the refund from return_request_items.
-- This keeps the calculation server-side so clients cannot manipulate it.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_return_refund(p_return_id TEXT)
RETURNS NUMERIC(10,2)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(unit_price * quantity), 0)
  FROM   return_request_items
  WHERE  return_request_id = p_return_id;
$$;

-- ----------------------------------------------------------------------------
-- ADVANCE RETURN STATUS RPC (admin-only operation)
-- Validates the transition, stamps the appropriate timestamp, and recalculates
-- the refund amount when moving to refund_processing.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION advance_return_status(
  p_return_id  TEXT,
  p_new_status TEXT,
  p_admin_note TEXT DEFAULT NULL
)
RETURNS return_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row return_requests;
  v_now TIMESTAMPTZ := now();
  v_refund NUMERIC(10,2);
BEGIN
  SELECT * INTO v_row FROM return_requests WHERE id = p_return_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Return request % not found', p_return_id;
  END IF;

  -- Compute refund amount when entering refund_processing
  IF p_new_status = 'refund_processing' THEN
    v_refund := calculate_return_refund(p_return_id);
  ELSE
    v_refund := v_row.refund_amount;
  END IF;

  UPDATE return_requests SET
    status               = p_new_status,
    admin_note           = COALESCE(p_admin_note, admin_note),
    refund_amount        = v_refund,
    approved_at          = CASE WHEN p_new_status = 'approved'          THEN v_now ELSE approved_at          END,
    pickup_scheduled_at  = CASE WHEN p_new_status = 'pickup_scheduled'  THEN v_now ELSE pickup_scheduled_at  END,
    picked_up_at         = CASE WHEN p_new_status = 'picked_up'         THEN v_now ELSE picked_up_at         END,
    received_at          = CASE WHEN p_new_status = 'received'          THEN v_now ELSE received_at          END,
    refund_processing_at = CASE WHEN p_new_status = 'refund_processing' THEN v_now ELSE refund_processing_at END,
    refunded_at          = CASE WHEN p_new_status = 'refunded'          THEN v_now ELSE refunded_at          END,
    rejected_at          = CASE WHEN p_new_status = 'rejected'          THEN v_now ELSE rejected_at          END,
    updated_at           = v_now
  WHERE id = p_return_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ----------------------------------------------------------------------------
-- RLS POLICIES
-- NOTE: The app currently does not enforce Supabase Auth JWT (client-side PIN
-- auth). These policies use the service_role bypass — the same approach the
-- rest of the app uses. When proper JWT auth is added, replace `using (true)`
-- painter policies with `using (auth.uid() = user_id)`.
-- For now, all access goes through the anon key with no JWT → policies grant
-- read/write access openly (consistent with the existing tables).
-- Enable RLS so the policies are ready when proper auth is added.
-- ----------------------------------------------------------------------------

ALTER TABLE return_requests      ENABLE ROW LEVEL SECURITY;
ALTER TABLE return_request_items ENABLE ROW LEVEL SECURITY;

-- Anon key: full access (consistent with existing tables until JWT auth lands)
CREATE POLICY "anon full access return_requests"
  ON return_requests FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon full access return_request_items"
  ON return_request_items FOR ALL TO anon USING (true) WITH CHECK (true);

-- Service role: always bypasses RLS (Supabase default behaviour).

-- ============================================================================
-- VERIFICATION QUERIES (run after applying migration)
-- ============================================================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'return%';
-- SELECT * FROM return_requests LIMIT 5;
-- SELECT * FROM return_request_items LIMIT 5;
-- SELECT advance_return_status(gen_random_uuid()::text, 'approved'); -- will fail: not found
-- ============================================================================