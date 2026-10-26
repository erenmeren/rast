-- Follow-ups from the 5b and 5d reviews: the removed-connections list, one
-- session row per account (concurrent starts), the seed hidden from clients,
-- a repeated pass counting as the most recent one.

create or replace function public.disconnected_accounts() returns jsonb
language sql stable security definer
set search_path = public, app, extensions
as $$
  select jsonb_build_object('outcome', 'ok', 'disconnected', coalesce(jsonb_agg(
    jsonb_build_object('account_id', o, 'age', app.age_on(pr.birth_date, current_date))
    order by p.disconnected_at desc), '[]'::jsonb))
  from pair p
  cross join lateral (select case when p.a = app.uid() then p.b else p.a end as o) x
  join profile pr on pr.account_id = x.o
  where app.uid() in (p.a, p.b)
    and p.matched_at is not null
    and p.disconnected_at is not null
$$;

-- discovery_session: one per account, atomically replaced
alter table discovery_session add constraint discovery_session_account_key unique (account_id);
revoke select on discovery_session from authenticated;
grant select (id, account_id, created_at, expires_at) on discovery_session to authenticated;

create or replace function public.start_discovery_session() returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  sid uuid;
begin
  insert into discovery_session (account_id, seed)
  values (me, (random() * 4611686018427387903)::bigint)
  on conflict (account_id) do update
    set id = gen_random_uuid(), seed = excluded.seed, created_at = now(), expires_at = now() + interval '24 hours'
  returning id into sid;
  return jsonb_build_object('outcome', 'ok', 'session_id', sid);
end $$;

-- a repeated pass is the most recent one again
create or replace function public.pass_account(target uuid, client_op_id uuid) returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  p pair;
begin
  if target = me or not app.account_exists(target) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  p := app.lock_pair(me, target);
  if not app.candidate(me, p.id) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  insert into pair_pass (pair_id, from_account) values (p.id, me)
  on conflict (pair_id, from_account) do update set created_at = clock_timestamp();
  return jsonb_build_object('outcome', 'passed');
end $$;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
grant execute on function app.can_view_photos(uuid, uuid) to authenticated;
grant execute on function app.photo_owner(text) to authenticated;
revoke all on function public.disconnected_accounts() from public, anon;
grant execute on function public.disconnected_accounts() to authenticated;
