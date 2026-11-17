-- watch-together: parties, members, invites, data rules and Realtime topics (design D7).
-- Everything cascades from auth.users: a party goes with its host's account, a member's
-- and an invitee's rows with theirs. Nothing here is ever deleted by the apps: leaving and
-- ending are updates, because Realtime sends DELETE events to every subscriber without RLS.

create table public.watch_parties (
  id           uuid primary key default gen_random_uuid(),
  host         uuid not null references auth.users (id) on delete cascade,
  channel_name text not null check (char_length(channel_name) between 1 and 100),
  -- The host's latest timeline, for late joiners (D1). Only the host writes it.
  state        jsonb not null default '{}'::jsonb check (pg_column_size(state) <= 8192),
  created_at   timestamptz not null default now(),
  -- The host's last write, by the backend's clock: "host gone" is judged on it (D7).
  beat_at      timestamptz not null default now(),
  ended_at     timestamptz
);
create index watch_parties_host_idx on public.watch_parties (host) where ended_at is null;

create table public.party_members (
  party_id  uuid not null references public.watch_parties (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at   timestamptz,
  primary key (party_id, user_id)
);
create index party_members_user_idx on public.party_members (user_id);

create table public.party_invites (
  party_id   uuid not null references public.watch_parties (id) on delete cascade,
  invitee    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- new → joined | dismissed (Not now); ended when the party ends.
  state      text not null default 'new' check (state in ('new', 'joined', 'dismissed', 'ended')),
  primary key (party_id, invitee)
);
create index party_invites_invitee_idx on public.party_invites (invitee);

-- The host's writes keep beat_at on the backend's clock.
create function public.watch_parties_touch() returns trigger
language plpgsql set search_path = public as $$
begin
  new.beat_at := now();
  return new;
end $$;

create trigger watch_parties_touch before update on public.watch_parties
  for each row execute function public.watch_parties_touch();

-- ---- Who belongs (security definer: the policies below use them without recursing) ----

-- An active member of a live party (the host is a member too).
create function public.party_active_member(p_party uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.party_members m
      join public.watch_parties w on w.id = m.party_id
     where m.party_id = p_party and m.user_id = p_user and m.left_at is null and w.ended_at is null);
$$;

-- Anyone who was ever in [p_party] or invited to it, or its host.
create function public.party_related(p_party uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.watch_parties w where w.id = p_party and w.host = p_user)
      or exists (select 1 from public.party_members m where m.party_id = p_party and m.user_id = p_user)
      or exists (select 1 from public.party_invites i where i.party_id = p_party and i.invitee = p_user);
$$;

-- Ever a member of [p_party] (left or not).
create function public.party_was_member(p_party uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.party_members m where m.party_id = p_party and m.user_id = p_user);
$$;

create function public.party_host_of(p_party uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select host from public.watch_parties where id = p_party;
$$;

-- ---- Row-level security ------------------------------------------------------------

alter table public.watch_parties enable row level security;
alter table public.party_members enable row level security;
alter table public.party_invites enable row level security;
revoke all on public.watch_parties, public.party_members, public.party_invites from anon, authenticated;
grant select on public.watch_parties, public.party_members, public.party_invites to authenticated;
-- The host writes the timeline; an invitee answers Not now. Everything else goes through
-- start-party, join-party and leave-party.
grant update (state) on public.watch_parties to authenticated;
grant update (state) on public.party_invites to authenticated;

-- watch_parties: its members (past and present), invitees and host.
create policy watch_parties_select on public.watch_parties for select to authenticated
using (public.party_related(id, (select auth.uid())));
-- Only the host, only while it's on.
create policy watch_parties_update on public.watch_parties for update to authenticated
using (host = (select auth.uid()) and ended_at is null)
with check (host = (select auth.uid()));

-- party_members: the party's members and host (an invitee sees who's in once joined).
create policy party_members_select on public.party_members for select to authenticated
using (
  user_id = (select auth.uid())
  or public.party_host_of(party_id) = (select auth.uid())
  or public.party_was_member(party_id, (select auth.uid()))
);

-- party_invites: the host and the invitee; the invitee may dismiss it.
create policy party_invites_select on public.party_invites for select to authenticated
using (invitee = (select auth.uid()) or public.party_host_of(party_id) = (select auth.uid()));
create policy party_invites_update on public.party_invites for update to authenticated
using (invitee = (select auth.uid()))
with check (invitee = (select auth.uid()) and state = 'dismissed');

-- Members see joins and leaves, invitees see invites, through Postgres Changes (RLS applied
-- per subscriber).
alter publication supabase_realtime add table public.party_members;
alter publication supabase_realtime add table public.party_invites;

-- ---- Realtime Broadcast on private topics (D7) -------------------------------------
-- party:<id>        actions, reactions, hello/bye: every active member sends and receives.
-- party:<id>:host   the timeline: every active member receives, only the host sends.
-- Realtime checks these when a channel joins, so the host-only topic is what keeps guests
-- from publishing a timeline.

create function public.party_topic_id(p_topic text) returns uuid
language sql immutable set search_path = public as $$
  select case
    when p_topic ~ '^party:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(:host)?$'
    then substr(p_topic, 7, 36)::uuid
  end;
$$;

create policy party_topics_receive on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and public.party_active_member(public.party_topic_id(realtime.topic()), (select auth.uid()))
);

create policy party_topics_send on realtime.messages for insert to authenticated
with check (
  realtime.messages.extension = 'broadcast'
  and public.party_active_member(public.party_topic_id(realtime.topic()), (select auth.uid()))
  and (realtime.topic() !~ ':host$'
       or public.party_host_of(public.party_topic_id(realtime.topic())) = (select auth.uid()))
);

-- ---- Starting, joining and leaving (service role only, through Edge Functions) ------

create function public.party_profile_json(p_user uuid) returns jsonb
language sql stable set search_path = public as $$
  select public.share_profile_json(p_user);
$$;

-- The party as the apps read it: who hosts, where, the timeline and the active members.
create function public.party_json(p_party uuid) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object(
    'id', w.id, 'host', w.host, 'channel_name', w.channel_name, 'state', w.state,
    'ended', w.ended_at is not null,
    'members', coalesce((
      select jsonb_agg(public.share_profile_json(m.user_id) order by m.joined_at)
        from public.party_members m where m.party_id = w.id and m.left_at is null), '[]'::jsonb))
    from public.watch_parties w where w.id = p_party;
$$;

-- Ends [p_party]: every member leaves and every invite ends.
create function public.party_end(p_party uuid) returns void
language plpgsql volatile set search_path = public as $$
begin
  update public.watch_parties set ended_at = now() where id = p_party and ended_at is null;
  update public.party_members set left_at = now() where party_id = p_party and left_at is null;
  update public.party_invites set state = 'ended' where party_id = p_party and state <> 'ended';
end $$;

-- Leaves every other party [p_user] is in (ending the ones it hosts): one party at a time.
create function public.party_leave_others(p_user uuid, p_keep uuid) returns void
language plpgsql volatile set search_path = public as $$
declare r record;
begin
  for r in select w.id, w.host from public.party_members m join public.watch_parties w on w.id = m.party_id
            where m.user_id = p_user and m.left_at is null and w.ended_at is null
              and w.id is distinct from p_keep loop
    if r.host = p_user then
      perform public.party_end(r.id);
    else
      update public.party_members set left_at = now() where party_id = r.id and user_id = p_user;
    end if;
  end loop;
end $$;

create function public.party_friends(p_a uuid, p_b uuid) returns boolean
language sql stable set search_path = public as $$
  select exists (select 1 from public.friendships where user_a = least(p_a, p_b) and user_b = greatest(p_a, p_b))
     and not exists (select 1 from public.blocks
                      where (blocker = p_a and blocked = p_b) or (blocker = p_b and blocked = p_a));
$$;

-- start-party: the party, its host as the first member, invites for up to 7 friends, and a
-- `watch` invite code on request. → {status: ok, party, code?, expires_at?}
--   | {status: no_profile | not_friends | too_many | bad_request}
create function public.start_party(p_host uuid, p_channel text, p_state jsonb, p_invite uuid[], p_link boolean)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_id uuid;
  v_inv jsonb;
  v_out jsonb;
  v_who uuid;
begin
  if not exists (select 1 from public.share_profiles where user_id = p_host) then
    return jsonb_build_object('status', 'no_profile');
  end if;
  if p_channel is null or char_length(p_channel) not between 1 and 100 or p_state is null then
    return jsonb_build_object('status', 'bad_request');
  end if;
  if coalesce(array_length(p_invite, 1), 0) > 7 then
    return jsonb_build_object('status', 'too_many');
  end if;
  foreach v_who in array coalesce(p_invite, '{}'::uuid[]) loop
    if not public.party_friends(p_host, v_who) then
      return jsonb_build_object('status', 'not_friends');
    end if;
  end loop;
  perform public.party_leave_others(p_host, null);
  insert into public.watch_parties (host, channel_name, state) values (p_host, p_channel, p_state)
    returning id into v_id;
  insert into public.party_members (party_id, user_id) values (v_id, p_host);
  insert into public.party_invites (party_id, invitee)
    select v_id, u from unnest(coalesce(p_invite, '{}'::uuid[])) u on conflict do nothing;
  v_out := jsonb_build_object('status', 'ok', 'party', public.party_json(v_id));
  if p_link then
    v_inv := public.make_invite(p_host, 'watch', jsonb_build_object('party', v_id));
    v_out := v_out || jsonb_build_object('code', v_inv->'code', 'expires_at', v_inv->'expires_at');
  end if;
  return v_out;
end $$;

-- invite-more from the party row: the host invites friends, up to 8 members with those
-- already in. → {status: ok} | {status: ended | not_host | not_friends | too_many}
create function public.party_invite(p_host uuid, p_party uuid, p_invite uuid[], p_link boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_who uuid;
  v_inv jsonb;
  v_out jsonb := jsonb_build_object('status', 'ok');
begin
  if not exists (select 1 from public.watch_parties where id = p_party and ended_at is null) then
    return jsonb_build_object('status', 'ended');
  end if;
  if public.party_host_of(p_party) <> p_host then
    return jsonb_build_object('status', 'not_host');
  end if;
  if (select count(*) from public.party_members where party_id = p_party and left_at is null)
       + coalesce(array_length(p_invite, 1), 0) > 8 then
    return jsonb_build_object('status', 'too_many');
  end if;
  foreach v_who in array coalesce(p_invite, '{}'::uuid[]) loop
    if not public.party_friends(p_host, v_who) then
      return jsonb_build_object('status', 'not_friends');
    end if;
  end loop;
  insert into public.party_invites (party_id, invitee)
    select p_party, u from unnest(coalesce(p_invite, '{}'::uuid[])) u
  on conflict (party_id, invitee) do update set state = 'new', created_at = now()
    where party_invites.state <> 'joined';
  if p_link then
    v_inv := public.make_invite(p_host, 'watch', jsonb_build_object('party', p_party));
    v_out := v_out || jsonb_build_object('code', v_inv->'code', 'expires_at', v_inv->'expires_at');
  end if;
  return v_out;
end $$;

-- join-party: an invitee, or a friend of the host, joins while there's room (8 in all).
-- → {status: ok, party} | {status: ended | full | not_allowed | no_profile}
create function public.join_party(p_user uuid, p_party uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_party public.watch_parties;
begin
  if not exists (select 1 from public.share_profiles where user_id = p_user) then
    return jsonb_build_object('status', 'no_profile');
  end if;
  select * into v_party from public.watch_parties where id = p_party for update;
  if v_party.id is null or v_party.ended_at is not null then
    return jsonb_build_object('status', 'ended');
  end if;
  if v_party.host <> p_user and not public.party_friends(v_party.host, p_user) then
    return jsonb_build_object('status', 'not_allowed');
  end if;
  if not public.party_active_member(p_party, p_user)
     and (select count(*) from public.party_members where party_id = p_party and left_at is null) >= 8 then
    return jsonb_build_object('status', 'full');
  end if;
  perform public.party_leave_others(p_user, p_party);
  insert into public.party_members (party_id, user_id) values (p_party, p_user)
  on conflict (party_id, user_id) do update set left_at = null, joined_at = now()
    where party_members.left_at is not null;
  update public.party_invites set state = 'joined' where party_id = p_party and invitee = p_user;
  return jsonb_build_object('status', 'ok', 'party', public.party_json(p_party));
end $$;

-- leave-party: the member leaves; the host leaving ends the party. reason `host-gone` from a
-- member ends it too, but only when the host hasn't written for 60 seconds.
-- → {status: ok, ended} | {status: not_member}
create function public.leave_party(p_user uuid, p_party uuid, p_reason text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_party public.watch_parties;
begin
  select * into v_party from public.watch_parties where id = p_party for update;
  if v_party.id is null or not public.party_related(p_party, p_user) then
    return jsonb_build_object('status', 'not_member');
  end if;
  if v_party.ended_at is not null then
    return jsonb_build_object('status', 'ok', 'ended', true);
  end if;
  if v_party.host = p_user
     or (p_reason = 'host-gone' and public.party_active_member(p_party, p_user)
         and v_party.beat_at < now() - interval '60 seconds') then
    perform public.party_end(p_party);
    return jsonb_build_object('status', 'ok', 'ended', true);
  end if;
  update public.party_members set left_at = now() where party_id = p_party and user_id = p_user and left_at is null;
  update public.party_invites set state = 'dismissed' where party_id = p_party and invitee = p_user and state = 'new';
  return jsonb_build_object('status', 'ok', 'ended', false);
end $$;

-- ---- Invites: the watch kind -----------------------------------------------------------

-- The live party a `watch` invite is for, or null once it ended.
create function public.invite_party(p_invite public.invites) returns public.watch_parties
language sql stable set search_path = public as $$
  select w.* from public.watch_parties w
   where p_invite.kind = 'watch' and w.id = (p_invite.payload->>'party')::uuid and w.ended_at is null;
$$;

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
   where code = upper(p_code) and kind in ('friend', 'channels', 'watch')
   for update;
  if v_invite.code is null or v_invite.used_at is not null or v_invite.expires_at <= now()
     or not exists (select 1 from public.share_profiles where user_id = v_invite.owner)
     -- A watch invite ends with its party.
     or (v_invite.kind = 'watch' and (public.invite_party(v_invite)).id is null) then
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

create or replace function public.peek_invite(p_user uuid, p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
  v_out jsonb;
  v_party public.watch_parties;
begin
  select * into c from public.share_check_invite(p_user, p_code);
  if c.v_status <> 'ok' then
    return jsonb_build_object('status', c.v_status);
  end if;
  v_out := jsonb_build_object('status', 'ok', 'kind', (c.v_invite).kind,
                              'from', public.share_profile_json((c.v_invite).owner));
  if (c.v_invite).kind = 'channels' then
    v_out := v_out || jsonb_build_object('channels', public.invite_channel_names(c.v_invite));
  elsif (c.v_invite).kind = 'watch' then
    v_party := public.invite_party(c.v_invite);
    v_out := v_out || jsonb_build_object('party', v_party.id,
                                         'show', jsonb_build_object('title', v_party.state->>'title'));
  end if;
  return v_out;
end $$;

-- Redeem: a `watch` invite makes the two accounts friends and invites the redeemer to the
-- party, so the app shows the Join confirmation.
create or replace function public.redeem_invite(p_user uuid, p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
  v_owner uuid;
  v_count int := 0;
  v_party public.watch_parties;
  v_out jsonb;
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
  v_out := jsonb_build_object('status', 'ok', 'kind', (c.v_invite).kind, 'channels', v_count,
                              'friend', public.share_profile_json(v_owner));
  if (c.v_invite).kind = 'watch' then
    v_party := public.invite_party(c.v_invite);
    insert into public.party_invites (party_id, invitee) values (v_party.id, p_user)
    on conflict (party_id, invitee) do update set state = 'new', created_at = now()
      where party_invites.state <> 'joined';
    v_out := v_out || jsonb_build_object('party', v_party.id,
                                         'show', jsonb_build_object('title', v_party.state->>'title'));
  end if;
  return v_out;
end $$;

-- Website preview: a live `watch` invite answers with the program's title.
create or replace function public.invite_preview(p_code text, p_ip_hash text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_inv public.invites;
  v_p public.share_profiles;
  v_from jsonb;
  v_body jsonb;
  v_party public.watch_parties;
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
  if v_inv.kind = 'watch' then
    v_party := public.invite_party(v_inv);
    if v_party.id is null then
      return jsonb_build_object('status', 404);
    end if;
  end if;
  v_from := jsonb_build_object('name', v_p.display_name, 'handle', v_p.handle);
  if v_p.station <> '' then
    v_from := v_from || jsonb_build_object('station', v_p.station);
  end if;
  v_body := jsonb_build_object('kind', v_inv.kind, 'from', v_from, 'expires_at', v_inv.expires_at);
  if v_inv.kind = 'channels' then
    v_body := v_body || jsonb_build_object('channels', public.invite_channel_names(v_inv));
  elsif v_inv.kind = 'watch' then
    v_body := v_body || jsonb_build_object('show', jsonb_build_object('title', coalesce(v_party.state->>'title', '')));
  end if;
  return jsonb_build_object('status', 200, 'body', v_body);
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'watch_parties_touch()', 'party_profile_json(uuid)', 'party_json(uuid)', 'party_end(uuid)',
    'party_leave_others(uuid, uuid)', 'party_friends(uuid, uuid)',
    'start_party(uuid, text, jsonb, uuid[], boolean)', 'party_invite(uuid, uuid, uuid[], boolean)',
    'join_party(uuid, uuid)', 'leave_party(uuid, uuid, text)', 'invite_party(public.invites)',
    'share_check_invite(uuid, text)', 'peek_invite(uuid, text)', 'redeem_invite(uuid, text)',
    'invite_preview(text, text)']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
  -- The policies run these as the caller.
  foreach f in array array[
    'party_active_member(uuid, uuid)', 'party_related(uuid, uuid)', 'party_was_member(uuid, uuid)',
    'party_host_of(uuid)',
    'party_topic_id(text)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;
