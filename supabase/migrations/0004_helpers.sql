-- Internal helpers. Nothing here is callable by API roles.

-- Completed years; birthday inclusive; 29 February counts on 1 March.
create or replace function app.age_on(birth date, today date) returns int
language sql immutable as $$
  select extract(year from age(today, birth))::int
$$;

create or replace function app.uid() returns uuid
language plpgsql stable as $$
declare
  u uuid := auth.uid();
begin
  if u is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  return u;
end $$;

-- The canonical pair row for two accounts, created on first use.
create or replace function app.pair_for(x uuid, y uuid) returns uuid
language plpgsql volatile as $$
declare
  lo uuid := least(x, y);
  hi uuid := greatest(x, y);
  pid uuid;
begin
  if x = y then
    raise exception 'same_account' using errcode = 'P0001';
  end if;
  insert into pair (a, b) values (lo, hi)
  on conflict (a, b) do nothing;
  select id into pid from pair where a = lo and b = hi;
  return pid;
end $$;

-- Active account, adult profile, gender set, preferences, four ready photos, visible.
create or replace function app.setup_complete(acct uuid) returns boolean
language sql stable as $$
  select exists (
    select 1
    from account a
    join profile p on p.account_id = a.id
    join preferences f on f.account_id = a.id
    where a.id = acct
      and a.status = 'active'
      and p.visible
      and app.age_on(p.birth_date, current_date) >= 18
      and (p.gender <> 'self' or p.custom_gender <> '')
      and (select count(*) from photo ph where ph.account_id = a.id and ph.state = 'ready') = 4
  )
$$;

-- Does `who` fit `interests`? everyone fits all; self-described fits only everyone.
create or replace function app.gender_fits(who gender_identity, interests interest[]) returns boolean
language sql immutable as $$
  select 'everyone' = any (interests)
      or (who = 'woman' and 'women' = any (interests))
      or (who = 'man' and 'men' = any (interests))
      or (who = 'nonbinary' and 'nonbinary' = any (interests))
$$;

create or replace function app.age_fits(years int, min_age int, max_age int) returns boolean
language sql immutable as $$
  select years >= min_age and (max_age = 99 or years <= max_age)
$$;

create or replace function app.mutual_preferences(x uuid, y uuid) returns boolean
language sql stable as $$
  select app.gender_fits(py.gender, fx.interests)
     and app.gender_fits(px.gender, fy.interests)
     and app.age_fits(app.age_on(py.birth_date, current_date), fx.min_age, fx.max_age)
     and app.age_fits(app.age_on(px.birth_date, current_date), fy.min_age, fy.max_age)
  from profile px, preferences fx, profile py, preferences fy
  where px.account_id = x and fx.account_id = x
    and py.account_id = y and fy.account_id = y
$$;

-- No tombstone and no block in either direction.
create or replace function app.pair_open(pair_id uuid) returns boolean
language sql stable as $$
  select p.disconnected_at is null
     and not exists (
       select 1 from block b
       where (b.blocker = p.a and b.blocked = p.b) or (b.blocker = p.b and b.blocked = p.a)
     )
  from pair p where p.id = pair_id
$$;

create or replace function app.eligible_pair(x uuid, y uuid) returns boolean
language sql stable as $$
  select app.setup_complete(x)
     and app.setup_complete(y)
     and app.mutual_preferences(x, y)
     and coalesce((
       select app.pair_open(p.id) from pair p
       where p.a = least(x, y) and p.b = greatest(x, y)
     ), not exists (
       select 1 from block b
       where (b.blocker = x and b.blocked = y) or (b.blocker = y and b.blocked = x)
     ))
$$;

create or replace function app.effective_delay_hours(x uuid, y uuid) returns int
language sql stable as $$
  select greatest(
    (select delay_hours from preferences where account_id = x),
    (select delay_hours from preferences where account_id = y)
  )
$$;
