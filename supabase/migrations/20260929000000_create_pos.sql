create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null,
  price integer not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  variants jsonb not null default '[]'::jsonb,
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id text primary key,
  cashier_id text not null,
  cashier_name text not null,
  terminal_id text not null default 'POS-01',
  order_type text not null default 'Dine-in',
  payment_method text not null,
  subtotal integer not null check (subtotal >= 0),
  tax integer not null default 0 check (tax >= 0),
  discount integer not null default 0 check (discount >= 0),
  total integer not null check (total >= 0),
  status text not null default 'Sukses',
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.orders(id) on delete cascade,
  product_id text not null,
  product_name text not null,
  variant text not null default '',
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  total integer not null check (total >= 0)
);

create table if not exists public.shifts (
  id text primary key,
  cashier_id text not null,
  cashier_name text not null,
  terminal_id text not null default 'POS-01',
  opening_float integer not null default 0 check (opening_float >= 0),
  actual_cash integer,
  closing_note text,
  status text not null default 'open' check (status in ('open', 'closed')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz
);

create index if not exists orders_created_at_idx
  on public.orders (created_at desc);
create index if not exists orders_cashier_created_at_idx
  on public.orders (cashier_id, created_at desc);
create index if not exists order_items_order_id_idx
  on public.order_items (order_id);
create index if not exists shifts_cashier_status_idx
  on public.shifts (cashier_id, status, opened_at desc);

insert into public.products (id, name, category, price, stock, variants, image_url)
values
  ('ESP-001', 'Espresso Double Shot', 'Kopi & Minuman', 24000, 35, '["Hot", "Extra Shot"]', 'https://images.unsplash.com/photo-1510707577719-ae7c14805e3a?auto=format&fit=crop&w=640&q=85'),
  ('MAC-001', 'Caramel Macchiato', 'Kopi & Minuman', 38000, 18, '["Less Sugar", "Extra Ice", "Hot"]', 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=640&q=85'),
  ('MAT-001', 'Matcha Latte', 'Kopi & Minuman', 36000, 22, '["Oat Milk", "Less Sugar", "Extra Ice"]', 'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?auto=format&fit=crop&w=640&q=85'),
  ('CRS-001', 'Croissant Butter Almond', 'Makanan Utama', 32000, 9, '["Hangatkan"]', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=640&q=85'),
  ('FRY-001', 'French Fries', 'Snack & Pastry', 35000, 14, '["Saus Terpisah", "Extra Saus"]', 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=640&q=85'),
  ('BUR-001', 'Classic Cheeseburger', 'Makanan Utama', 48000, 12, '["No Onion", "Extra Cheese"]', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=640&q=85'),
  ('TEA-001', 'Iced Peach Lemon Tea', 'Kopi & Minuman', 28000, 40, '["Less Sugar", "No Ice"]', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=640&q=85')
on conflict (id) do nothing;

alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.shifts enable row level security;

drop policy if exists "POS can read active products" on public.products;
create policy "POS can read active products" on public.products
  for select to anon, authenticated using (active);

drop policy if exists "POS can read orders" on public.orders;
create policy "POS can read orders" on public.orders
  for select to anon, authenticated using (true);
drop policy if exists "POS can void orders" on public.orders;
create policy "POS can void orders" on public.orders
  for update to anon, authenticated using (true) with check (true);

drop policy if exists "POS can read order items" on public.order_items;
create policy "POS can read order items" on public.order_items
  for select to anon, authenticated using (true);

drop policy if exists "POS can read shifts" on public.shifts;
create policy "POS can read shifts" on public.shifts
  for select to anon, authenticated using (true);
drop policy if exists "POS can create shifts" on public.shifts;
create policy "POS can create shifts" on public.shifts
  for insert to anon, authenticated with check (true);
drop policy if exists "POS can close shifts" on public.shifts;
create policy "POS can close shifts" on public.shifts
  for update to anon, authenticated using (true) with check (true);

create or replace function public.pos_create_order(p_order jsonb, p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
begin
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    update public.products
    set stock = stock - (v_item->>'quantity')::integer
    where id = v_item->>'product_id'
      and stock >= (v_item->>'quantity')::integer;

    if not found then
      raise exception 'Stok tidak cukup untuk produk %', v_item->>'product_name'
        using errcode = 'P0001';
    end if;
  end loop;

  insert into public.orders (
    id, cashier_id, cashier_name, terminal_id, order_type, payment_method,
    subtotal, tax, discount, total, status, created_at
  ) values (
    p_order->>'id', p_order->>'cashier_id', p_order->>'cashier_name',
    coalesce(p_order->>'terminal_id', 'POS-01'),
    coalesce(p_order->>'order_type', 'Dine-in'), p_order->>'payment_method',
    (p_order->>'subtotal')::integer, (p_order->>'tax')::integer,
    (p_order->>'discount')::integer, (p_order->>'total')::integer,
    coalesce(p_order->>'status', 'Sukses'),
    coalesce((p_order->>'created_at')::timestamptz, now())
  );

  insert into public.order_items (
    order_id, product_id, product_name, variant, quantity, unit_price, total
  )
  select
    p_order->>'id', elem->>'product_id', elem->>'product_name',
    coalesce(elem->>'variant', ''), (elem->>'quantity')::integer,
    (elem->>'unit_price')::integer, (elem->>'total')::integer
  from jsonb_array_elements(p_items) as elem;
end;
$$;

revoke all on function public.pos_create_order(jsonb, jsonb) from public;
grant execute on function public.pos_create_order(jsonb, jsonb) to anon, authenticated;

comment on function public.pos_create_order(jsonb, jsonb) is
  'Atomic POS checkout endpoint for the demo client. Restrict with authenticated role policies before production.';