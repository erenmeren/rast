// FCM HTTP v1: the fixed copy per kind, an OAuth token minted from the service
// account, one send per device token.
export type Kind = "matched" | "liked" | "message";

export type Message = { notification: { title: string; body: string }; data: Record<string, string> };

const COPY: Record<Kind, { title: string; body: string }> = {
  matched: { title: "It's a match", body: "Someone you crossed paths with likes you back." },
  liked: { title: "Someone likes you", body: "A new like is waiting in Likes You." },
  message: { title: "New message", body: "Someone you matched with wrote to you." },
};

// The liker stays hidden: no account id travels with a like.
export function messageFor(kind: Kind, otherId: string | null): Message {
  const data: Record<string, string> = { kind };
  if (kind !== "liked" && otherId) data.account_id = otherId;
  return { notification: COPY[kind], data };
}

type ServiceAccount = { client_email: string; private_key: string };

let cached: { token: string; expiresAt: number } | null = null;

function b64url(bytes: Uint8Array | string): string {
  const bin = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expiresAt - 300 > now) return cached.token;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)));
  const assertion = `${header}.${claims}.${b64url(signature)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${assertion}`,
  });
  if (!res.ok) throw new Error(`oauth ${res.status}`);
  const json = await res.json();
  cached = { token: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cached.token;
}

export type SendResult = "sent" | "unregistered" | "error";

export async function send(projectId: string, token: string, msg: Message, bearer: string): Promise<SendResult> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: msg.notification,
        data: msg.data,
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
      },
    }),
  });
  if (res.ok) return "sent";
  const body = await res.text();
  if (res.status === 404 || body.includes("UNREGISTERED")) return "unregistered";
  console.error("fcm", res.status, body.slice(0, 300));
  return "error";
}
