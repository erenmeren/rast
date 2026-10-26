-- Photo storage: buckets, storage policies on the 5b rule, server-only
-- `ready`, and preview-token resolution for the like-preview function.
-- Design: docs/superpowers/specs/2026-10-26-media-design.md

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 5242880, '{image/jpeg,image/png}')
on conflict (id) do nothing;
insert into storage.buckets (id, name, public)
values ('previews', 'previews', false)
on conflict (id) do nothing;

-- A photo row may only point into its owner's folder.
alter table photo add constraint photo_path_own_folder check (storage_path like account_id::text || '/%');

-- First path segment as an account id, null when it is not a uuid.
create or replace function app.photo_owner(name text) returns uuid
language sql immutable
set search_path = public, app, extensions
as $$
  select case when split_part(name, '/', 1) ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
              then split_part(name, '/', 1)::uuid end
$$;

-- Only the finalize function (service role, no JWT subject) may mark a photo ready.
create or replace function app.photo_ready_guard() returns trigger
language plpgsql
set search_path = public, app, extensions
as $$
begin
  if auth.uid() is not null then
    raise exception 'photo_ready_is_server_only' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger photo_ready_guard
before update of state on photo
for each row
when (new.state = 'ready' and old.state is distinct from 'ready')
execute function app.photo_ready_guard();

create policy photos_read on storage.objects for select to authenticated
  using (bucket_id = 'photos' and app.can_view_photos(auth.uid(), app.photo_owner(name)));
create policy photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and app.photo_owner(name) = auth.uid());
create policy photos_update on storage.objects for update to authenticated
  using (bucket_id = 'photos' and app.photo_owner(name) = auth.uid())
  with check (bucket_id = 'photos' and app.photo_owner(name) = auth.uid());
create policy photos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and app.photo_owner(name) = auth.uid());

-- The liker's first photo for a preview token of the caller, if the like is
-- still eligible right now. Never the liker's account id.
create or replace function public.resolve_like_preview(token uuid) returns uuid
language sql stable security definer
set search_path = public, app, extensions
as $$
  select ph.id
  from like_preview lp
  join app.incoming_likes(app.uid()) i on i.pid = lp.pair_id
  join photo ph on ph.account_id = i.other and ph.slot = 0 and ph.state = 'ready'
  where lp.token = resolve_like_preview.token
    and lp.viewer = app.uid()
    and lp.expires_at > now()
$$;

revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
grant execute on function app.can_view_photos(uuid, uuid) to authenticated;
grant execute on function app.photo_owner(text) to authenticated;
revoke all on function public.resolve_like_preview(uuid) from public, anon;
grant execute on function public.resolve_like_preview(uuid) to authenticated;
