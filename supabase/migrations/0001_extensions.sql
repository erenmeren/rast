-- Extensions and the internal schema. PostGIS already exists on Supabase
-- (schema extensions) and on the postgis docker image (schema public).
create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

-- Internal helpers live here; the API never exposes this schema.
create schema if not exists app;
revoke all on schema app from public;
grant usage on schema app to postgres;
-- Functions created in app are not callable by anyone unless granted one by one.
alter default privileges for role postgres in schema app revoke execute on functions from public;
