-- ============================================================================
-- KUTBI PAINTS — SUPABASE SECURITY HARDENING  (🚨 RELEASE BLOCKER)
-- ============================================================================
--
-- WHY THIS EXISTS
-- ---------------
-- The app currently ships the Supabase URL + anon key inside the APK (.env is
-- bundled as a Flutter asset), and login is done CLIENT-SIDE: the app downloads
-- the ENTIRE `users` table and checks `phone == x && pin == y` locally
-- (see lib/services/data_service.dart -> login()).
--
-- If Row Level Security (RLS) is OFF on these tables (the Supabase default for
-- new tables), then ANYONE with the anon key — which is trivially extractable
-- from the APK — can read and write EVERY row: all users' phone numbers, their
-- PLAINTEXT PINs, bank account numbers and passbook URLs, all orders, prices,
-- and commissions. This is a catastrophic data breach and a Google Play
-- "User Data" policy violation.
--
-- ⚠️  DO NOT just enable RLS on its own. The current client-side login RELIES on
--     reading the whole users table with the anon key. Enabling RLS without the
--     auth change below will break login for everyone. Do the steps IN ORDER.
--
-- ----------------------------------------------------------------------------
-- STEP 1 — MOVE AUTHENTICATION SERVER-SIDE  (code + this SQL)
-- ----------------------------------------------------------------------------
-- Replace client-side credential checking with a SECURITY DEFINER RPC that
-- verifies the PIN on the server and returns ONLY the calling user's row.
-- PINs must be HASHED (never stored or compared in plaintext).

create extension if not exists pgcrypto;

-- 1a. Add a hashed-pin column (keep the old `pin` column until migration done).
alter table users add column if not exists pin_hash text;

-- 1b. One-time backfill: hash existing plaintext pins, then DROP the pin column.
--     Run once, verify, then: `alter table users drop column pin;`
update users set pin_hash = crypt(pin, gen_salt('bf'))
  where pin_hash is null and pin is not null;

-- 1c. Server-side login. Returns the user row only when the PIN matches.
--     The app calls: supabase.rpc('login_with_pin', { p_phone, p_pin })
create or replace function login_with_pin(p_phone text, p_pin text)
returns setof users
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
    select * from users
    where phone = p_phone
      and pin_hash = crypt(p_pin, pin_hash);
end;
$$;

-- 1d. Setting/updating a PIN must also hash. Example RPC:
create or replace function set_user_pin(p_user_id uuid, p_pin text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update users set pin_hash = crypt(p_pin, gen_salt('bf')) where id = p_user_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- STEP 2 — ENABLE RLS ON EVERY TABLE  (only AFTER step 1 + code are shipped)
-- ----------------------------------------------------------------------------
-- With login going through the SECURITY DEFINER RPC above (which bypasses RLS
-- safely and returns a single row), you can lock every table down. Adjust table
-- names to match your schema.

alter table users     enable row level security;
alter table products  enable row level security;
alter table orders    enable row level security;
alter table brands    enable row level security;
alter table banners   enable row level security;
-- ...repeat for brand_categories, bills, ledger, etc.

-- 2a. READ-ONLY public catalog data is fine to expose to the anon key:
create policy "anon can read products" on products for select using (true);
create policy "anon can read brands"   on brands   for select using (true);
create policy "anon can read banners"  on banners  for select using (is_active);

-- 2b. Sensitive tables: NO anon access. All writes/admin reads must go through
--     authenticated Supabase sessions or SECURITY DEFINER RPCs. Example: block
--     the anon role entirely and only allow the service role / RPCs.
--     (Do NOT create broad `using (true)` policies on users/orders.)
revoke all on users  from anon;
revoke all on orders from anon;

-- ----------------------------------------------------------------------------
-- STEP 3 — STOP SHIPPING BUSINESS LOGIC / PRICES THE CLIENT SHOULDN'T SET
-- ----------------------------------------------------------------------------
-- Order totals, commissions and "approved" states must be computed/validated
-- server-side (DB triggers or RPCs), never trusted from the client, since the
-- client can be tampered with.
--
-- ============================================================================
-- Until STEP 1 + STEP 2 are complete, treat the backend as PUBLICLY WRITABLE.
-- This is the single biggest blocker to a safe public release.
-- ============================================================================
