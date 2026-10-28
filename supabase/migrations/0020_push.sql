-- Push notifications: three per-member switches, the device token, an outbox
-- written by the RPCs that create the events, and a pg_net trigger that hands
-- each row to the push-send edge function.
-- Design: docs/superpowers/specs/2026-10-28-push-notifications-design.md

alter table preferences
  add column notify_matches boolean not null default true,
  add column notify_likes boolean not null default true,
  add column notify_messages boolean not null default true;

alter table device add column push_token text;

create table push_outbox (
  id bigserial primary key,
  recipient uuid not null references account (id) on delete cascade,
  kind text not null check (kind in ('matched', 'liked', 'message')),
  pair_id uuid references pair (id),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  result text
);
create index push_outbox_recipient on push_outbox (recipient, id);
alter table push_outbox enable row level security;
revoke all on push_outbox from anon, authenticated;

-- Where the trigger posts. One row, inserted by the owner after deploying
-- push-send; without it (and without pg_net) the outbox simply accumulates.
create table app.push_hook (
  id boolean primary key default true check (id),
  url text not null,
  secret text not null
);
revoke all on app.push_hook from anon, authenticated;

-- One outbox row when the recipient wants this kind and has a device that can
-- receive it. The sender's identity never travels: the function only knows
-- the pair.
create or replace function app.notify(recipient uuid, kind text, pid uuid) returns void
language plpgsql volatile
set search_path = public, app, extensions
as $$
begin
  if exists (
       select 1 from preferences f
       where f.account_id = recipient
         and case kind when 'matched' then f.notify_matches when 'liked' then f.notify_likes else f.notify_messages end
     )
     and exists (select 1 from device d where d.account_id = recipient and d.push_token is not null) then
    insert into push_outbox (recipient, kind, pair_id) values (recipient, kind, pid);
  end if;
end $$;

create or replace function app.push_outbox_hook() returns trigger
language plpgsql volatile
set search_path = public, app, extensions
as $$
declare
  h app.push_hook;
begin
  select * into h from app.push_hook limit 1;
  if h.url is not null and exists (select 1 from pg_extension where extname = 'pg_net') then
    begin
      -- dynamic so the function also compiles where the net schema is absent
      execute format(
        'select net.http_post(url := %L, body := %L::jsonb, headers := %L::jsonb, timeout_milliseconds := 10000)',
        h.url,
        jsonb_build_object('id', new.id)::text,
        jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', h.secret)::text
      );
    exception when others then
      -- a push that cannot be queued (pg_net worker down) must not undo the like or message
      raise warning 'push hook: %', sqlerrm;
    end;
  end if;
  return new;
end $$;

create trigger push_outbox_notify after insert on push_outbox
  for each row execute function app.push_outbox_hook();

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end $$;

-- like_account (0007) + notify: both members on a match, the target on a new
-- one-sided like. A repeated like and an unavailable target notify nobody.
create or replace function public.like_account(target uuid, client_op_id uuid) returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  p pair;
  inserted int;
begin
  if target = me or not app.account_exists(target) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  p := app.lock_pair(me, target);
  if p.disconnected_at is not null or not app.pair_open(p.id)
     or not exists (select 1 from encounter where pair_id = p.id and state = 'released')
     or not app.eligible_pair(me, target) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;

  insert into pair_like (pair_id, from_account) values (p.id, me) on conflict do nothing;
  get diagnostics inserted = row_count;

  if p.matched_at is null and exists (select 1 from pair_like where pair_id = p.id and from_account = target) then
    update pair set matched_at = now() where id = p.id;
    perform app.bump(p.id, 'matched');
    perform app.notify(me, 'matched', p.id);
    perform app.notify(target, 'matched', p.id);
    return jsonb_build_object('outcome', 'matched');
  end if;
  if inserted > 0 then
    perform app.bump(p.id, null);
    perform app.notify(target, 'liked', p.id);
  end if;
  return jsonb_build_object('outcome', case when p.matched_at is null then 'liked' else 'matched' end);
end $$;

-- send_message (0007) + notify for the other member.
create or replace function public.send_message(target uuid, client_op_id uuid, body text) returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  p pair;
  existing message;
  next_seq bigint;
begin
  if target = me or not app.account_exists(target) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  p := app.lock_pair(me, target);
  select * into existing from message m where m.pair_id = p.id and m.client_op_id = send_message.client_op_id;
  if existing.id is not null then
    return jsonb_build_object('outcome', 'sent', 'seq', existing.seq);
  end if;
  if p.matched_at is null or p.disconnected_at is not null or not app.pair_open(p.id)
     or not app.account_active(me) or not app.account_active(target) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  select coalesce(max(seq), 0) + 1 into next_seq from message where pair_id = p.id;
  insert into message (pair_id, sender, client_op_id, seq, body)
  values (p.id, me, client_op_id, next_seq, body);
  perform app.bump(p.id, 'message');
  perform app.notify(target, 'message', p.id);
  return jsonb_build_object('outcome', 'sent', 'seq', next_seq);
end $$;

-- purge_discovery (0013) + the outbox: a row older than a week was either sent
-- or never will be.
create or replace function app.purge_discovery() returns int
language plpgsql volatile
set search_path = public, app, extensions
as $$
declare
  n int;
  m int;
  k int;
begin
  delete from like_preview where expires_at <= now();
  get diagnostics n = row_count;
  delete from discovery_session where expires_at <= now();
  get diagnostics m = row_count;
  delete from push_outbox where created_at < now() - interval '7 days';
  get diagnostics k = row_count;
  return n + m + k;
end $$;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
grant execute on function app.can_view_photos(uuid, uuid) to authenticated;
grant execute on function app.photo_owner(text) to authenticated;
