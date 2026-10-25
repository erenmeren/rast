-- Transactional pair operations. Each public function acts as app.uid(),
-- locks the pair row, checks the tombstone and blocks under the lock, bumps
-- pair.revision and appends a pair_event in the same transaction.

create or replace function app.lock_pair(x uuid, y uuid) returns pair
language plpgsql volatile as $$
declare
  p pair;
begin
  perform app.pair_for(x, y);
  select * into p from pair where a = least(x, y) and b = greatest(x, y) for update;
  return p;
end $$;

-- Existing pair only (no row is created), locked.
create or replace function app.lock_existing_pair(x uuid, y uuid) returns pair
language plpgsql volatile as $$
declare
  p pair;
begin
  select * into p from pair where a = least(x, y) and b = greatest(x, y) for update;
  return p;
end $$;

-- Bumps the revision; writes an event when kind is given. A like bumps
-- without an event: the other person must not learn of it.
create or replace function app.bump(pid uuid, kind text) returns bigint
language plpgsql volatile as $$
declare
  r bigint;
begin
  update pair set revision = revision + 1 where id = pid returning revision into r;
  if kind is not null then
    insert into pair_event (pair_id, revision, kind) values (pid, r, kind);
  end if;
  return r;
end $$;

-- Tombstone + void live encounters + event. Idempotent.
create or replace function app.close_pair(p pair) returns void
language plpgsql volatile as $$
begin
  if p.disconnected_at is not null then return; end if;
  update pair set disconnected_at = now() where id = p.id;
  update encounter set state = 'void' where pair_id = p.id and state <> 'void';
  perform app.bump(p.id, 'disconnected');
end $$;

create or replace function app.account_exists(acct uuid) returns boolean
language sql stable as $$
  select exists (select 1 from account where id = acct)
$$;

create or replace function app.account_active(acct uuid) returns boolean
language sql stable as $$
  select exists (select 1 from account where id = acct and status = 'active')
$$;

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
    return jsonb_build_object('outcome', 'matched');
  end if;
  if inserted > 0 then
    perform app.bump(p.id, null);
  end if;
  return jsonb_build_object('outcome', case when p.matched_at is null then 'liked' else 'matched' end);
end $$;

create or replace function public.disconnect_pair(target uuid, client_op_id uuid) returns jsonb
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
  perform app.close_pair(p);
  return jsonb_build_object('outcome', 'disconnected');
end $$;

-- A block never tells the other person: no pair row is created for it and no
-- event is written. Blocking a match also removes the connection, and that
-- removal is visible like any other.
create or replace function public.block_account(target uuid) returns jsonb
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
  p := app.lock_existing_pair(me, target);
  insert into block (blocker, blocked) values (me, target) on conflict do nothing;
  if p.id is not null and p.matched_at is not null then
    perform app.close_pair(p);
  end if;
  return jsonb_build_object('outcome', 'blocked');
end $$;

create or replace function public.unblock_account(target uuid) returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
begin
  delete from block where blocker = me and blocked = target;
  return jsonb_build_object('outcome', 'unblocked');
end $$;

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
  return jsonb_build_object('outcome', 'sent', 'seq', next_seq);
end $$;

create or replace function public.submit_report(target uuid, reason_code text, client_op_id uuid, also_block boolean) returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  pid uuid;
begin
  if target = me or not app.account_exists(target) then
    return jsonb_build_object('outcome', 'unavailable');
  end if;
  if exists (select 1 from report r where r.client_op_id = submit_report.client_op_id) then
    return jsonb_build_object('outcome', 'received');
  end if;
  select id into pid from pair where a = least(me, target) and b = greatest(me, target);
  insert into report (reporter, target, pair_id, reason_code, client_op_id)
  values (me, target, pid, reason_code, client_op_id);
  if also_block then
    perform public.block_account(target);
  end if;
  return jsonb_build_object('outcome', 'received');
end $$;

-- Marks the account deleted and takes it out of every live encounter. Pairs
-- and tombstones stay: "never again" is enforced for the account pair.
create or replace function public.delete_account() returns jsonb
language plpgsql volatile security definer
set search_path = public, app, extensions
as $$
declare
  me uuid := app.uid();
  conn pair;
begin
  update account set status = 'deleted', deleted_at = now() where id = me;
  update profile set visible = false where account_id = me;
  -- Open connections close like a disconnect, so the other side is told.
  for conn in select * from pair where me in (a, b) and matched_at is not null and disconnected_at is null for update loop
    perform app.close_pair(conn);
  end loop;
  update encounter e set state = 'void'
  from pair p
  where p.id = e.pair_id and me in (p.a, p.b) and e.state <> 'void';
  return jsonb_build_object('outcome', 'deleted');
end $$;

revoke all on function
  public.like_account(uuid, uuid), public.disconnect_pair(uuid, uuid), public.block_account(uuid),
  public.unblock_account(uuid), public.send_message(uuid, uuid, text),
  public.submit_report(uuid, text, uuid, boolean), public.delete_account()
from public, anon;
grant execute on function
  public.like_account(uuid, uuid), public.disconnect_pair(uuid, uuid), public.block_account(uuid),
  public.unblock_account(uuid), public.send_message(uuid, uuid, text),
  public.submit_report(uuid, text, uuid, boolean), public.delete_account()
to authenticated;
