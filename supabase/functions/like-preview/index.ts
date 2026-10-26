// GET ?token=<uuid>: the blurred preview behind a Likes You token. The token
// is resolved server-side and re-checked for eligibility; the liker's account
// id and photo id never reach the client.
import { createClient } from "@supabase/supabase-js";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") return reply(405, { error: "method" });
  const auth = req.headers.get("Authorization");
  if (!auth) return reply(401, { error: "unauthenticated" });
  const token = new URL(req.url).searchParams.get("token") ?? "";
  if (!UUID.test(token)) return reply(404, { error: "unknown_token" });

  const user = createClient(url, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: photoId, error } = await user.rpc("resolve_like_preview", { token });
  if (error) return reply(401, { error: "unauthenticated" });
  if (!photoId) return reply(404, { error: "unknown_token" });

  const admin = createClient(url, serviceKey);
  const { data: file, error: dl } = await admin.storage.from("previews").download(`${photoId}.jpg`);
  if (dl || !file) return reply(404, { error: "unknown_token" });
  return new Response(file.stream(), {
    headers: { "Content-Type": "image/jpeg", "Cache-Control": "private, max-age=300" },
  });
});
