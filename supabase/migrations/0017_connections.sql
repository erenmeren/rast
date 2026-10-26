-- What the client needs for people it no longer holds a deck card for:
-- open matches with the partner's card, one card by id, the blocked list,
-- and pair_event in the realtime publication.

create or replace function public.connections() returns jsonb
language sql stable security definer
set search_path = public, app, extensions
as $$
  select jsonb_build_object('outcome', 'ok', 'connections', coalesce(jsonb_agg(
    jsonb_build_object('pair_id', p.id, 'revision', p.revision,
                       'card', app.card(case when p.a = app.uid() then p.b else p.a end))
    order by p.matched_at desc), '[]'::jsonb))
  from pair p
  where app.uid() in (p.a, p.b)
    and p.matched_at is not null
    and app.pair_open(p.id)
$$;

-- A current candidate or an open match of the caller; anyone else is
-- indistinguishable from a stranger.
create or replace function public.person_card(target uuid) returns jsonb
language sql stable security definer
set search_path = public, app, extensions
as $$
  select case
    when exists (
      select 1 from pair p
      where p.a = least(app.uid(), target) and p.b = greatest(app.uid(), target)
        and target <> app.uid()
        and ((p.matched_at is not null and app.pair_open(p.id)) or app.candidate(app.uid(), p.id))
    ) then jsonb_build_object('outcome', 'ok', 'card', app.card(target))
    else jsonb_build_object('outcome', 'unavailable')
  end
$$;

create or replace function public.blocked_accounts() returns jsonb
language sql stable security definer
set search_path = public, app, extensions
as $$
  select jsonb_build_object('outcome', 'ok', 'blocked', coalesce(jsonb_agg(
    jsonb_build_object('account_id', b.blocked, 'age', app.age_on(pr.birth_date, current_date))
    order by b.created_at desc), '[]'::jsonb))
  from block b
  join profile pr on pr.account_id = b.blocked
  where b.blocker = app.uid()
$$;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'pair_event') then
    alter publication supabase_realtime add table pair_event;
  end if;
end $$;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
grant execute on function app.can_view_photos(uuid, uuid) to authenticated;
grant execute on function app.photo_owner(text) to authenticated;
revoke all on function public.connections(), public.person_card(uuid), public.blocked_accounts() from public, anon;
grant execute on function public.connections(), public.person_card(uuid), public.blocked_accounts() to authenticated;
