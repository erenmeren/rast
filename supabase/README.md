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
