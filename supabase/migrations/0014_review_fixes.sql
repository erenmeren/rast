-- Phase 5b review fixes (2026-10-26).
-- 1. A pass no longer removes a liker from Likes You: otherwise pass, count,
--    rewind would name every liker to a free member.
-- 2. Free previews are ordered by token, not by a pair-id hash the client can
--    recompute.
-- 3. rewind_pass looks passes up by account; give it an index.
-- 4. app.can_view_photos will back a Storage policy, which runs as the caller:
--    it has to read through RLS (security definer) and be executable.

create or replace function app.incoming_likes(me uuid) returns table (pid uuid, other uuid)
language sql stable
set search_path = public, app, extensions
as $$
  select p.id, case when p.a = me then p.b else p.a end
  from pair p
  where me in (p.a, p.b)
    and app.candidate(me, p.id)
    and exists (select 1 from pair_like l
                where l.pair_id = p.id and l.from_account = case when p.a = me then p.b else p.a end)
$$;

create or replace function public.likes_you() returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  r record;
  items jsonb := '[]'::jsonb;
  prem boolean := app.is_premium(me);
begin
  for r in
    select i.pid, i.other from app.incoming_likes(me) i
    order by hashtextextended(i.pid::text, 0), i.pid
  loop
    if prem then
      items := items || app.card(r.other);
    else
      insert into like_preview (viewer, pair_id) values (me, r.pid)
      on conflict (viewer, pair_id) do update set expires_at = excluded.expires_at;
    end if;
  end loop;
  if not prem then
    select coalesce(jsonb_agg(jsonb_build_object('token', lp.token, 'age', app.age_on(pr.birth_date, current_date)) order by lp.token), '[]'::jsonb)
    into items
    from like_preview lp
    join pair p on p.id = lp.pair_id
    join profile pr on pr.account_id = case when p.a = me then p.b else p.a end
    where lp.viewer = me and lp.pair_id in (select i.pid from app.incoming_likes(me) i);
  end if;
  return jsonb_build_object('outcome', 'ok', 'premium', prem, 'count', jsonb_array_length(items),
                            case when prem then 'cards' else 'previews' end, items);
end $$;

create index pair_pass_account_time on pair_pass (from_account, created_at desc);

create or replace function app.can_view_photos(viewer uuid, owner uuid) returns boolean
language sql stable security definer
set search_path = public, app, extensions
as $$
  select viewer = owner
      or exists (
        select 1 from pair p
        where p.a = least(viewer, owner) and p.b = greatest(viewer, owner)
          and ((p.matched_at is not null and app.pair_open(p.id)) or app.candidate(viewer, p.id))
      )
$$;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
grant execute on function app.can_view_photos(uuid, uuid) to authenticated;
