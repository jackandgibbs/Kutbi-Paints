-- Run this in Supabase SQL Editor before using the QR generator page.

create table if not exists qr_codes (
  id text primary key,
  batch_id text not null,
  qr_value text not null,
  points integer not null default 50,
  color_scheme text not null default 'teal',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  used_at timestamptz,
  used_by text,
  used_by_name text,
  quantity integer not null default 1,
  message text,
  created_by text,
  custom_logo_base64 text,
  scans integer not null default 0
);

create index if not exists qr_codes_batch_id_idx on qr_codes(batch_id);
create index if not exists qr_codes_status_idx on qr_codes(status);
create index if not exists qr_codes_created_at_idx on qr_codes(created_at desc);

alter table qr_codes enable row level security;

drop policy if exists "qr_codes_select" on qr_codes;
drop policy if exists "qr_codes_insert" on qr_codes;
drop policy if exists "qr_codes_update" on qr_codes;
drop policy if exists "qr_codes_delete" on qr_codes;

create policy "qr_codes_select" on qr_codes
for select using (true);

create policy "qr_codes_insert" on qr_codes
for insert with check (true);

create policy "qr_codes_update" on qr_codes
for update using (true);

create policy "qr_codes_delete" on qr_codes
for delete using (true);
