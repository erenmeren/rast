-- Phase 5c review fixes. A client could insert a photo row already `ready`
-- (the guard only watched updates) and could repoint storage_path after
-- finalize. Now `ready` is server-only on insert too, and clients may change
-- only state (to `removed`) and slot (reorder).

create or replace function app.photo_ready_guard() returns trigger
language plpgsql
set search_path = public, app, extensions
as $$
begin
  if auth.uid() is not null and (tg_op = 'INSERT' or old.state is distinct from 'ready') then
    raise exception 'photo_ready_is_server_only' using errcode = 'P0001';
  end if;
  return new;
end $$;
create or replace trigger photo_ready_guard
before insert or update on photo
for each row
when (new.state = 'ready')
execute function app.photo_ready_guard();

revoke update on photo from authenticated;
grant update (state, slot) on photo to authenticated;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
grant execute on function app.can_view_photos(uuid, uuid) to authenticated;
grant execute on function app.photo_owner(text) to authenticated;
