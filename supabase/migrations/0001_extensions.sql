-- Extensions and the internal schema. PostGIS already exists on Supabase
-- (schema extensions) and on the postgis docker image (schema public).
create schema if not exists extensions;
create extension if not exists postgis;

-- Internal helpers live here; the API never exposes this schema.
create schema if not exists app;
revoke all on schema app from public;
grant usage on schema app to postgres;
