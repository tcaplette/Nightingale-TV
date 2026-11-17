-- channel-sharing: shared channel recipes and the shares of them (design D4).
-- Both cascade from auth.users, so deleting either account removes them.

create table public.shared_channels (
  -- Made by the sender's app (its channel's share link keeps it), so
  -- republishing updates the same row.
  id         uuid primary key,
  owner      uuid not null references auth.users (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 200),
  recipe     jsonb not null check (octet_length(recipe::text) <= 2000000),
  version    integer not null default 1 check (version >= 1),
  updated_at timestamptz not null default now(),
  stopped_at timestamptz
);
create index shared_channels_owner_idx on public.shared_channels (owner);

create table public.channel_shares (
  id                uuid primary key default gen_random_uuid(),
  shared_channel_id uuid not null references public.shared_channels (id) on delete cascade,
  recipient         uuid not null references auth.users (id) on delete cascade,
  created_at        timestamptz not null default now(),
  state             text not null default 'new' check (state in ('new', 'added', 'declined')),
  ended_at          timestamptz,
  unique (shared_channel_id, recipient)
);
create index channel_shares_recipient_idx on public.channel_shares (recipient);

-- Two accounts stop being friends (removed, or a block): every share
-- between them ends, both ways.
create function public.friendship_end_shares() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.channel_shares cs set ended_at = now()
    from public.shared_channels sc
   where cs.shared_channel_id = sc.id
     and cs.ended_at is null
     and ((sc.owner = old.user_a and cs.recipient = old.user_b)
       or (sc.owner = old.user_b and cs.recipient = old.user_a));
  return old;
end $$;

create trigger friendship_end_shares after delete on public.friendships
  for each row execute function public.friendship_end_shares();

-- Stop sharing (the sender sets stopped_at): every share of it ends.
create function public.shared_channel_stopped() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.stopped_at is not null and old.stopped_at is null then
    update public.channel_shares set ended_at = now()
     where shared_channel_id = new.id and ended_at is null;
  end if;
  return new;
end $$;

create trigger shared_channel_stopped after update of stopped_at on public.shared_channels
  for each row execute function public.shared_channel_stopped();

-- ---- Row-level security ------------------------------------------------------

alter table public.shared_channels enable row level security;
alter table public.channel_shares  enable row level security;

revoke all on public.shared_channels, public.channel_shares from anon;
-- The sender publishes through share-channels; directly it may only stop
-- sharing or remove the row.
revoke insert, update on public.shared_channels from authenticated;
grant update (stopped_at) on public.shared_channels to authenticated;
-- Shares are made by share-channels and redeem-invite; the receiver may
-- change only its own Add or Decline state.
revoke insert, update, delete on public.channel_shares from authenticated;
grant update (state) on public.channel_shares to authenticated;

-- The sender sees its own; a receiver sees one while it has an active share.
create policy shared_channels_select on public.shared_channels for select to authenticated
using (
  owner = (select auth.uid())
  or exists (
    select 1 from public.channel_shares cs
     where cs.shared_channel_id = shared_channels.id
       and cs.recipient = (select auth.uid())
       and cs.ended_at is null)
);
create policy shared_channels_update on public.shared_channels for update to authenticated
using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy shared_channels_delete on public.shared_channels for delete to authenticated
using (owner = (select auth.uid()));

-- A share's sender and receiver see it. The sender is found without the
-- shared_channels policy, so an ended share's receiver still sees it ended.
create function public.shared_channel_owner(p_id uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select owner from public.shared_channels where id = p_id;
$$;
revoke all on function public.shared_channel_owner(uuid) from public, anon;
grant execute on function public.shared_channel_owner(uuid) to authenticated;

create policy channel_shares_select on public.channel_shares for select to authenticated
using (
  recipient = (select auth.uid())
  or public.shared_channel_owner(shared_channel_id) = (select auth.uid())
);
create policy channel_shares_update on public.channel_shares for update to authenticated
using (recipient = (select auth.uid())) with check (recipient = (select auth.uid()));

-- What a receiver needs to show a share, ended ones included: the sender's
-- profile, the channel's name and version. Never the recipe.
create function public.my_channel_shares() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', cs.id, 'shared_channel_id', sc.id, 'state', cs.state,
      'created_at', cs.created_at, 'ended_at', cs.ended_at,
      'name', sc.name, 'version', sc.version,
      'from', public.share_profile_json(sc.owner))
    order by cs.created_at), '[]'::jsonb)
    from public.channel_shares cs join public.shared_channels sc on sc.id = cs.shared_channel_id
   where cs.recipient = (select auth.uid());
$$;
revoke all on function public.my_channel_shares() from public, anon;
grant execute on function public.my_channel_shares() to authenticated;

-- ---- Sending -----------------------------------------------------------------

-- Publishes [p_recipes] ([{id, name, recipe}]) for [p_owner] and shares them
-- with [p_to] (friends only) or, with [p_link], makes a `channels` invite.
-- A recipe whose content changed gets version + 1. Service role only.
create function public.share_channels(p_owner uuid, p_recipes jsonb, p_to uuid[], p_link boolean)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  r jsonb;
  v_id uuid;
  v_row public.shared_channels;
  v_ids uuid[] := '{}';
  v_out jsonb := '[]'::jsonb;
  v_to uuid;
  v_invite jsonb;
begin
  if not exists (select 1 from public.share_profiles where user_id = p_owner) then
    return jsonb_build_object('status', 'no_profile');
  end if;
  if jsonb_typeof(p_recipes) <> 'array' or jsonb_array_length(p_recipes) = 0
     or jsonb_array_length(p_recipes) > 50 then
    return jsonb_build_object('status', 'bad_request');
  end if;
  foreach v_to in array coalesce(p_to, '{}') loop
    if not exists (select 1 from public.friendships
                    where user_a = least(p_owner, v_to) and user_b = greatest(p_owner, v_to)) then
      return jsonb_build_object('status', 'not_friends');
    end if;
  end loop;
  for r in select * from jsonb_array_elements(p_recipes) loop
    v_id := (r->>'id')::uuid;
    if exists (select 1 from public.shared_channels where id = v_id and owner <> p_owner) then
      return jsonb_build_object('status', 'bad_request');
    end if;
    if (r->'recipe'->>'v') is null
       or jsonb_array_length(coalesce(r->'recipe'->'items', '[]'::jsonb)) > 20000 then
      return jsonb_build_object('status', 'too_big');
    end if;
    insert into public.shared_channels as sc (id, owner, name, recipe)
      values (v_id, p_owner, left(coalesce(nullif(r->>'name', ''), '?'), 200), r->'recipe')
    on conflict (id) do update
      set name = excluded.name,
          recipe = excluded.recipe,
          version = case when sc.recipe = excluded.recipe then sc.version else sc.version + 1 end,
          updated_at = case when sc.recipe = excluded.recipe then sc.updated_at else now() end,
          -- Sharing a stopped channel again starts it again.
          stopped_at = case when p_link or cardinality(coalesce(p_to, '{}')) > 0 then null else sc.stopped_at end
    returning * into v_row;
    v_ids := v_ids || v_id;
    v_out := v_out || jsonb_build_object('id', v_row.id, 'version', v_row.version);
    foreach v_to in array coalesce(p_to, '{}') loop
      insert into public.channel_shares (shared_channel_id, recipient)
        values (v_id, v_to)
      on conflict (shared_channel_id, recipient) do update
        set ended_at = null,
            state = case when channel_shares.ended_at is null then channel_shares.state else 'new' end,
            created_at = case when channel_shares.ended_at is null then channel_shares.created_at else now() end;
    end loop;
  end loop;
  if p_link then
    v_invite := public.make_invite(p_owner, 'channels', jsonb_build_object('channels', to_jsonb(v_ids)));
    return jsonb_build_object('status', 'ok', 'channels', v_out, 'code', v_invite->'code',
                              'expires_at', v_invite->'expires_at');
  end if;
  return jsonb_build_object('status', 'ok', 'channels', v_out);
end $$;

-- ---- Invites: the channels kind ----------------------------------------------

create or replace function public.share_check_invite(p_user uuid, p_code text, out v_invite public.invites,
                                                     out v_status text)
language plpgsql volatile set search_path = public as $$
begin
  delete from public.redeem_attempts where at < now() - interval '1 day';
  if public.share_redeem_limited(p_user) then
    v_status := 'limited';
    return;
  end if;
  select * into v_invite from public.invites
   where code = upper(p_code) and kind in ('friend', 'channels')
   for update;
  if v_invite.code is null or v_invite.used_at is not null or v_invite.expires_at <= now()
     or not exists (select 1 from public.share_profiles where user_id = v_invite.owner) then
    v_status := 'gone';
  elsif v_invite.owner = p_user then
    v_status := 'own';
    return;
  elsif exists (select 1 from public.blocks
                 where (blocker = v_invite.owner and blocked = p_user)
                    or (blocker = p_user and blocked = v_invite.owner)) then
    -- Blocks are never revealed: they look like an expired code.
    v_status := 'gone';
  else
    v_status := 'ok';
    return;
  end if;
  insert into public.redeem_attempts (user_id, ok) values (p_user, false);
  v_invite := null;
end $$;

-- The live channels of a `channels` invite, in the sender's order.
create function public.invite_channel_names(p_invite public.invites) returns jsonb
language sql stable set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', sc.name) order by ids.ord), '[]'::jsonb)
    from jsonb_array_elements_text(coalesce(p_invite.payload->'channels', '[]'::jsonb))
         with ordinality as ids(id, ord)
    join public.shared_channels sc on sc.id = ids.id::uuid
   where sc.owner = p_invite.owner and sc.stopped_at is null;
$$;

create or replace function public.peek_invite(p_user uuid, p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
  v_out jsonb;
begin
  select * into c from public.share_check_invite(p_user, p_code);
  if c.v_status <> 'ok' then
    return jsonb_build_object('status', c.v_status);
  end if;
  v_out := jsonb_build_object('status', 'ok', 'kind', (c.v_invite).kind,
                              'from', public.share_profile_json((c.v_invite).owner));
  if (c.v_invite).kind = 'channels' then
    v_out := v_out || jsonb_build_object('channels', public.invite_channel_names(c.v_invite));
  end if;
  return v_out;
end $$;

-- Redeem in one transaction: limit, look up, checks, mark used, make
-- friends, and for a `channels` invite the shares.
create or replace function public.redeem_invite(p_user uuid, p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
  v_owner uuid;
  v_count int := 0;
begin
  if not exists (select 1 from public.share_profiles where user_id = p_user) then
    return jsonb_build_object('status', 'no_profile');
  end if;
  select * into c from public.share_check_invite(p_user, p_code);
  if c.v_status <> 'ok' then
    return jsonb_build_object('status', c.v_status);
  end if;
  v_owner := (c.v_invite).owner;
  update public.invites set used_by = p_user, used_at = now() where code = (c.v_invite).code;
  insert into public.friendships (user_a, user_b)
    values (least(p_user, v_owner), greatest(p_user, v_owner))
    on conflict do nothing;
  if (c.v_invite).kind = 'channels' then
    insert into public.channel_shares (shared_channel_id, recipient)
      select sc.id, p_user
        from jsonb_array_elements_text(coalesce((c.v_invite).payload->'channels', '[]'::jsonb)) ids(id)
        join public.shared_channels sc on sc.id = ids.id::uuid
       where sc.owner = v_owner and sc.stopped_at is null
    on conflict (shared_channel_id, recipient) do update
      set ended_at = null, state = 'new', created_at = now()
      where channel_shares.ended_at is not null;
    get diagnostics v_count = row_count;
  end if;
  insert into public.redeem_attempts (user_id, ok) values (p_user, true);
  return jsonb_build_object('status', 'ok', 'kind', (c.v_invite).kind, 'channels', v_count,
                            'friend', public.share_profile_json(v_owner));
end $$;

-- Website preview, with the channel names of a `channels` invite.
create or replace function public.invite_preview(p_code text, p_ip_hash text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_inv public.invites;
  v_p public.share_profiles;
  v_from jsonb;
  v_body jsonb;
begin
  delete from public.preview_hits where at < now() - interval '1 day';
  insert into public.preview_hits (ip_hash) values (p_ip_hash);
  if (select count(*) from public.preview_hits
       where ip_hash = p_ip_hash and at > now() - interval '10 minutes') > 30 then
    return jsonb_build_object('status', 429);
  end if;
  select * into v_inv from public.invites
   where code = upper(p_code) and used_at is null and expires_at > now();
  if v_inv.code is null then
    return jsonb_build_object('status', 404);
  end if;
  select * into v_p from public.share_profiles where user_id = v_inv.owner;
  if v_p.user_id is null then
    return jsonb_build_object('status', 404);
  end if;
  v_from := jsonb_build_object('name', v_p.display_name, 'handle', v_p.handle);
  if v_p.station <> '' then
    v_from := v_from || jsonb_build_object('station', v_p.station);
  end if;
  v_body := jsonb_build_object('kind', v_inv.kind, 'from', v_from, 'expires_at', v_inv.expires_at);
  if v_inv.kind = 'channels' then
    v_body := v_body || jsonb_build_object('channels', public.invite_channel_names(v_inv));
  end if;
  return jsonb_build_object('status', 200, 'body', v_body);
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'share_channels(uuid, jsonb, uuid[], boolean)', 'invite_channel_names(public.invites)',
    'share_check_invite(uuid, text)', 'peek_invite(uuid, text)', 'redeem_invite(uuid, text)',
    'invite_preview(text, text)', 'friendship_end_shares()', 'shared_channel_stopped()']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;
