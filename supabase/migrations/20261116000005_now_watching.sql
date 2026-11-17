-- friend-presence: what each account is watching now (design D1, D3, D4).
-- One row per account. "Not watching" is the row cleared (title null), not deleted:
-- Realtime sends DELETE events to every subscriber without RLS, while updates reach
-- only the subscribers the select policy lets read the row.

create table public.now_watching (
  user_id           uuid primary key references auth.users (id) on delete cascade,
  title             text check (char_length(title) between 1 and 200),
  channel_name      text check (char_length(channel_name) between 1 and 100),
  shared_channel_id uuid,
  started_at        timestamptz,
  updated_at        timestamptz not null default now(),
  -- Watching has a channel; cleared has nothing at all.
  check ((title is null and channel_name is null and shared_channel_id is null and started_at is null)
      or (channel_name is not null and started_at is not null))
);

-- The backend's clock, never the client's (staleness is measured against it).
create function public.now_watching_touch() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger now_watching_touch before insert or update on public.now_watching
  for each row execute function public.now_watching_touch();

alter table public.now_watching enable row level security;
revoke all on public.now_watching from anon;
grant select, insert, update, delete on public.now_watching to authenticated;

-- Read: your own row, and accepted friends' rows with no block either way.
create policy now_watching_select on public.now_watching for select to authenticated
using (
  user_id = (select auth.uid())
  or (
    exists (
      select 1 from public.friendships f
       where (f.user_a = (select auth.uid()) and f.user_b = now_watching.user_id)
          or (f.user_b = (select auth.uid()) and f.user_a = now_watching.user_id))
    and not exists (
      select 1 from public.blocks b
       where (b.blocker = (select auth.uid()) and b.blocked = now_watching.user_id)
          or (b.blocked = (select auth.uid()) and b.blocker = now_watching.user_id))
  )
);
-- Write: your own row only.
create policy now_watching_insert on public.now_watching for insert to authenticated
with check (user_id = (select auth.uid()));
create policy now_watching_update on public.now_watching for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy now_watching_delete on public.now_watching for delete to authenticated
using (user_id = (select auth.uid()));

-- Friends' apps follow the table through Postgres Changes (RLS applied per subscriber).
alter publication supabase_realtime add table public.now_watching;

-- Daily clean-up: rows not refreshed for an hour (a crash or a power cut) are cleared.
-- Cleared, not deleted, for the same reason as above.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
select cron.schedule('now-watching-cleanup', '17 4 * * *',
  $$update public.now_watching
       set title = null, channel_name = null, shared_channel_id = null, started_at = null
     where channel_name is not null and updated_at < now() - interval '1 hour'$$);

-- Show what I'm watching (D4): null until asked, then 'friends' or 'off'.
alter table public.share_profiles
  add column presence text check (presence in ('friends', 'off'));
