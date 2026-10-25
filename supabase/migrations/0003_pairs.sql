-- Pairs, encounters, likes, blocks, messages, reports, the pair event outbox
-- and the encounter parameters. Clients read under policy and never write:
-- every change goes through the RPC functions of later migrations.

create type encounter_state as enum ('pending', 'released', 'void');
create type report_status as enum ('received', 'reviewing', 'closed');

create table pair (
  id uuid primary key default gen_random_uuid(),
  a uuid not null references account (id),
  b uuid not null references account (id),
  revision bigint not null default 0,
  matched_at timestamptz,
  disconnected_at timestamptz,          -- the permanent tombstone
  created_at timestamptz not null default now(),
  constraint pair_canonical check (a < b),
  constraint pair_unique unique (a, b)
);
create index pair_b on pair (b);

create table pair_like (
  pair_id uuid not null references pair (id),
  from_account uuid not null references account (id),
  created_at timestamptz not null default now(),
  primary key (pair_id, from_account)
);

create table block (
  blocker uuid not null references account (id),
  blocked uuid not null references account (id),
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  constraint block_not_self check (blocker <> blocked)
);
create index block_blocked on block (blocked);

create table encounter (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references pair (id),
  encountered_at timestamptz not null,
  rule_version int not null,
  release_at timestamptz not null,
  state encounter_state not null default 'pending',
  sample_a uuid,                        -- ids only; samples are purged after 24 h
  sample_b uuid,
  created_at timestamptz not null default now()
);
-- one live encounter per pair
create unique index encounter_live_pair on encounter (pair_id) where state <> 'void';
create index encounter_pending_release on encounter (release_at) where state = 'pending';

create table message (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references pair (id),
  sender uuid not null references account (id),
  client_op_id uuid not null,
  seq bigint not null,
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint message_op unique (pair_id, client_op_id),
  constraint message_seq unique (pair_id, seq)
);

create table report (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references account (id),
  target uuid not null references account (id),
  pair_id uuid references pair (id),
  reason_code text not null,
  status report_status not null default 'received',
  client_op_id uuid not null unique,
  created_at timestamptz not null default now()
);

create table pair_event (
  id bigserial primary key,
  pair_id uuid not null references pair (id),
  revision bigint not null,
  kind text not null,
  created_at timestamptz not null default now()
);
create index pair_event_pair on pair_event (pair_id, id);

-- Single-row parameters. Provisional values until Phase 0 replaces them.
create table encounter_params (
  id boolean primary key default true check (id),
  radius_m int not null,
  max_skew_s int not null,
  max_sample_age_s int not null,
  max_future_s int not null,
  max_accuracy_m int not null,
  rule_version int not null
);
insert into encounter_params (radius_m, max_skew_s, max_sample_age_s, max_future_s, max_accuracy_m, rule_version)
values (20, 60, 86400, 60, 50, 1);

alter table pair enable row level security;
alter table pair_like enable row level security;
alter table block enable row level security;
alter table encounter enable row level security;
alter table message enable row level security;
alter table report enable row level security;
alter table pair_event enable row level security;
alter table encounter_params enable row level security;

create policy pair_member on pair for select to authenticated using (auth.uid() in (a, b));
create policy pair_like_member on pair_like for select to authenticated
  using (exists (select 1 from pair p where p.id = pair_id and auth.uid() in (p.a, p.b)));
create policy encounter_member on encounter for select to authenticated
  using (exists (select 1 from pair p where p.id = pair_id and auth.uid() in (p.a, p.b)));
create policy message_member on message for select to authenticated
  using (exists (select 1 from pair p where p.id = pair_id and auth.uid() in (p.a, p.b)));
create policy pair_event_member on pair_event for select to authenticated
  using (exists (select 1 from pair p where p.id = pair_id and auth.uid() in (p.a, p.b)));
create policy block_own on block for select to authenticated using (blocker = auth.uid());
create policy report_own on report for select to authenticated using (reporter = auth.uid());
create policy params_read on encounter_params for select to authenticated using (true);

-- Clients never write these tables, and never see encounter times.
revoke all on pair, pair_like, block, encounter, message, report, pair_event, encounter_params from anon, authenticated;
grant select on pair, pair_like, block, message, report, pair_event, encounter_params to authenticated;
grant select (id, pair_id, state, rule_version, created_at) on encounter to authenticated;
