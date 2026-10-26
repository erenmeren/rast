-- Pin search_path on every app function (Supabase advisor 0011). They run
-- under security-definer wrappers that already set it; this makes direct
-- calls (pg_cron, psql) behave the same.
alter function app.age_on(date, date) set search_path = public, app, extensions;
alter function app.uid() set search_path = public, app, extensions;
alter function app.pair_for(uuid, uuid) set search_path = public, app, extensions;
alter function app.setup_complete(uuid) set search_path = public, app, extensions;
alter function app.gender_fits(gender_identity, interest[]) set search_path = public, app, extensions;
alter function app.age_fits(int, int, int) set search_path = public, app, extensions;
alter function app.mutual_preferences(uuid, uuid) set search_path = public, app, extensions;
alter function app.pair_open(uuid) set search_path = public, app, extensions;
alter function app.eligible_pair(uuid, uuid) set search_path = public, app, extensions;
alter function app.effective_delay_hours(uuid, uuid) set search_path = public, app, extensions;
alter function app.cell_keys(geography) set search_path = public, app, extensions;
alter function app.evaluate_encounters(uuid) set search_path = public, app, extensions;
alter function app.release_due_encounters() set search_path = public, app, extensions;
alter function app.lock_pair(uuid, uuid) set search_path = public, app, extensions;
alter function app.lock_existing_pair(uuid, uuid) set search_path = public, app, extensions;
alter function app.bump(uuid, text) set search_path = public, app, extensions;
alter function app.close_pair(pair) set search_path = public, app, extensions;
alter function app.account_exists(uuid) set search_path = public, app, extensions;
alter function app.account_active(uuid) set search_path = public, app, extensions;
alter function app.purge_location_samples() set search_path = public, app, extensions;
alter function app.purge_void_encounters() set search_path = public, app, extensions;
