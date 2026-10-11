-- YOUR COLOR: admin-only analytics dashboard access
-- 1. Run this entire file in Supabase SQL Editor.
-- 2. In Authentication > Users, create/invite your own login user.
-- 3. Replace YOU@example.com below with that user's email and run the INSERT separately.
create table if not exists public.your_color_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.your_color_admins enable row level security;
revoke all on public.your_color_admins from anon;
grant select on public.your_color_admins to authenticated;
drop policy if exists "admins can view own membership" on public.your_color_admins;
create policy "admins can view own membership" on public.your_color_admins
  for select to authenticated using (user_id = (select auth.uid()));

alter table public.your_color_sessions enable row level security;
revoke all on public.your_color_sessions from anon;
grant select on public.your_color_sessions to authenticated;
revoke insert, update, delete on public.your_color_sessions from authenticated;
drop policy if exists "admin analytics read" on public.your_color_sessions;
create policy "admin analytics read" on public.your_color_sessions
  for select to authenticated
  using (exists (
    select 1 from public.your_color_admins a
    where a.user_id = (select auth.uid())
  ));
-- Do NOT grant SELECT to anon. Existing SECURITY DEFINER write RPCs remain separate.

-- AFTER inviting/creating your personal account in Authentication > Users:
-- Run this separately after replacing the email (not the whole file again).
-- insert into public.your_color_admins (user_id)
-- select id from auth.users where email = 'YOU@example.com'
-- on conflict (user_id) do nothing;
