-- Pending encounters become visible at most one minute after release_at and
-- never before it. Scheduled with pg_cron when the extension is enabled.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('release-due-encounters', '* * * * *', 'select app.release_due_encounters()');
  end if;
end $$;
