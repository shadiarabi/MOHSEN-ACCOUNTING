-- ============================================================
-- MOHSEN ACCOUNTING — FULL SCHEMA
-- Run this once, top to bottom, in Supabase SQL Editor
-- (Settings → SQL Editor → New query → paste all → Run)
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ── CUSTOMERS ─────────────────────────────────────────────
create table if not exists customers (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  email text,
  phone text,
  address text,
  currency text default 'USD',
  opening_balance numeric default 0,
  created_at timestamptz default now()
);
alter table customers enable row level security;
create policy "allow all" on customers for all using (true) with check (true);

-- ── SUPPLIERS ─────────────────────────────────────────────
create table if not exists suppliers (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  email text,
  phone text,
  address text,
  currency text default 'USD',
  opening_balance numeric default 0,
  created_at timestamptz default now()
);
alter table suppliers enable row level security;
create policy "allow all" on suppliers for all using (true) with check (true);

-- ── PRODUCTS ──────────────────────────────────────────────
create table if not exists products (
  id uuid primary key default uuid_generate_v4(),
  code text,
  name text not null,
  category text default 'General',
  uom text,
  qty numeric default 0,
  reorder_level numeric default 10,
  cost_price numeric default 0,
  sell_price numeric default 0,
  created_at timestamptz default now()
);
alter table products enable row level security;
create policy "allow all" on products for all using (true) with check (true);

-- ── INVOICES ──────────────────────────────────────────────
create table if not exists invoices (
  id uuid primary key default uuid_generate_v4(),
  number text,
  customer_id uuid references customers(id) on delete set null,
  customer_name text,
  date date,
  due_date date,
  currency text,
  subtotal numeric default 0,
  discount_pct numeric default 0,
  total numeric default 0,
  base_amount numeric default 0,
  cogs numeric default 0,
  paid_amount numeric default 0,
  balance numeric default 0,
  status text default 'draft',
  notes text,
  taxa numeric,
  created_at timestamptz default now()
);
alter table invoices enable row level security;
create policy "allow all" on invoices for all using (true) with check (true);

-- ── INVOICE LINES ─────────────────────────────────────────
create table if not exists invoice_lines (
  id uuid primary key default uuid_generate_v4(),
  invoice_id uuid references invoices(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  product_name text,
  product_code text,
  qty numeric default 0,
  unit_price numeric default 0,
  discount_pct numeric default 0,
  commission_pct numeric default 0,
  commission_amt numeric default 0,
  line_total numeric default 0,
  cogs numeric default 0,
  imei text,
  created_at timestamptz default now()
);
alter table invoice_lines enable row level security;
create policy "allow all" on invoice_lines for all using (true) with check (true);

-- ── PURCHASES ─────────────────────────────────────────────
create table if not exists purchases (
  id uuid primary key default uuid_generate_v4(),
  number text,
  supplier_id uuid references suppliers(id) on delete set null,
  supplier_name text,
  date date,
  delivery_date date,
  currency text,
  total numeric default 0,
  base_amount numeric default 0,
  paid_amount numeric default 0,
  balance numeric default 0,
  status text default 'draft',
  created_at timestamptz default now()
);
alter table purchases enable row level security;
create policy "allow all" on purchases for all using (true) with check (true);

-- ── PURCHASE LINES ────────────────────────────────────────
create table if not exists purchase_lines (
  id uuid primary key default uuid_generate_v4(),
  purchase_id uuid references purchases(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  product_name text,
  product_code text,
  qty numeric default 0,
  unit_cost numeric default 0,
  line_total numeric default 0,
  created_at timestamptz default now()
);
alter table purchase_lines enable row level security;
create policy "allow all" on purchase_lines for all using (true) with check (true);

-- ── RECEIPTS (money IN from customers) ───────────────────
create table if not exists receipts (
  id uuid primary key default uuid_generate_v4(),
  date date,
  customer_id uuid references customers(id) on delete set null,
  customer_name text,
  invoice_id uuid references invoices(id) on delete set null,
  invoice_number text,
  currency text,
  amount numeric default 0,
  base_amount numeric default 0,
  method text,
  note text,
  created_at timestamptz default now()
);
alter table receipts enable row level security;
create policy "allow all" on receipts for all using (true) with check (true);

-- ── PAYMENTS (money OUT to suppliers) ────────────────────
create table if not exists payments (
  id uuid primary key default uuid_generate_v4(),
  date date,
  supplier_id uuid references suppliers(id) on delete set null,
  supplier_name text,
  purchase_id uuid references purchases(id) on delete set null,
  purchase_number text,
  currency text,
  amount numeric default 0,
  base_amount numeric default 0,
  method text,
  note text,
  created_at timestamptz default now()
);
alter table payments enable row level security;
create policy "allow all" on payments for all using (true) with check (true);

-- ── EXPENSES ──────────────────────────────────────────────
create table if not exists expenses (
  id uuid primary key default uuid_generate_v4(),
  date date,
  category text,
  description text,
  payee text,
  currency text,
  amount numeric default 0,
  base_amount numeric default 0,
  created_at timestamptz default now()
);
alter table expenses enable row level security;
create policy "allow all" on expenses for all using (true) with check (true);

-- ── INVENTORY BATCHES (FIFO costing) ─────────────────────
create table if not exists inventory_batches (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid references products(id) on delete cascade,
  purchase_id uuid references purchases(id) on delete set null,
  purchase_number text,
  date date,
  qty_received numeric default 0,
  qty_remaining numeric default 0,
  unit_cost numeric default 0,
  created_at timestamptz default now()
);
alter table inventory_batches enable row level security;
create policy "allow all" on inventory_batches for all using (true) with check (true);

-- ── STOCK ADJUSTMENTS (audit trail) ──────────────────────
create table if not exists stock_adjustments (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid references products(id),
  product_name text,
  product_code text,
  old_qty numeric,
  new_qty numeric,
  difference numeric,
  reason text,
  notes text,
  created_at timestamptz default now()
);
alter table stock_adjustments enable row level security;
create policy "allow all" on stock_adjustments for all using (true) with check (true);

-- ── SUPPLIER BALANCE ADJUSTMENTS (audit trail) ───────────
create table if not exists supplier_adjustments (
  id uuid primary key default uuid_generate_v4(),
  supplier_id uuid references suppliers(id),
  supplier_name text,
  old_balance numeric,
  new_balance numeric,
  difference numeric,
  reason text,
  notes text,
  created_at timestamptz default now()
);
alter table supplier_adjustments enable row level security;
create policy "allow all" on supplier_adjustments for all using (true) with check (true);

-- ── CAPITAL ENTRIES (owner investment / withdrawals) ─────
-- NEW: tracks Mohsen's starting capital and any future top-ups
-- so it shows on the Dashboard, Reports (Balance Sheet & Capital
-- page) as a proper owner-equity ledger — separate from revenue.
create table if not exists capital_entries (
  id uuid primary key default uuid_generate_v4(),
  date date not null default current_date,
  type text not null check (type in ('injection','withdrawal')),
  amount numeric not null,
  currency text default 'USD',
  base_amount numeric,
  note text,
  created_at timestamptz default now()
);
alter table capital_entries enable row level security;
create policy "allow all" on capital_entries for all using (true) with check (true);

-- ── SETTINGS (single row) ─────────────────────────────────
create table if not exists settings (
  id uuid primary key default uuid_generate_v4(),
  company text,
  address text,
  phone text,
  email text,
  vat_number text,
  invoice_prefix text default 'INV-',
  payment_terms integer default 30,
  base_currency text default 'USD',
  updated_at timestamptz default now()
);
alter table settings enable row level security;
create policy "allow all" on settings for all using (true) with check (true);

-- ── SEED DATA FOR MOHSEN ──────────────────────────────────
insert into settings (company, base_currency, invoice_prefix, payment_terms)
values ('Mohsen', 'USD', 'INV-', 30);

-- Starting capital: $100,000 USD injection, dated today
insert into capital_entries (date, type, amount, currency, base_amount, note)
values (current_date, 'injection', 100000, 'USD', 100000, 'Starting capital');
