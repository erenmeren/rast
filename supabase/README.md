# rast backend (Supabase)

Plain SQL migrations under `migrations/`, applied in file order. `public` holds the tables and the RPC functions clients call; `app` holds internal helpers and is not exposed through the API. Design: `docs/superpowers/specs/2026-10-25-backend-core-design.md`.

## Tests

Prerequisites: the docker CLI and the image `postgis/postgis:17-3.5` (`docker pull postgis/postgis:17-3.5`). Python 3 standard library only.

```bash
python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'
```

The harness starts a throwaway container, applies `tests/auth_stub.sql` and `tests/storage_stub.sql` (stand-ins for Supabase's `auth` and `storage` schemas and the API roles; never apply them to a real project) and then every migration, and runs each test as one `begin … rollback` script. Set `RAST_PG_CONTAINER=<container id>` to reuse a container you started yourself; the harness then applies nothing and leaves it running.

## Applying to a Supabase project

Link the project once (`supabase link --project-ref <ref>`) and run `supabase db push`; the CLI applies `migrations/*.sql` in order. Enable `pg_cron` in the dashboard first if you want the retention jobs scheduled; without it the schedule step is skipped and the purge functions can be called by hand.

## Layout

| Migration | Contents |
| --- | --- |
| `0001_extensions.sql` | PostGIS, the `app` schema |
| `0002_accounts.sql` | account, profile, photo, preferences, intro_progress, device, entitlement; own-row RLS |
| `0003_pairs.sql` | pair, pair_like, block, encounter, message, report, pair_event, encounter_params; member RLS, encounter times hidden |
| `0004_helpers.sql` | `app.age_on`, `app.uid`, `app.pair_for`, `app.setup_complete`, `app.mutual_preferences`, `app.pair_open`, `app.eligible_pair`, `app.effective_delay_hours` |
| `0005_location.sql` | location_sample (closed to clients), `submit_location_samples` RPC, `app.evaluate_encounters`, `app.release_due_encounters` |
| `0006_delay_policy.sql` | delay changes extend, never shorten, the release floor |
| `0007_pair_ops.sql` | `like_account`, `disconnect_pair`, `block_account`, `unblock_account`, `send_message`, `submit_report`, `delete_account` |
| `0008_retention.sql` | `app.purge_location_samples` (24 h), `app.purge_void_encounters` (30 d), pg_cron schedule when available |
| `0009_app_function_grants.sql` | explicit execute revoke on `app` functions (the 0001 default-privilege revoke is a no-op on Supabase) |
| `0010_search_path.sql` | pins `search_path` on every `app` function |
| `0011_release_schedule.sql` | pg_cron: `app.release_due_encounters` every minute |
| `0012_discovery.sql` | discovery_session, pair_pass, `app.candidate`, `app.order_key`, `app.card`, `app.deck`; `start_discovery_session`, `discovery_cards`, `pass_account`, `rewind_pass` |
| `0013_likes_you.sql` | `app.is_premium`, `app.incoming_likes`, like_preview, `likes_you`, `app.can_view_photos`, `app.purge_discovery` (daily) |
| `0014_review_fixes.sql` | passes no longer hide likers from Likes You; previews ordered by token; `pair_pass` index; `app.can_view_photos` security definer, callable by `authenticated` |
| `0015_media.sql` | buckets `photos`, `previews`; `storage.objects` policies on `app.can_view_photos` / `app.photo_owner`; `photo_path_own_folder` check; `photo_ready_guard` trigger; `resolve_like_preview` |
| `0016_photo_guard.sql` | `ready` is server-only on insert too; clients may update only `photo.state` and `photo.slot` |

Thresholds live in the single `encounter_params` row and are provisional until Phase 0 replaces them: radius 20 m, skew 60 s, sample age 24 h, future 60 s, accuracy 50 m. Change them with an `update`, not a migration, until the field numbers are in. `app.release_due_encounters()` runs every minute under pg_cron (0011).

## Phase 5b RPCs (discovery)

Design: `docs/superpowers/specs/2026-10-26-discovery-design.md`. All return `jsonb` with an `outcome` key.

| RPC | Outcomes |
| --- | --- |
| `start_discovery_session()` | `ok` + `session_id`. Replaces the caller's previous session; sessions expire after 24 h. |
| `discovery_cards(session_id, after, page_size)` | `ok` + `cards` + `next` (pass `next` back as `after`; null means the end); `session_expired`; `bad_cursor`. `page_size` is clamped to 1..50. |
| `pass_account(target, client_op_id)` | `passed`, `unavailable`. |
| `rewind_pass()` | `restored` + `account_id`, `unavailable` (no pass, or the person is no longer available). |
| `likes_you()` | `ok` + `premium` + `count` + either `cards` (premium) or `previews` of `{token, age}` (free). Writes tokens, so call it with POST (the supabase-dart `rpc()` default), never `GET`. A pass does not remove a liker from this set. |

A card is `{account_id, age, gender|null, custom_gender, photos}`; `gender` is null unless the member shows it. Photo bytes are not served yet (Phase 5c); `app.can_view_photos(viewer, owner)` is the rule the Storage policy will use.

## Phase 5c: photos and previews

Design: `docs/superpowers/specs/2026-10-26-media-design.md`.

- Upload flow (client): insert a `photo` row (`state = 'uploading'`, `storage_path = '<account_id>/<photo_id>.jpg'`), upload the bytes to bucket `photos` at that path, then `POST /functions/v1/photo-finalize` with `{"photo_id"}` and the user's JWT. The function renders `previews/<photo_id>.jpg` (32 px wide) and sets `state = 'ready'`; clients cannot set `ready` themselves (`photo_ready_guard`). Errors: `400 bad_request`, `404 unknown_photo` / `missing_upload`, `422 bad_image` / `too_small` (narrower than 320 px).
- Originals: download from bucket `photos` with the user's JWT; Storage RLS applies `app.can_view_photos(viewer, folder owner)`. Owners may insert, update and delete under their own folder only.
- Likes You previews: `GET /functions/v1/like-preview?token=<token from likes_you()>` with the user's JWT returns `image/jpeg` bytes (`Cache-Control: private, max-age=300`) or `404 unknown_token`. The token is re-checked against `app.incoming_likes` at fetch time. Never request `previews` from Storage directly: the bucket has no client policy.
- Edge Function sources live in `functions/`; deploy with the MCP `deploy_edge_function` tool (pass `import_map_path: deno.json`) or `supabase functions deploy`.
- MCP note: a migration containing `drop …` makes the Supabase MCP server ask for a confirmation that this workflow cannot answer (`Invalid or expired requestState`). Use `create or replace` forms instead.

## Phone sign-in (owner checklist)

1. Twilio console: create a Verify service; note Account SID, Auth Token and Verify Service SID.
2. Supabase dashboard → Authentication → Providers → Phone: enable, provider **Twilio Verify**, paste the three values, save.
3. Authentication → Rate limits: keep the SMS default until Phase 5d testing needs more.
4. Turkey: Verify's shared numeric senders work without sender-ID registration; register an alphanumeric sender only if branding is needed later.
