-- Discover deck: sessions with a random but stable order, cursor pages,
-- pass and rewind. Design: docs/superpowers/specs/2026-10-26-discovery-design.md

create table discovery_session (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references account (id) on delete cascade,
  seed bigint not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create index discovery_session_account on discovery_session (account_id);
alter table discovery_session enable row level security;
create policy session_own on discovery_session for select to authenticated using (account_id = auth.uid());
revoke all on discovery_session from anon, authenticated;
grant select on discovery_session to authenticated;

-- A pass is per pair and private: no event, no revision bump.
create table pair_pass (
  pair_id uuid not null references pair (id),
  from_account uuid not null references account (id),
  created_at timestamptz not null default now(),
  primary key (pair_id, from_account)
);
alter table pair_pass enable row level security;
create policy pass_own on pair_pass for select to authenticated using (from_account = auth.uid());
revoke all on pair_pass from anon, authenticated;
grant select on pair_pass to authenticated;

-- The deck gate: released encounter, not matched, open, eligible right now.
create or replace function app.candidate(me uuid, pid uuid) returns boolean
language sql stable
set search_path = public, app, extensions
as $$
  select exists (
    select 1 from pair p
    where p.id = pid
      and me in (p.a, p.b)
      and p.matched_at is null
      and exists (select 1 from encounter e where e.pair_id = p.id and e.state = 'released')
      and app.pair_open(p.id)
      and app.eligible_pair(me, case when p.a = me then p.b else p.a end)
  )
$$;

-- Deck order depends on the session seed and the pair id only.
create or replace function app.order_key(seed bigint, pid uuid) returns bigint
language sql immutable
set search_path = public, app, extensions
as $$
  select hashtextextended(seed::text || pid::text, 0)
$$;

-- What a client may see of another member. No timestamps, no like status.
create or replace function app.card(acct uuid) returns jsonb
language sql stable
set search_path = public, app, extensions
as $$
  select jsonb_build_object(
    'account_id', acct,
    'age', app.age_on(p.birth_date, current_date),
    'gender', case when p.show_gender then p.gender::text end,
    'custom_gender', case when p.show_gender and p.gender = 'self' then p.custom_gender else '' end,
    'photos', (select coalesce(jsonb_agg(ph.storage_path order by ph.slot), '[]'::jsonb)
               from photo ph where ph.account_id = acct and ph.state = 'ready')
  )
  from profile p where p.account_id = acct
$$;

-- Candidates the caller has neither liked nor passed.
create or replace function app.deck(me uuid) returns table (pid uuid, other uuid)
language sql stable
set search_path = public, app, extensions
as $$
  select p.id, case when p.a = me then p.b else p.a end
  from pair p
  where me in (p.a, p.b)
    and app.candidate(me, p.id)
    and not exists (select 1 from pair_like l where l.pair_id = p.id and l.from_account = me)
    and not exists (select 1 from pair_pass s where s.pair_id = p.id and s.from_account = me)
$$;

create or replace function public.start_discovery_session() returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  sid uuid;
begin
  delete from discovery_session where account_id = me;
  insert into discovery_session (account_id, seed)
  values (me, (random() * 4611686018427387903)::bigint)
  returning id into sid;
  return jsonb_build_object('outcome', 'ok', 'session_id', sid);
end $$;

-- Page of the deck after cursor `after` (the previous page's `next`).
-- Removals never skip a card; candidates released behind the cursor appear
-- in the next session.
create or replace function public.discovery_cards(session_id uuid, after text default null, page_size int default 20) returns jsonb
language plpgsql stable security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  s discovery_session;
  cursor_key bigint := -9223372036854775808;
  n int := least(greatest(coalesce(page_size, 20), 1), 50);
  r record;
  out jsonb := '[]'::jsonb;
  last_key bigint;
  more boolean := false;
begin
  select * into s from discovery_session d
  where d.id = session_id and d.account_id = me and d.expires_at > now();
  if s.id is null then
    return jsonb_build_object('outcome', 'session_expired');
  end if;
  if after is not null then
    begin
      cursor_key := after::bigint;
    exception when others then
      return jsonb_build_object('outcome', 'bad_cursor');
    end;
  end if;
  for r in
    select d.pid, d.other, app.order_key(s.seed, d.pid) as key
    from app.deck(me) d
    where app.order_key(s.seed, d.pid) > cursor_key
    order by 3, 1
    limit n + 1
  loop
    if jsonb_array_length(out) = n then
      more := true;
      exit;
    end if;
    out := out || app.card(r.other);
    last_key := r.key;
  end loop;
  return jsonb_build_object('outcome', 'ok', 'cards', out, 'next', case when more then last_key::text end);
end $$;

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
  insert into pair_pass (pair_id, from_account) values (p.id, me) on conflict do nothing;
  return jsonb_build_object('outcome', 'passed');
end $$;

-- Removes the most recent pass only if that person is still available.
create or replace function public.rewind_pass() returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  p pair;
begin
  select pr.* into p
  from pair_pass s join pair pr on pr.id = s.pair_id
  where s.from_account = me
  order by s.created_at desc, s.pair_id
  limit 1
  for update of pr;
  if p.id is null or not app.candidate(me, p.id) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  delete from pair_pass where pair_id = p.id and from_account = me;
  return jsonb_build_object('outcome', 'restored', 'account_id', case when p.a = me then p.b else p.a end);
end $$;

-- Privileges: app stays internal (0009), the RPCs are for signed-in users.
revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
revoke all on function
  public.start_discovery_session(), public.discovery_cards(uuid, text, int),
  public.pass_account(uuid, uuid), public.rewind_pass()
from public, anon;
grant execute on function
  public.start_discovery_session(), public.discovery_cards(uuid, text, int),
  public.pass_account(uuid, uuid), public.rewind_pass()
to authenticated;
