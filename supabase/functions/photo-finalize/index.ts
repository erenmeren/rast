// POST {"photo_id"}: renders the 32 px preview of the caller's photo and marks
// it ready. Design: docs/superpowers/specs/2026-10-26-media-design.md
import { createClient } from "@supabase/supabase-js";
import { Image } from "imagescript";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PREVIEW_WIDTH = 32;
const MIN_WIDTH = 320;

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return reply(405, { error: "method" });
  const auth = req.headers.get("Authorization");
  if (!auth) return reply(401, { error: "unauthenticated" });
  let photoId: string | undefined;
  try {
    photoId = (await req.json()).photo_id;
  } catch {
    return reply(400, { error: "bad_request" });
  }
  if (typeof photoId !== "string") return reply(400, { error: "bad_request" });

  // The caller's own row only: RLS on photo hides everyone else's.
  const user = createClient(url, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: photo, error } = await user.from("photo").select("id, account_id, slot, storage_path, state").eq("id", photoId).maybeSingle();
  if (error) return reply(401, { error: "unauthenticated" });
  if (!photo || photo.state === "removed") return reply(404, { error: "unknown_photo" });

  const admin = createClient(url, serviceKey);
  const { data: file, error: dl } = await admin.storage.from("photos").download(photo.storage_path);
  if (dl || !file) return reply(404, { error: "missing_upload" });

  let image: Image;
  try {
    const decoded = await Image.decode(new Uint8Array(await file.arrayBuffer()));
    if (!(decoded instanceof Image)) return reply(422, { error: "bad_image" });
    image = decoded;
  } catch {
    return reply(422, { error: "bad_image" });
  }
  if (image.width < MIN_WIDTH) return reply(422, { error: "too_small" });

  const preview = await image.resize(PREVIEW_WIDTH, Image.RESIZE_AUTO).encodeJPEG(60);
  const { error: up } = await admin.storage.from("previews").upload(`${photo.id}.jpg`, preview, { contentType: "image/jpeg", upsert: true });
  if (up) return reply(500, { error: "preview_failed" });

  // The photo this one replaces retires first (one ready photo per slot).
  // Never resurrect a row the owner removed while the preview was rendering.
  await admin.from("photo").update({ state: "removed" }).eq("account_id", photo.account_id).eq("slot", photo.slot).eq("state", "ready").neq("id", photo.id);
  const { data: marked, error: mark } = await admin.from("photo").update({ state: "ready" }).eq("id", photo.id).neq("state", "removed").select("id");
  if (mark) return reply(500, { error: "mark_failed" });
  if (!marked || marked.length === 0) return reply(404, { error: "unknown_photo" });
  return reply(200, { outcome: "ready" });
});
