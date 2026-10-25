-- Delay changes: an increase extends the release floor of pending encounters,
-- a reduction never moves it earlier (owner decision, 2026-10-24).

create or replace function app.extend_release_floor() returns trigger
language plpgsql security definer
set search_path = public, app, extensions
as $$
begin
  update encounter e
  set release_at = greatest(
        e.release_at,
        e.encountered_at + make_interval(hours => app.effective_delay_hours(p.a, p.b))
      )
  from pair p
  where p.id = e.pair_id
    and e.state = 'pending'
    and new.account_id in (p.a, p.b);
  return new;
end $$;

create trigger preferences_delay_changed
after update of delay_hours on preferences
for each row
when (old.delay_hours is distinct from new.delay_hours)
execute function app.extend_release_floor();
