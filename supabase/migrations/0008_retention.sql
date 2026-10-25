-- Retention. Raw samples live 24 h (owner decision 2026-10-24); void
-- encounters 30 days. Scheduled with pg_cron when the extension is enabled;
-- otherwise the functions are called by hand or by an external scheduler.

create or replace function app.purge_location_samples() returns int
language plpgsql volatile as $$
declare
  n int;
begin
  delete from location_sample where received_at < now() - interval '24 hours';
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function app.purge_void_encounters() returns int
language plpgsql volatile as $$
declare
  n int;
begin
  delete from encounter where state = 'void' and created_at < now() - interval '30 days';
  get diagnostics n = row_count;
  return n;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('purge-location-samples', '17 * * * *', 'select app.purge_location_samples()');
    perform cron.schedule('purge-void-encounters', '23 3 * * *', 'select app.purge_void_encounters()');
  end if;
end $$;
