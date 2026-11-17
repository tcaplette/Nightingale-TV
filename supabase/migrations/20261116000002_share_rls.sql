-- share-accounts: row-level security (design D9).
-- The public key can be pulled out of any APK, so these rules are the protection.

alter table public.share_profiles  enable row level security;
alter table public.friendships     enable row level security;
alter table public.blocks          enable row level security;
alter table public.invites         enable row level security;
alter table public.redeem_attempts enable row level security;
alter table public.preview_hits    enable row level security;

-- Anonymous callers get nothing at all.
revoke all on public.share_profiles, public.friendships, public.blocks, public.invites,
  public.redeem_attempts, public.preview_hits from anon;
-- Signed-in callers: only what the policies below allow, and no writes where an
-- Edge Function does the writing.
revoke all on public.redeem_attempts, public.preview_hits from authenticated;
revoke insert, update on public.friendships from authenticated;
revoke insert, update, delete on public.invites from authenticated;
revoke update on public.blocks from authenticated;
revoke delete on public.share_profiles from authenticated;

-- share_profiles: your own row, your friends' rows, and people you blocked
-- (so the Blocked list can name them).
create policy share_profiles_select on public.share_profiles for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.friendships f
     where (f.user_a = (select auth.uid()) and f.user_b = share_profiles.user_id)
        or (f.user_b = (select auth.uid()) and f.user_a = share_profiles.user_id))
  or exists (
    select 1 from public.blocks b
     where b.blocker = (select auth.uid()) and b.blocked = share_profiles.user_id)
);
create policy share_profiles_insert on public.share_profiles for insert to authenticated
with check (user_id = (select auth.uid()));
create policy share_profiles_update on public.share_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- friendships: see and remove the ones that include you. Only redeem-invite adds them.
create policy friendships_select on public.friendships for select to authenticated
using ((select auth.uid()) in (user_a, user_b));
create policy friendships_delete on public.friendships for delete to authenticated
using ((select auth.uid()) in (user_a, user_b));

-- blocks: your own.
create policy blocks_select on public.blocks for select to authenticated
using (blocker = (select auth.uid()));
create policy blocks_insert on public.blocks for insert to authenticated
with check (blocker = (select auth.uid()));
create policy blocks_delete on public.blocks for delete to authenticated
using (blocker = (select auth.uid()));

-- invites: read the ones you made.
create policy invites_select on public.invites for select to authenticated
using (owner = (select auth.uid()));

-- redeem_attempts, preview_hits: RLS on, no policies, no grants: no client access.

-- Live "That handle is taken." check without exposing anyone's profile.
create function public.handle_available(p_handle text) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from public.share_profiles
     where lower(handle) = lower(p_handle)
       and user_id <> coalesce((select auth.uid()), '00000000-0000-0000-0000-000000000000'::uuid));
$$;
revoke all on function public.handle_available(text) from public, anon;
grant execute on function public.handle_available(text) to authenticated;
