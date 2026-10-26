# Photo storage, previews and phone sign-in (Phase 5c) design

Date: 2026-10-26. Builds on 5a/5b. Engineering calls, no owner question round; all reversible and listed in the decision log. Handoff: docs/04 §5 (media authorization), docs/05 LIKE-02, LIKE-03, PHOTO-*.

## Goal

Serve photo bytes under the rules 5b proved in SQL: originals only to people who may see them, blurred previews only through an opaque token, and make `ready` a server-side state. Plus the owner checklist for Twilio Verify.

## Non-goals

Flutter adapters (5d); image moderation; photo deletion of storage objects when a row is `removed` (client deletes its own object; a purge job can follow); EXIF stripping (noted for 5d, Flutter side).

## Buckets and paths

- `photos`: private, 5 MB limit, `image/jpeg` and `image/png`. Object path = `photo.storage_path`, which must start with `<account_id>/` (check constraint, new in this phase; the harness fixtures move to `<account_id>/<n>.jpg`).
- `previews`: private, service role only. Object path `<photo_id>.jpg`, a 32 px wide JPEG of the original. Low resolution is the blur: the client upscales it. No client policy, no signed URLs: bytes only ever leave through the `like-preview` function, so the photo id never reaches a free member.

## Storage policies (`storage.objects`)

- `photos` select: `app.can_view_photos(auth.uid(), app.photo_owner(name))` where `app.photo_owner(name)` is the first path segment as uuid, or null when it is not one.
- `photos` insert, update, delete: `app.photo_owner(name) = auth.uid()`.
- `previews`: nothing for `anon`/`authenticated`.

## `ready` is server-only

Trigger `photo_ready_guard` (before update of `state` on `photo`): raises `photo_ready_is_server_only` when the new state is `ready` and `auth.uid()` is not null. The service role has no JWT subject, so the finalize function may set it; clients may still move a photo to `removed`.

## Edge Functions (Deno, `supabase/functions/`)

- `photo-finalize` (POST `{"photo_id"}`, user JWT, verify_jwt on): reads the caller's `photo` row through RLS (404 `unknown_photo` otherwise); downloads the original with the service key; decodes it (`npm:imagescript@1.3.0`), rejects anything that is not a decodable JPEG/PNG (422 `bad_image`) or narrower than 320 px (422 `too_small`); writes `previews/<photo_id>.jpg`; sets `state = 'ready'` with the service key; returns `{"outcome":"ready"}`. Idempotent: an already-ready photo re-renders its preview and returns `ready`.
- `like-preview` (GET `?token=<uuid>`, user JWT, verify_jwt on): calls `public.resolve_like_preview(token)` as the caller; null → 404 `unknown_token`; otherwise streams `previews/<photo_id>.jpg` with `Content-Type: image/jpeg`, `Cache-Control: private, max-age=300`.

## `public.resolve_like_preview(token uuid) returns uuid`

Security definer. Returns the slot-0 `ready` photo id of the liker when the token belongs to the caller, has not expired and its pair is still in `app.incoming_likes(me)`; null otherwise. Never reveals the liker's account id.

## Twilio Verify (owner checklist, dashboard)

1. Twilio console: create a Verify service, note the Account SID, Auth Token and Verify Service SID.
2. Supabase dashboard → Authentication → Providers → Phone: enable, provider Twilio Verify, paste the three values, save.
3. Authentication → Rate limits: keep the SMS default (30/h) until Phase 5d testing needs more.
4. Turkey: alphanumeric sender IDs need registration; Verify uses Twilio's shared numeric senders by default, which is what we want for now.

## Tests

SQL via the harness with a `storage_stub.sql` (schema `storage`: `buckets`, `objects`, `foldername`, `filename`, `extension`; applied after `auth_stub.sql`): bucket rows exist with the limits; owner can insert/select/delete own object; cannot insert under another folder; candidate can select the other's original; stranger and pending-pair member cannot; nobody but postgres reads `previews`; `photo_owner` returns null on junk; client update to `ready` raises, to `removed` passes, service path passes; `resolve_like_preview` returns the liker's slot-0 photo for the viewer and null for the wrong viewer, an expired token or a blocked pair; privileges on the new function.

Edge Functions: deployed through the MCP server; smoke test = unauthenticated call returns 401. End-to-end with a real user is Phase 5d's first task (no auth user exists yet).
