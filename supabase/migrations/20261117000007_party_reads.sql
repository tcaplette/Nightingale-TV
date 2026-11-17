-- watch-together: reads the apps make as the caller (design D7, D8).
-- A guest may be in a party with the host's friends who aren't its own, whose profiles RLS
-- hides: these give the party's members and open invites with just what the party row and
-- the invite banner show.

-- The active members of [p_party], for anyone in it or invited to it.
create function public.party_members_of(p_party uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when public.party_related(p_party, (select auth.uid())) then coalesce((
    select jsonb_agg(public.share_profile_json(m.user_id) order by m.joined_at)
      from public.party_members m
      join public.watch_parties w on w.id = m.party_id
     where m.party_id = p_party and m.left_at is null and w.ended_at is null), '[]'::jsonb)
  else '[]'::jsonb end;
$$;

-- The caller's open invites to live parties, newest first: the party, its host, channel and
-- the program's title.
create function public.my_party_invites() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'party', w.id, 'host', public.share_profile_json(w.host), 'channel_name', w.channel_name,
      'title', w.state->>'title', 'created_at', i.created_at) order by i.created_at desc), '[]'::jsonb)
    from public.party_invites i
    join public.watch_parties w on w.id = i.party_id
   where i.invitee = (select auth.uid()) and i.state = 'new' and w.ended_at is null
     and not exists (select 1 from public.blocks b
                      where (b.blocker = i.invitee and b.blocked = w.host)
                         or (b.blocker = w.host and b.blocked = i.invitee));
$$;

revoke all on function public.party_members_of(uuid) from public, anon;
revoke all on function public.my_party_invites() from public, anon;
grant execute on function public.party_members_of(uuid) to authenticated, service_role;
grant execute on function public.my_party_invites() to authenticated, service_role;
