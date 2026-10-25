-- Accounts, profiles, photos, preferences, intro progress, devices, entitlements.
-- The phone number stays in auth.users; nothing here is public.

create type account_status as enum ('active', 'deleted');
create type gender_identity as enum ('woman', 'man', 'nonbinary', 'self');
create type photo_state as enum ('uploading', 'ready', 'removed');
create type interest as enum ('everyone', 'women', 'men', 'nonbinary');

create table account (
  id uuid primary key references auth.users (id) on delete cascade,
  status account_status not null default 'active',
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table profile (
  account_id uuid primary key references account (id) on delete cascade,
  birth_date date not null,
  gender gender_identity not null,
  custom_gender text not null default '',
  show_gender boolean not null default false,
  visible boolean not null default true,
  revision bigint not null default 0,
  updated_at timestamptz not null default now(),
  constraint profile_self_description check (gender <> 'self' or custom_gender <> '')
);

create table photo (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references account (id) on delete cascade,
  slot int not null check (slot between 0 and 3),
  storage_path text not null,
  state photo_state not null default 'uploading',
  created_at timestamptz not null default now()
);
create unique index photo_live_slot on photo (account_id, slot) where state <> 'removed';

create table preferences (
  account_id uuid primary key references account (id) on delete cascade,
  interests interest[] not null,
  min_age int not null default 18 check (min_age between 18 and 99),
  max_age int not null default 99 check (max_age between 18 and 99),
  interval_s int not null default 30 check (interval_s in (15, 30, 45, 60, 75, 90, 105, 120)),
  delay_hours int not null default 2 check (delay_hours in (0, 1, 2, 4, 6, 12, 18, 24)),
  updated_at timestamptz not null default now(),
  constraint preferences_age_order check (min_age <= max_age),
  -- non-empty; "everyone" stands alone or not at all
  constraint preferences_interests check (
    cardinality(interests) > 0
    and (not ('everyone' = any (interests)) or cardinality(interests) = 1)
  )
);

create table intro_progress (
  account_id uuid primary key references account (id) on delete cascade,
  content_version int not null,
  completed_at timestamptz
);

create table device (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references account (id) on delete cascade,
  platform text not null default '',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index device_account on device (account_id);

create table entitlement (
  account_id uuid not null references account (id) on delete cascade,
  product text not null,
  status text not null,
  valid_until timestamptz,
  verification_revision bigint not null default 0,
  primary key (account_id, product)
);

-- Row-level security: own rows only. anon gets nothing.
alter table account enable row level security;
alter table profile enable row level security;
alter table photo enable row level security;
alter table preferences enable row level security;
alter table intro_progress enable row level security;
alter table device enable row level security;
alter table entitlement enable row level security;

create policy account_own on account for all to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy profile_own on profile for all to authenticated using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy photo_own on photo for all to authenticated using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy preferences_own on preferences for all to authenticated using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy intro_own on intro_progress for all to authenticated using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy device_own on device for all to authenticated using (account_id = auth.uid()) with check (account_id = auth.uid());
create policy entitlement_read on entitlement for select to authenticated using (account_id = auth.uid());

revoke all on all tables in schema public from anon;
revoke insert, update, delete on entitlement from authenticated;
