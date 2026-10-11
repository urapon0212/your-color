-- Run in Supabase SQL Editor after supabase/setup.sql.
-- Adds multiple camera manufacturers to the existing anonymous survey.
alter table public.your_color_sessions
  add column if not exists camera_brands text[] not null default '{}'::text[];

create or replace function public.submit_your_color_camera_brands(
  p_session uuid,
  p_brands text[]
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_session is null or p_brands is null or cardinality(p_brands) > 12
    or exists (
      select 1 from unnest(p_brands) b
      where b is null or b not in (
        'Canon', 'Nikon', 'Sony', 'FUJIFILM', 'LUMIX (Panasonic)',
        'OM SYSTEM / Olympus', 'RICOH / PENTAX', 'SIGMA', 'Leica',
        'Hasselblad', 'その他', 'カメラは使っていない'
      )
    ) then
    raise exception 'invalid camera brands';
  end if;

  update public.your_color_sessions
    set camera_brands = p_brands
    where session_id = p_session and survey_at is not null
      and camera_brands = '{}'::text[];
end;
$$;
revoke all on function public.submit_your_color_camera_brands(uuid,text[]) from public;
grant execute on function public.submit_your_color_camera_brands(uuid,text[]) to anon;

-- Example: count selected camera manufacturers (multi-select)
-- select brand, count(*) from public.your_color_sessions s,
--   lateral unnest(s.camera_brands) as brand group by brand order by count(*) desc;
