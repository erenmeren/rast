-- The default-privilege revoke in 0001 does not take effect on Supabase (no
-- pg_default_acl row is stored for schema app), so every app function kept the
-- built-in execute grant to public. Revoke it explicitly; only pair_visible is
-- callable by API roles (RLS policies use it).
revoke execute on all functions in schema app from public, anon, authenticated;
grant execute on function app.pair_visible(uuid, uuid) to authenticated;
