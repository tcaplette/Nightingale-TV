-- share-accounts: tables, checks, indexes and the block trigger (design D6).
-- Every table cascades from auth.users so deleting an account removes everything.

create extension if not exists pgcrypto with schema extensions;

create table public.share_profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 30),
  handle       text not null check (handle ~ '^[a-z0-9_]{3,20}$'),
  avatar       text not null default 'fox' check (avatar ~ '^[a-z0-9_]{1,40}$'),
  avatar_color integer not null default 0 check (avatar_color >= 0),
  station      text not null default '' check (char_length(station) <= 30),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create unique index share_profiles_handle_key on public.share_profiles (lower(handle));

create table public.friendships (
  user_a     uuid not null references auth.users (id) on delete cascade,
  user_b     uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index friendships_user_b_idx on public.friendships (user_b);

create table public.blocks (
  blocker    uuid not null references auth.users (id) on delete cascade,
  blocked    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index blocks_blocked_idx on public.blocks (blocked);

create table public.invites (
  code       text primary key check (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$'),
  owner      uuid not null references auth.users (id) on delete cascade,
  kind       text not null default 'friend' check (kind in ('friend', 'channels', 'watch')),
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by    uuid references auth.users (id) on delete set null,
  used_at    timestamptz
);
create index invites_owner_idx on public.invites (owner, kind);

create table public.redeem_attempts (
  id      bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  at      timestamptz not null default now(),
  ok      boolean not null
);
create index redeem_attempts_user_at_idx on public.redeem_attempts (user_id, at);

create table public.preview_hits (
  id      bigint generated always as identity primary key,
  ip_hash text not null,
  at      timestamptz not null default now()
);
create index preview_hits_hash_at_idx on public.preview_hits (ip_hash, at);

-- A block ends the friendship at once.
create function public.blocks_end_friendship() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.friendships
   where user_a = least(new.blocker, new.blocked)
     and user_b = greatest(new.blocker, new.blocked);
  return new;
end $$;

create trigger blocks_end_friendship after insert on public.blocks
  for each row execute function public.blocks_end_friendship();

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger share_profiles_touch before update on public.share_profiles
  for each row execute function public.touch_updated_at();
