-- Likes You: the eligible incoming-like set, free previews vs premium cards,
-- the photo-access rule Storage will enforce (Phase 5c) and the purge of
-- expired sessions and preview tokens.

create or replace function app.is_premium(acct uuid) returns boolean
language sql stable
set search_path = public, app, extensions
as $$
  select exists (
    select 1 from entitlement
    where account_id = acct and product = 'premium' and status = 'active'
      and (valid_until is null or valid_until > now())
  )
$$;

-- Candidates who liked `me` and whom `me` has neither liked nor passed.
-- Computed before any entitlement logic.
create or replace function app.incoming_likes(me uuid) returns table (pid uuid, other uuid)
language sql stable
set search_path = public, app, extensions
as $$
  select d.pid, d.other
  from app.deck(me) d
  where exists (select 1 from pair_like l where l.pair_id = d.pid and l.from_account = d.other)
$$;

-- Opaque handle a free member gets instead of an identity. Phase 5c resolves
-- it to a blurred derivative after re-checking eligibility.
create table like_preview (
  token uuid primary key default gen_random_uuid(),
  viewer uuid not null references account (id) on delete cascade,
  pair_id uuid not null references pair (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  unique (viewer, pair_id)
);
alter table like_preview enable row level security;
revoke all on like_preview from anon, authenticated;

create or replace function public.likes_you() returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  r record;
  items jsonb := '[]'::jsonb;
  prem boolean := app.is_premium(me);
  tok uuid;
begin
  for r in
    select i.pid, i.other from app.incoming_likes(me) i
    order by hashtextextended(i.pid::text, 0), i.pid
  loop
    if prem then
      items := items || app.card(r.other);
    else
      insert into like_preview (viewer, pair_id) values (me, r.pid)
      on conflict (viewer, pair_id) do update set expires_at = excluded.expires_at
      returning token into tok;
      items := items || jsonb_build_object(
        'token', tok,
        'age', (select app.age_on(birth_date, current_date) from profile where account_id = r.other));
    end if;
  end loop;
  return jsonb_build_object('outcome', 'ok', 'premium', prem, 'count', jsonb_array_length(items),
                            case when prem then 'cards' else 'previews' end, items);
end $$;

-- Who may load whose photos: self, an open match, or a current candidate.
create or replace function app.can_view_photos(viewer uuid, owner uuid) returns boolean
language sql stable
set search_path = public, app, extensions
as $$
  select viewer = owner
      or exists (
        select 1 from pair p
        where p.a = least(viewer, owner) and p.b = greatest(viewer, owner)
          and ((p.matched_at is not null and app.pair_open(p.id)) or app.candidate(viewer, p.id))
      )
$$;

create or replace function app.purge_discovery() returns int
language plpgsql volatile
set search_path = public, app, extensions
as $$
declare
  n int;
  m int;
begin
  delete from like_preview where expires_at <= now();
  get diagnostics n = row_count;
  delete from discovery_session where expires_at <= now();
  get diagnostics m = row_count;
  return n + m;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('purge-discovery', '41 3 * * *', 'select app.purge_discovery()');
  end if;
end $$;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
revoke all on function public.likes_you() from public, anon;
grant execute on function public.likes_you() to authenticated;
