# rast backend (Supabase)

Plain SQL migrations under `migrations/`, applied in file order. `public` holds the tables and the RPC functions clients call; `app` holds internal helpers and is not exposed through the API. Design: `docs/superpowers/specs/2026-10-25-backend-core-design.md`.

## Tests

Prerequisites: the docker CLI and the image `postgis/postgis:17-3.5` (`docker pull postgis/postgis:17-3.5`). Python 3 standard library only.

```bash
python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'
```

The harness starts a throwaway container, applies `tests/auth_stub.sql` (a stand-in for Supabase's `auth` schema and API roles; never apply it to a real project) and then every migration, and runs each test as one `begin … rollback` script. Set `RAST_PG_CONTAINER=<container id>` to reuse a container you started yourself; the harness then applies nothing and leaves it running.

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

Thresholds live in the single `encounter_params` row and are provisional until Phase 0 replaces them: radius 20 m, skew 60 s, sample age 24 h, future 60 s, accuracy 50 m. Change them with an `update`, not a migration, until the field numbers are in. Something still has to call `app.release_due_encounters()` on a schedule (a pg_cron job once the cadence is decided, or the discovery RPC in Phase 5b before it reads).
