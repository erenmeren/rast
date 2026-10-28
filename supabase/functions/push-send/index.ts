// POST {"id"}: sends one push_outbox row to the recipient's devices. Called by
// the pg_net trigger (0020) with the shared secret in x-push-secret.
// Design: docs/superpowers/specs/2026-10-28-push-notifications-design.md
import { createClient } from "@supabase/supabase-js";
import { accessToken, type Kind, messageFor, send } from "./fcm.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const hookSecret = Deno.env.get("PUSH_HOOK_SECRET");
const serviceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT");

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return reply(405, { error: "method" });
  if (!hookSecret || req.headers.get("x-push-secret") !== hookSecret) return reply(401, { error: "unauthenticated" });
  let id: unknown;
  try {
    id = (await req.json()).id;
  } catch {
    return reply(400, { error: "bad_request" });
  }
  if (typeof id !== "number") return reply(400, { error: "bad_request" });

  const admin = createClient(url, serviceKey);
  const { data: row, error } = await admin.from("push_outbox").select("id, recipient, kind, pair_id, sent_at").eq("id", id).maybeSingle();
  if (error) return reply(500, { error: "lookup_failed" });
  if (!row) return reply(404, { error: "unknown_row" });
  if (row.sent_at) return reply(200, { outcome: "already" });

  const finish = async (result: string) => {
    await admin.from("push_outbox").update({ sent_at: new Date().toISOString(), result }).eq("id", id);
    return reply(200, { outcome: result });
  };

  const { data: devices } = await admin.from("device").select("id, push_token").eq("account_id", row.recipient).not("push_token", "is", null);
  if (!devices || devices.length === 0) return finish("no_device");

  let otherId: string | null = null;
  if (row.pair_id) {
    const { data: pair } = await admin.from("pair").select("a, b").eq("id", row.pair_id).maybeSingle();
    if (pair) otherId = pair.a === row.recipient ? pair.b : pair.a;
  }
  const msg = messageFor(row.kind as Kind, otherId);

  if (!serviceAccount) return finish("fcm_error:no_service_account");
  const sa = JSON.parse(serviceAccount);
  let bearer: string;
  try {
    bearer = await accessToken(sa);
  } catch (e) {
    console.error(e);
    return finish("fcm_error:oauth");
  }
  const results = await Promise.all(devices.map((d) => send(sa.project_id, d.push_token as string, msg, bearer)));
  const dead = devices.filter((_, i) => results[i] === "unregistered").map((d) => d.id);
  if (dead.length > 0) await admin.from("device").update({ push_token: null }).in("id", dead);
  const sent = results.filter((r) => r === "sent").length;
  return finish(sent > 0 ? `sent:${sent}` : results.includes("error") ? "fcm_error:send" : "no_device");
});
