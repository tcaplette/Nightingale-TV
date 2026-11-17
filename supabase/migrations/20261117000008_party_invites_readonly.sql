-- watch-together: invites stay listed until their party ends, so apps never change them.
-- (A guest who leaves has its invite marked by leave-party, on the server.)
drop policy party_invites_update on public.party_invites;
revoke update on public.party_invites from authenticated;
