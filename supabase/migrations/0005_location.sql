-- Raw location samples, the intake RPC and PostGIS encounter evaluation.
-- Clients only ever call submit_location_samples; the table is closed to them.

create table location_sample (
  id uuid primary key,
  account_id uuid not null references account (id),
  device_id uuid not null references device (id),
  seq bigint not null,
  point geography(Point, 4326) not null,
  accuracy_m real not null,
  observed_at timestamptz not null,
  received_at timestamptz not null default now(),
  constraint location_sample_device_seq unique (device_id, seq)
);
create index location_sample_point on location_sample using gist (point);
create index location_sample_account_time on location_sample (account_id, observed_at);
create index location_sample_received on location_sample (received_at);

alter table location_sample enable row level security;
revoke all on location_sample from anon, authenticated;

-- For the new sample S of account A: every other account with a sample within
-- radius_m and max_skew_s becomes a candidate; the closest-in-time sample per
-- account is used; distance is centre to centre, rounded to millimetres.
create or replace function app.evaluate_encounters(sample_id uuid) returns int
language plpgsql volatile as $$
declare
  s location_sample;
  prm encounter_params;
  r record;
  inserted int;
  n int := 0;
begin
  select * into s from location_sample where id = sample_id;
  if s.id is null then return 0; end if;
  select * into prm from encounter_params;

  for r in
    select distinct on (t.account_id)
           t.account_id as other,
           t.id as other_sample,
           greatest(s.observed_at, t.observed_at) as at
    from location_sample t
    where t.account_id <> s.account_id
      and ST_DWithin(t.point, s.point, prm.radius_m)
      and abs(extract(epoch from (t.observed_at - s.observed_at))) <= prm.max_skew_s
      and t.accuracy_m <= prm.max_accuracy_m
      and round(ST_Distance(t.point, s.point)::numeric, 3) <= prm.radius_m
    order by t.account_id, abs(extract(epoch from (t.observed_at - s.observed_at)))
  loop
    if not app.eligible_pair(s.account_id, r.other) then
      continue;
    end if;
    insert into encounter (pair_id, encountered_at, rule_version, release_at, state, sample_a, sample_b)
    values (
      app.pair_for(s.account_id, r.other),
      r.at,
      prm.rule_version,
      r.at + make_interval(hours => app.effective_delay_hours(s.account_id, r.other)),
      'pending',
      case when s.account_id < r.other then s.id else r.other_sample end,
      case when s.account_id < r.other then r.other_sample else s.id end
    )
    on conflict (pair_id) where state <> 'void' do nothing;
    get diagnostics inserted = row_count;
    n := n + inserted;
  end loop;
  return n;
end $$;

create or replace function app.release_due_encounters() returns int
language plpgsql volatile as $$
declare
  n int;
begin
  update encounter set state = 'released'
  where state = 'pending' and release_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

-- Intake. Input: [{id, device_id, seq, lat, lon, accuracy_m, observed_at}, …].
-- Output: {"accepted": [ids], "rejected": [{"id", "reason"}]} and nothing about anyone else.
create or replace function public.submit_location_samples(samples jsonb) returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  prm encounter_params;
  el jsonb;
  accepted jsonb := '[]'::jsonb;
  rejected jsonb := '[]'::jsonb;
  sid uuid; dev uuid; sq bigint;
  lat double precision; lon double precision; acc real; obs timestamptz;
  reason text;
begin
  if samples is null or jsonb_typeof(samples) <> 'array' then
    raise exception 'samples must be a json array' using errcode = '22023';
  end if;
  select * into prm from encounter_params;

  for el in select value from jsonb_array_elements(samples) loop
    reason := null;
    begin
      sid := (el->>'id')::uuid;
      dev := (el->>'device_id')::uuid;
      sq := (el->>'seq')::bigint;
      lat := (el->>'lat')::double precision;
      lon := (el->>'lon')::double precision;
      acc := (el->>'accuracy_m')::real;
      obs := (el->>'observed_at')::timestamptz;
      if sid is null or dev is null or sq is null or lat is null or lon is null or acc is null or obs is null
         or lat < -90 or lat > 90 or lon < -180 or lon > 180 or acc < 0 or acc <> acc then
        reason := 'malformed';
      end if;
    exception when others then
      reason := 'malformed';
    end;

    if reason is null then
      if not exists (select 1 from device d where d.id = dev and d.account_id = me) then
        reason := 'device';
      elsif obs < now() - make_interval(secs => prm.max_sample_age_s) then
        reason := 'too_old';
      elsif obs > now() + make_interval(secs => prm.max_future_s) then
        reason := 'future';
      elsif acc > prm.max_accuracy_m then
        reason := 'inaccurate';
      end if;
    end if;

    if reason is not null then
      rejected := rejected || jsonb_build_object('id', el->'id', 'reason', reason);
      continue;
    end if;

    -- A retry of an already stored (device, seq) is accepted again, not stored twice.
    if not exists (select 1 from location_sample where device_id = dev and seq = sq) then
      insert into location_sample (id, account_id, device_id, seq, point, accuracy_m, observed_at)
      values (sid, me, dev, sq, ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography, acc, obs);
      perform app.evaluate_encounters(sid);
    end if;
    accepted := accepted || to_jsonb(sid::text);
  end loop;

  return jsonb_build_object('accepted', accepted, 'rejected', rejected);
end $$;

revoke all on function public.submit_location_samples(jsonb) from public, anon;
grant execute on function public.submit_location_samples(jsonb) to authenticated;
