-- BusControl PRO 4.0 RC: local-first cloud snapshots.
-- Execute once in Supabase SQL Editor.

begin;

create table if not exists public.app_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  payload_hash text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_snapshots enable row level security;

drop policy if exists "app_snapshots_select_own" on public.app_snapshots;
drop policy if exists "app_snapshots_insert_own" on public.app_snapshots;
drop policy if exists "app_snapshots_update_own" on public.app_snapshots;
drop policy if exists "app_snapshots_delete_own" on public.app_snapshots;

create policy "app_snapshots_select_own"
on public.app_snapshots for select
using (user_id = auth.uid());

create policy "app_snapshots_insert_own"
on public.app_snapshots for insert
with check (user_id = auth.uid());

create policy "app_snapshots_update_own"
on public.app_snapshots for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "app_snapshots_delete_own"
on public.app_snapshots for delete
using (user_id = auth.uid());

grant select, insert, update, delete
on public.app_snapshots
to authenticated;

commit;
