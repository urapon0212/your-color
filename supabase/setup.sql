-- Run once in Supabase Dashboard > SQL Editor.
-- Public callers can submit records but cannot query the stored rows.
create table if not exists public.your_color_sessions (
  session_id uuid primary key,
  created_at timestamptz not null default now(),
  answers smallint[] not null,
  lut_base text not null check (lut_base in ('STD','VLOG')),
  lut_name text not null,
  download_format text not null check (download_format in ('zip','cube')),
  age_group text check (age_group in ('10代','20代','30代','40代','50代','60代以上')),
  gender text check (gender in ('男性','女性','その他')),
  photo_frequency text check (photo_frequency in ('よく撮る','たまに撮る','スマホが中心','ほとんど撮らない')),
  survey_at timestamptz
);
alter table public.your_color_sessions enable row level security;
revoke all on public.your_color_sessions from anon, authenticated;
-- SECURITY DEFINER RPC is the only client-write path. No SELECT/UPDATE/DELETE grants.
create or replace function public.submit_your_color_log(
  p_action text,
  p_session uuid,
  p_answers smallint[] default null,
  p_base text default null,
  p_name text default null,
  p_format text default null,
  p_age text default null,
  p_gender text default null,
  p_photo text default null
) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if p_session is null or p_action not in ('download','survey') then
    raise exception 'invalid request';
  end if;
  if p_action = 'download' then
    if p_answers is null or array_length(p_answers,1) <> 7
      or exists(select 1 from unnest(p_answers) as a where a is null or a < 0 or a > 3)
      or p_base not in ('STD','VLOG') or p_format not in ('zip','cube')
      or p_name is null or length(p_name) > 120 then
      raise exception 'invalid download payload';
    end if;
    insert into public.your_color_sessions(session_id,answers,lut_base,lut_name,download_format)
    values(p_session,p_answers,p_base,p_name,p_format)
    on conflict (session_id) do nothing;
  else
    if (p_age is not null and p_age not in ('10代','20代','30代','40代','50代','60代以上'))
      or (p_gender is not null and p_gender not in ('男性','女性','その他'))
      or (p_photo is not null and p_photo not in ('よく撮る','たまに撮る','スマホが中心','ほとんど撮らない')) then
      raise exception 'invalid survey payload';
    end if;
    update public.your_color_sessions
      set age_group=p_age,gender=p_gender,photo_frequency=p_photo,survey_at=now()
    where session_id=p_session and survey_at is null;
  end if;
end;
$$;
revoke all on function public.submit_your_color_log(text,uuid,smallint[],text,text,text,text,text,text) from public;
grant execute on function public.submit_your_color_log(text,uuid,smallint[],text,text,text,text,text,text) to anon;
-- Example admin-only query: select answers[1] as q1, count(*) from public.your_color_sessions group by 1 order by 1;
-- For production abuse resistance, add rate limiting (e.g., via a protected Edge Function).
