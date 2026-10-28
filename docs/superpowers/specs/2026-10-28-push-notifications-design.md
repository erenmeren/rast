# Push notifications design

Date: 2026-10-28. Owner asked for notifications on a new match, an incoming like and a new message, each one switchable by the member. Decisions taken in chat: Firebase Cloud Messaging (FCM); no names or message text in a notification (the product has no names).

## Goal

A member with the app closed learns within seconds that someone matched with them, liked them or wrote to them, and can turn each of the three off in Profile › Notifications. The three choices live on the server so the sender respects them; nothing about the other person's identity, the crossing time or place ever appears in a notification.

## Non-goals

Notification badges and in-app banners while the app is in the foreground (realtime already refreshes chats and likes), per-conversation muting, quiet hours, retries of a failed send beyond one attempt, iOS field validation (no device), rich notifications (photos), analytics.

## Shape

### Database (`0020_push.sql`)

- `preferences.notify_matches`, `notify_likes`, `notify_messages boolean not null default true`. Clients write them through the existing own-row update policy.
- `device.push_token text` (nullable). Clients write it through the existing `device_update` policy.
- `push_outbox (id bigserial, recipient uuid → account, kind text in ('matched','liked','message'), pair_id uuid → pair, created_at, sent_at, result text)`. RLS on, no grants to `anon` or `authenticated`: only the service role reads and updates it.
- `app.notify(recipient uuid, kind text, pid uuid) returns void`: inserts one outbox row when the recipient's preference for `kind` is on and the recipient has at least one device with a token. Otherwise nothing.
- Call sites, recreated in 0020: `like_account` notifies both members with `matched` on a new match, and the target with `liked` on a new one-sided like (never on a repeated like, never the liker). `send_message` notifies the target with `message`. `disconnected` and blocks notify nobody.
- `app.push_hook (id boolean pk, url text, secret text)`: single row the owner inserts after deploying the function. `app.push_outbox_hook()` trigger after insert on `push_outbox`: when `pg_net` is installed and the hook row exists, `net.http_post(url, body {"id"}, headers Content-Type + x-push-secret)`. Without `pg_net` (the test container) the trigger is a no-op, so the outbox is still testable.
- `pg_net` is created when available (`pg_available_extensions`), same guard style as `pg_cron`.
- `app.purge_discovery()` (daily) also deletes outbox rows older than 7 days.

### Edge function `push-send`

- `POST {"id": <outbox id>}` with header `x-push-secret` equal to the `PUSH_HOOK_SECRET` secret; anything else is 401.
- Reads the row with the service role. Already sent → `{"outcome":"already"}`. Loads the recipient's devices with a token and the pair's other member (for the deep link).
- Copy, fixed:
  - `matched`: title `It's a match`, body `Someone you crossed paths with likes you back.`
  - `liked`: title `Someone likes you`, body `A new like is waiting in Likes You.`
  - `message`: title `New message`, body `Someone you matched with wrote to you.`
- Data payload: `kind`, and `account_id` of the other member for `matched` and `message` (not for `liked`: the liker stays hidden).
- Sends through FCM HTTP v1 (`https://fcm.googleapis.com/v1/projects/<project_id>/messages:send`), one request per token, authorised with an OAuth token minted from the `FCM_SERVICE_ACCOUNT` secret (service account JSON; RS256 JWT via WebCrypto, cached until expiry). A `404`/`UNREGISTERED` answer clears that device's token.
- Marks the row `sent_at = now()`, `result` = `sent:<n>` | `no_device` | `fcm_error:<status>`.

### Flutter

- `Settings.notifications` (one bool) becomes `notifyMatches`, `notifyLikes`, `notifyMessages`, all default true. `NotifyKind { matches, likes, messages }`. `SettingsRepository.setNotify(NotifyKind, bool)` replaces `setNotifications`. Mock keys `rast.notify.matches|likes|messages`; Supabase writes the `preferences` column and `hydrate()` reads the three back; `savePreferences` carries them like `delay_hours`.
- Notifications sheet: three `ToggleRow`s, titles `New matches`, `Likes`, `Messages`. Profile row detail `On` when any is on, `Off` when all are off.
- `PushRepository` (new interface): `requestPermission()`, `tokens()` (current token, then refreshes), `register(token)` (writes `device.push_token` of this install), `unregister()` (clears the column and deletes the FCM token), `taps()` (a `PushTap(kind, accountId)` per notification the member opened, including the one that launched the app). Mock: permission granted, empty streams, no-ops.
- `SupabasePushRepository`: `firebase_messaging`. The device row comes from `ensureDeviceId(client, store)`, extracted from `SupabaseLocationRepository.deviceId()` and shared.
- Firebase is initialised in `supabaseOverrides` only when the four dart-defines `RAST_FCM_API_KEY`, `RAST_FCM_APP_ID`, `RAST_FCM_SENDER_ID`, `RAST_FCM_PROJECT_ID` are set (`--dart-define-from-file=firebase.env.json`, committed: these are client keys like the Supabase publishable key). Without them the mock push repository stays, so the app builds and runs before the owner creates the Firebase project.
- `PushService` (`pushProvider`, app state like `locationProvider`): while the session is active it requests permission once, registers every token the repository emits, and routes taps: `message` → `/chats/<account_id>`, `matched` → `/chats`, `liked` → `/likes`. `SessionNotifier.logOut()` calls `unregister()` before signing out so a signed-out phone receives nothing.

## Owner setup

1. Firebase project, Android app with package `app.rast.rast`; copy API key, app id, sender id and project id into `firebase.env.json`. iOS later: APNs key uploaded to Firebase.
2. Service account JSON (Firebase console › Project settings › Service accounts) → edge function secret `FCM_SERVICE_ACCOUNT`.
3. `PUSH_HOOK_SECRET` (random) → edge function secret and `insert into app.push_hook (url, secret) values ('https://<ref>.supabase.co/functions/v1/push-send', '<secret>')`.
4. Enable `pg_net` in the dashboard if 0020 did not (it is available on hosted projects).
5. Any redeploy of `push-send` keeps `verify_jwt` off (`supabase functions deploy push-send --no-verify-jwt`).

## Tests

- SQL (`supabase/tests/test_push.py`): a like writes one `liked` row for the target and none for the liker; a repeated like writes nothing; a match writes `matched` for both; a message writes `message` for the other member; a preference off or no token means no row; `push_outbox` is not readable by `authenticated`; `app.notify` is not callable by `authenticated`; the purge removes rows older than 7 days and keeps younger ones.
- Edge function (`deno test`): `messageFor(kind, otherId)` returns the fixed copy and the right data keys.
- Flutter: settings notifier persists the three flags and the sheet toggles them (profile row reads `Off` when all are off); `PushService` with a fake repository registers the first and the refreshed token for an active member, does nothing when signed out, and a tap moves the router to the right path.
- Live (`test/live/push_test.dart`): writing `device.push_token` and the three `preferences` columns round-trips.
- Device run after the owner setup: a like, a match and a message from the Nothing Phone arrive on the locked Pixel 9a; each toggle off stops its kind.
