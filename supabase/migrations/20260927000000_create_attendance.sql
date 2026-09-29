create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  karyawan_id text not null,
  tipe_absen text not null,
  latitude double precision not null,
  longitude double precision not null,
  foto text not null,
  waktu timestamptz not null default now()
);

create index if not exists attendance_karyawan_waktu_idx
  on public.attendance (karyawan_id, waktu desc);

alter table public.attendance enable row level security;

drop policy if exists "Allow read attendance" on public.attendance;
create policy "Allow read attendance" on public.attendance
  for select to anon, authenticated using (true);

drop policy if exists "Allow insert attendance" on public.attendance;
create policy "Allow insert attendance" on public.attendance
  for insert to anon, authenticated with check (true);

comment on table public.attendance is
  'Attendance records with RLS policies enabled.';