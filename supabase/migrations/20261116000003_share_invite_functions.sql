-- share-accounts: invite codes, peek, redeem and previews (design D7, D8).
-- These run as security definer and only the service role (Edge Functions) may call them.

create function public.share_new_code() returns text
language plpgsql volatile set search_path = public, extensions as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea;
  b int;
  v_code text;
  i int;
begin
  loop
    v_code := '';
    bytes := extensions.gen_random_bytes(24);
    i := 0;
    while char_length(v_code) < 6 and i < 24 loop
      b := get_byte(bytes, i);
      i := i + 1;
      -- 248 = 31 * 8: rejecting the top bytes keeps every character equally likely.
      if b < 248 then
        v_code := v_code || substr(alphabet, (b % 31) + 1, 1);
      end if;
    end loop;
    if char_length(v_code) = 6 and not exists (select 1 from public.invites where invites.code = v_code) then
      return v_code;
    end if;
  end loop;
end $$;

create function public.share_profile_json(p_user uuid) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object(
    'user_id', p.user_id, 'name', p.display_name, 'handle', p.handle,
    'avatar', p.avatar, 'avatar_color', p.avatar_color, 'station', p.station)
    from public.share_profiles p where p.user_id = p_user;
$$;

-- One live friend code per account: making a new one ends the old one.
create function public.make_invite(p_owner uuid, p_kind text default 'friend',
                                   p_payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_code text;
  v_row public.invites;
begin
  if not exists (select 1 from public.share_profiles where user_id = p_owner) then
    return jsonb_build_object('status', 'no_profile');
  end if;
  if p_kind = 'friend' then
    delete from public.invites where owner = p_owner and kind = 'friend' and used_at is null;
  end if;
  v_code := public.share_new_code();
  insert into public.invites (code, owner, kind, payload)
    values (v_code, p_owner, p_kind, coalesce(p_payload, '{}'::jsonb))
    returning * into v_row;
  return jsonb_build_object('status', 'ok', 'code', v_row.code, 'kind', v_row.kind,
                            'expires_at', v_row.expires_at);
end $$;

create function public.share_redeem_limited(p_user uuid) returns boolean
language sql stable set search_path = public as $$
  select count(*) >= 10 from public.redeem_attempts
   where user_id = p_user and not ok and at > now() - interval '1 hour';
$$;

-- Shared checks for peek and redeem. Returns the live invite or null; sets p_status.
create function public.share_check_invite(p_user uuid, p_code text, out v_invite public.invites,
                                          out v_status text)
language plpgsql volatile set search_path = public as $$
begin
  delete from public.redeem_attempts where at < now() - interval '1 day';
  if public.share_redeem_limited(p_user) then
    v_status := 'limited';
    return;
  end if;
  select * into v_invite from public.invites
   where code = upper(p_code) and kind = 'friend'
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

-- Read-only look at a code before the confirmation. Failed looks count towards the
-- redeem limit so peek can't be used to guess codes.
create function public.peek_invite(p_user uuid, p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
begin
  select * into c from public.share_check_invite(p_user, p_code);
  if c.v_status <> 'ok' then
    return jsonb_build_object('status', c.v_status);
  end if;
  return jsonb_build_object('status', 'ok', 'kind', (c.v_invite).kind,
                            'from', public.share_profile_json((c.v_invite).owner));
end $$;

-- Redeem in one transaction: limit, look up, checks, mark used, make friends.
create function public.redeem_invite(p_user uuid, p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
  v_owner uuid;
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
  insert into public.redeem_attempts (user_id, ok) values (p_user, true);
  return jsonb_build_object('status', 'ok', 'friend', public.share_profile_json(v_owner));
end $$;

-- Website preview: 30 requests per 10 minutes per salted address hash.
create function public.invite_preview(p_code text, p_ip_hash text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_inv public.invites;
  v_p public.share_profiles;
  v_from jsonb;
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
  return jsonb_build_object('status', 200, 'body',
    jsonb_build_object('kind', v_inv.kind, 'from', v_from, 'expires_at', v_inv.expires_at));
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'share_new_code()', 'share_profile_json(uuid)', 'make_invite(uuid, text, jsonb)',
    'share_redeem_limited(uuid)', 'share_check_invite(uuid, text)', 'peek_invite(uuid, text)',
    'redeem_invite(uuid, text)', 'invite_preview(text, text)', 'blocks_end_friendship()',
    'touch_updated_at()']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;
