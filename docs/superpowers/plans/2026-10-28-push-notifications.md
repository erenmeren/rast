# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A member learns by push about a new match, an incoming like and a new message, each kind switchable in Profile › Notifications and respected server-side.

**Architecture:** The RPCs that already create the events (`like_account`, `send_message`) write a `push_outbox` row through `app.notify`, gated by the recipient's three `preferences` flags and the presence of a device token. A `pg_net` trigger posts the row id to the `push-send` edge function, which sends through FCM HTTP v1. The Flutter app registers its FCM token on the `device` row, exposes three toggles, and routes a tapped notification.

**Tech Stack:** Postgres (pg_net, plpgsql), Supabase edge function (Deno, FCM HTTP v1, WebCrypto RS256), Flutter (`firebase_core`, `firebase_messaging`, Riverpod 3, go_router).

**Spec:** `docs/superpowers/specs/2026-10-28-push-notifications-design.md`

## Global Constraints

- Notification copy is fixed by the spec; no names, no message text, no crossing time or place, no liker identity.
- `push_outbox` and `app.push_hook` have no grants to `anon` or `authenticated`; `app.notify` and `app.push_outbox_hook` are not callable by API roles (0009 pattern: `revoke execute on all functions in schema app from public, anon, authenticated`).
- Every new `app` function sets `search_path = public, app, extensions` (0010 pattern).
- Migrations must apply on the test container (no `pg_net`, no `pg_cron`): guard with `pg_available_extensions` / `pg_extension`.
- The mock backend and builds without the four `RAST_FCM_*` defines keep working with no Firebase at all.
- Existing comments stay; surgical diffs; match the surrounding style (one-line Dart members, `c.body` tokens, `Space`/`Radii` scales).
- Verify commands: `python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'`, `flutter analyze`, `flutter test`.

## Review Focus

1. A like from a blocked or non-eligible person returns `unavailable` before `app.notify` is reached; no outbox row may appear (Task 1 test `test_unavailable_like_writes_nothing`).
2. A member with two devices receives one notification per device and a dead token on one device must not stop the other (Task 2 helper `sendAll` continues on error; live check in Task 6).
3. The owner's Nothing Phone still carries a token after log-out unless `unregister()` ran before `signOut()`; the Task 5 test `log out unregisters before the session ends` pins the order.
4. `hydrate()` on a reinstall must not reset the three flags to true when the server says false (Task 3 test `hydrate reads the three flags`).
5. A tap on a `liked` notification carries no `account_id`; the router must go to `/likes`, never to a person page (Task 5 test `a liked tap opens Likes You`).

---

### Task 1: Migration 0020 — outbox, preferences flags, notify, hook

**Files:**
- Create: `supabase/migrations/0020_push.sql`
- Create: `supabase/tests/test_push.py`
- Modify: `supabase/README.md` (layout table: add the 0020 row after 0019)

**Interfaces:**
- Produces: `preferences.notify_matches|notify_likes|notify_messages boolean not null default true`; `device.push_token text`; table `push_outbox (id bigserial pk, recipient uuid not null references account (id) on delete cascade, kind text not null check (kind in ('matched','liked','message')), pair_id uuid references pair (id), created_at timestamptz not null default now(), sent_at timestamptz, result text)`; `app.notify(recipient uuid, kind text, pid uuid) returns void`; `app.push_hook (id boolean primary key default true check (id), url text not null, secret text not null)`; trigger `push_outbox_notify after insert on push_outbox for each row execute function app.push_outbox_hook()`.

- [ ] **Step 1: Write the failing tests** in `supabase/tests/test_push.py`

```python
import json
import unittest
from harness import SqlError, as_user, db, member, uuid
from test_discovery import call, like, released_group

TOKEN = "update device set push_token = 'tok-%d' where account_id = '%s';"
OUTBOX = "select coalesce(jsonb_agg(jsonb_build_array(recipient, kind, pair_id is not null) order by id), '[]')::text from push_outbox;"
MSG = "send_message('%s','%s','hi')"

def tokens(*ns):
    return "".join(TOKEN % (n, uuid(n)) for n in ns)

class PushTests(unittest.TestCase):
    def rows(self, sql):
        return json.loads(db().run(sql + OUTBOX)[-1][0])

    def test_like_notifies_target_only_once(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700) + like(1, 2, 701)
        self.assertEqual(self.rows(sql), [[uuid(2), "liked", True]])

    def test_match_notifies_both(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700) + like(2, 1, 701)
        kinds = sorted((r[0], r[1]) for r in self.rows(sql))
        self.assertEqual(kinds, sorted([(uuid(2), "liked"), (uuid(1), "matched"), (uuid(2), "matched")]))

    def test_message_notifies_other_member(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700) + like(2, 1, 701) + call(1, MSG % (uuid(2), uuid(702)))
        self.assertEqual(self.rows(sql)[-1], [uuid(2), "message", True])

    def test_preference_off_or_no_token_writes_nothing(self):
        off = "update preferences set notify_likes = false where account_id = '%s';" % uuid(2)
        self.assertEqual(self.rows(released_group(1, 2) + tokens(1, 2) + off + like(1, 2, 700)), [])
        self.assertEqual(self.rows(released_group(1, 2) + like(1, 2, 700)), [])

    def test_unavailable_like_writes_nothing(self):
        sql = released_group(1, 2) + tokens(1, 2) + call(2, "block_account('%s','%s')" % (uuid(1), uuid(699))) + like(1, 2, 700)
        self.assertEqual(self.rows(sql), [])

    def test_purge_removes_week_old_rows(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700)
        sql += "update push_outbox set created_at = now() - interval '8 days'; insert into push_outbox (recipient, kind) values ('%s', 'liked'); select app.purge_discovery();" % uuid(2)
        self.assertEqual(db().run(sql + "select count(*) from push_outbox;")[-1], ["1"])

    def test_privileges(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700)
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(sql + as_user(uuid(2), "select * from push_outbox;"))
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(2), "select app.notify('%s', 'liked', null);" % uuid(2)))
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(2), "select * from app.push_hook;"))

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -I -m unittest supabase/tests/test_push.py -v` (from the repo root with `cd supabase/tests` if the harness imports need it; `test_followups.py` shows the working invocation)
Expected: FAIL with `relation "push_outbox" does not exist`

- [ ] **Step 3: Write `supabase/migrations/0020_push.sql`**

In order: the three `preferences` columns; `device.push_token`; `push_outbox` + index on `(recipient, id)` + `enable row level security` + `revoke all on push_outbox from anon, authenticated`; `app.push_hook` (revoke all from anon, authenticated); `app.notify` (plpgsql, volatile, security definer not needed: called from security-definer RPCs) — insert when `exists (select 1 from preferences f where f.account_id = recipient and case kind when 'matched' then f.notify_matches when 'liked' then f.notify_likes else f.notify_messages end) and exists (select 1 from device d where d.account_id = recipient and d.push_token is not null)`; `app.push_outbox_hook()` trigger function using `execute format(...)` of `select net.http_post(url := %L, body := %L::jsonb, headers := %L::jsonb)` only when `exists (select 1 from pg_extension where extname = 'pg_net')` and a hook row exists; the trigger; `create extension if not exists pg_net with schema extensions` inside a `do` block guarded by `pg_available_extensions`; recreate `public.like_account` and `public.send_message` by copying their 0007 bodies and adding `perform app.notify(me, 'matched', p.id); perform app.notify(target, 'matched', p.id);` after `bump(p.id, 'matched')`, `perform app.notify(target, 'liked', p.id);` inside `if inserted > 0`, and `perform app.notify(target, 'message', p.id);` after `bump(p.id, 'message')`; recreate `app.purge_discovery()` with `delete from push_outbox where created_at < now() - interval '7 days';` added; finish with the 0009/0010 lines: `revoke execute on all functions in schema app from public, anon, authenticated; grant execute on function app.pair_visible(uuid, uuid) to authenticated;` and `alter function app.notify(uuid, text, uuid) set search_path = public, app, extensions;` (same for `app.push_outbox_hook()`).

- [ ] **Step 4: Run the push tests and the whole SQL suite**

Run: `python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'`
Expected: all OK (the recreated `like_account` and `send_message` must keep `test_pair_ops.py` green)

- [ ] **Step 5: README row**

Add `| `0020_push.sql` | preferences notify flags, `device.push_token`, `push_outbox`, `app.notify` from `like_account`/`send_message`, `app.push_hook` + `pg_net` trigger to `push-send`, 7-day outbox purge |` to the layout table in `supabase/README.md`.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0020_push.sql supabase/tests/test_push.py supabase/README.md
git commit -m "feat(backend): push outbox, notify flags and pg_net hook (0020)"
```

---

### Task 2: Edge function `push-send`

**Files:**
- Create: `supabase/functions/push-send/index.ts`
- Create: `supabase/functions/push-send/fcm.ts`
- Create: `supabase/functions/push-send/fcm_test.ts`

**Interfaces:**
- Consumes: `push_outbox`, `device.push_token`, `pair.a/b` (Task 1); secrets `PUSH_HOOK_SECRET`, `FCM_SERVICE_ACCOUNT`.
- Produces (in `fcm.ts`): `type Kind = 'matched' | 'liked' | 'message'`; `messageFor(kind: Kind, otherId: string | null): { notification: { title: string; body: string }; data: Record<string, string> }`; `accessToken(serviceAccount: { client_email: string; private_key: string }): Promise<string>` (cached module-level until 5 min before expiry); `send(projectId: string, token: string, msg: ReturnType<typeof messageFor>, bearer: string): Promise<'sent' | 'unregistered' | 'error'>`.

- [ ] **Step 1: Write the failing test** `fcm_test.ts`

```ts
import { assertEquals } from "jsr:@std/assert@1";
import { messageFor } from "./fcm.ts";

Deno.test("copy is fixed and the liker stays hidden", () => {
  assertEquals(messageFor("liked", "x"), { notification: { title: "Someone likes you", body: "A new like is waiting in Likes You." }, data: { kind: "liked" } });
  assertEquals(messageFor("message", "acc-1").data, { kind: "message", account_id: "acc-1" });
  assertEquals(messageFor("matched", "acc-1").notification.title, "It's a match");
  assertEquals(messageFor("matched", "acc-1").notification.body, "Someone you crossed paths with likes you back.");
  assertEquals(messageFor("message", "acc-1").notification, { title: "New message", body: "Someone you matched with wrote to you." });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd supabase/functions && deno test push-send/fcm_test.ts`
Expected: FAIL, module `./fcm.ts` not found

- [ ] **Step 3: Write `fcm.ts`**

`messageFor` as specified. `accessToken`: build a JWT (`alg RS256`, claims `iss = client_email`, `scope = https://www.googleapis.com/auth/firebase.messaging`, `aud = https://oauth2.googleapis.com/token`, `iat`, `exp = iat + 3600`), import the PEM with `crypto.subtle.importKey('pkcs8', …, {name:'RSASSA-PKCS1-v1_5', hash:'SHA-256'}, false, ['sign'])`, POST `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=…` to the token endpoint, cache `{token, expiresAt}`. `send`: POST `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send` with `{ message: { token, notification, data, android: { priority: 'high' }, apns: { payload: { aps: { sound: 'default' } } } } }`; `404` or an error body containing `UNREGISTERED` → `'unregistered'`; other non-2xx → `'error'`.

- [ ] **Step 4: Run the test**

Run: `cd supabase/functions && deno test push-send/fcm_test.ts`
Expected: PASS

- [ ] **Step 5: Write `index.ts`**

Follow `photo-finalize/index.ts` (`reply`, env reads, `Deno.serve`). `POST` only; `x-push-secret !== Deno.env.get("PUSH_HOOK_SECRET")` → 401 `{error:'unauthenticated'}`; body `{id: number}` else 400. Admin client: `push_outbox` row by id (404 `unknown_row`; `sent_at` set → 200 `{outcome:'already'}`); `device` rows `id, push_token` for the recipient with token not null; when `pair_id` is set, `pair` row `a, b` → `otherId = a === recipient ? b : a`; `otherId` is passed only for `matched` and `message`. No device → update `result = 'no_device'`, `sent_at = now()`, 200. Otherwise `accessToken(JSON.parse(FCM_SERVICE_ACCOUNT))`, send to every token (`Promise.all`), clear `push_token` where `'unregistered'`, `result = sent:<count of 'sent'>` or `fcm_error:<n>` when none sent and at least one `'error'`; `sent_at = now()`; 200 `{outcome: result}`.

- [ ] **Step 6: Type-check**

Run: `cd supabase/functions && deno check push-send/index.ts`
Expected: no errors

- [ ] **Step 7: Commit**

```bash
git add supabase/functions/push-send
git commit -m "feat(backend): push-send edge function (FCM HTTP v1)"
```

---

### Task 3: Three notification flags in the app

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `lib/data/repositories.dart:191-200` (SettingsRepository)
- Modify: `lib/data/mock/mock_repositories.dart:225-265` (MockSettingsRepository)
- Modify: `lib/data/supabase/profile_repository.dart` (`SupabaseSettingsRepository.setNotifications`, `savePreferences` upsert, `hydrate`)
- Modify: `lib/features/profile/settings_notifier.dart:36-39`
- Modify: `lib/features/profile/sheets/notifications_sheet.dart`
- Modify: `lib/features/profile/profile_page.dart:155`
- Modify: `test/features/profile_safety_test.dart:72-84`
- Test: `test/features/notifications_test.dart` (new)

**Interfaces:**
- Produces: `enum NotifyKind { matches, likes, messages }` in `settings.dart`; `Settings({... this.notifyMatches = true, this.notifyLikes = true, this.notifyMessages = true})` with `bool get anyNotify`; `bool Settings.notify(NotifyKind kind)`; `SettingsRepository.setNotify(NotifyKind kind, bool value)` (replaces `setNotifications`); `SettingsNotifier.setNotify(NotifyKind kind, bool value)`; mock keys `rast.notify.matches`, `rast.notify.likes`, `rast.notify.messages`; `preferences` columns `notify_matches`, `notify_likes`, `notify_messages`.

- [ ] **Step 1: Write the failing tests** in `test/features/notifications_test.dart`

```dart
test('each flag persists and reloads', () async {
  final c = await testContainer();
  c.read(settingsProvider.notifier).setNotify(NotifyKind.likes, false);
  expect(c.read(settingsProvider).notifyLikes, isFalse);
  expect(c.read(settingsProvider).notifyMatches, isTrue);
  expect(c.read(settingsProvider).anyNotify, isTrue);
  final again = await testContainer(prefs: {'rast.notify.likes': false, 'rast.notify.messages': false, 'rast.notify.matches': false});
  expect(again.read(settingsProvider).anyNotify, isFalse);
});

testWidgets('the sheet shows three toggles and the row reads Off when all are off', (tester) async {
  final c = await testContainer();
  makeActiveMember(c);
  await pumpRast(tester, c, initialLocation: '/profile');
  await tester.ensureVisible(find.text('Notifications'));
  await tester.tap(find.text('Notifications'));
  await tester.pumpAndSettle();
  expect(find.text('New matches'), findsOneWidget);
  expect(find.text('Likes'), findsOneWidget);
  expect(find.text('Messages'), findsOneWidget);
  for (final s in find.byType(RastSwitch).evaluate().toList()) { await tester.tap(find.byWidget(s.widget)); await tester.pumpAndSettle(); }
  expect(c.read(settingsProvider).anyNotify, isFalse);
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
  expect(find.text('Off'), findsOneWidget);
});
```

Delete the old `notifications sheet toggles the preference` test from `profile_safety_test.dart` (the new file replaces it).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/notifications_test.dart`
Expected: compile error, `NotifyKind` undefined

- [ ] **Step 3: Implement**

`settings.dart`: replace `notifications` with the three fields, `copyWith`, `anyNotify`, `notify(kind)`. `repositories.dart`: `Future<void> setNotify(NotifyKind kind, bool value);`. Mock: `static const notifyKeys = {NotifyKind.matches: 'rast.notify.matches', …}`; `load()` reads each with `?? true`; `clear()` removes them (drop `notificationsKey`). Supabase repo: `setNotify` → `await cache.setNotify(kind, value); await _prefs({_column(kind): value});` with `_column` → `'notify_matches'` etc.; `savePreferences` upsert adds the three columns from `settings`; `hydrate()` adds `await settings.setNotify(k, prefs[column] as bool)` for the three. Notifier: `void setNotify(NotifyKind kind, bool value)`. Sheet: body `Hear about new matches, likes and messages.`, three `ToggleRow`s (`New matches` / `Someone you crossed paths with likes you back.`, `Likes` / `A new like is waiting for you.`, `Messages` / `A match wrote to you.`), `SizedBox(height: Space.m)` between (check `Space` for the 12 or 16 px step the other sheets use). Profile row: `settings.anyNotify ? 'On' : 'Off'`.

- [ ] **Step 4: Run analyzer and the suite**

Run: `flutter analyze && flutter test`
Expected: 0 issues; all pass (the screenshot test still renders the sheet)

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(app): three notification flags, stored on the server"
```

---

### Task 4: PushRepository, Firebase wiring, token registration

**Files:**
- Modify: `pubspec.yaml` (`flutter pub add firebase_core firebase_messaging`)
- Modify: `lib/data/repositories.dart` (append `PushTap`, `PushRepository`)
- Modify: `lib/data/mock/mock_repositories.dart` (append `MockPushRepository`)
- Modify: `lib/data/supabase/location_repository.dart:73-82` (extract `ensureDeviceId`)
- Create: `lib/data/supabase/push_repository.dart`
- Create: `lib/data/supabase/firebase_config.dart`
- Modify: `lib/app/providers.dart` (`pushRepositoryProvider`)
- Modify: `lib/app/bootstrap.dart` (`supabaseOverrides`)
- Create: `firebase.env.json` (four keys, empty strings until the owner fills them)
- Create: `test/helpers/fake_push.dart`
- Test: `test/live/push_test.dart` (new)

**Interfaces:**
- Produces: `class PushTap { final String kind; final String? accountId; }`; `abstract class PushRepository { Future<bool> requestPermission(); Stream<String> tokens(); Future<void> register(String token); Future<void> unregister(); Stream<PushTap> taps(); }`; `Future<String> ensureDeviceId(SupabaseClient client, PreferencesStore store)` top-level in `location_repository.dart`; `class FirebaseConfig { static const apiKey = String.fromEnvironment('RAST_FCM_API_KEY'); … appId, senderId, projectId; static bool get present; static FirebaseOptions get options; }`; `final pushRepositoryProvider = Provider<PushRepository>((ref) => MockPushRepository());`; `class FakePush implements PushRepository { final tokenController = StreamController<String>.broadcast(); final tapController = StreamController<PushTap>.broadcast(); final registered = <String>[]; int permissionRequests = 0; bool unregistered = false; }`.

- [ ] **Step 1: Add the packages**

Run: `flutter pub add firebase_core firebase_messaging`
Expected: pubspec updated, `flutter pub get` succeeds. Check `android/app/build.gradle.kts` `minSdk`; firebase_messaging needs 21+ (the lab's location build is already higher).

- [ ] **Step 2: Interfaces and the mock**

`PushTap`, `PushRepository` in `repositories.dart` after `LocationRepository`. `MockPushRepository`: permission `true`, `tokens()`/`taps()` → `const Stream.empty()`, `register`/`unregister` no-ops. `pushRepositoryProvider` in `providers.dart`. `FakePush` in `test/helpers/fake_push.dart`: `requestPermission` increments and returns `permitted` (default true), `tokens()` → `tokenController.stream`, `register` appends, `unregister` sets the flag, `taps()` → `tapController.stream`.

- [ ] **Step 3: Extract `ensureDeviceId`**

Move the body of `SupabaseLocationRepository.deviceId()` into top-level `Future<String> ensureDeviceId(SupabaseClient client, PreferencesStore store)` in the same file; `deviceId()` becomes `=> ensureDeviceId(client, store)`. Keep the `deviceKey` constant and the `AuthException('not signed in')`.

- [ ] **Step 4: `firebase_config.dart` and `push_repository.dart`**

`FirebaseConfig.present` = all four non-empty; `options` = `FirebaseOptions(apiKey:, appId:, messagingSenderId:, projectId:)`. `SupabasePushRepository(this.client, this.store)`: `requestPermission()` → `(await FirebaseMessaging.instance.requestPermission()).authorizationStatus` is `authorized` or `provisional`; `tokens()` → `async*` yields `await getToken()` when non-null then `yield* onTokenRefresh`; `register(token)` → `client.from('device').update({'push_token': token}).eq('id', await ensureDeviceId(client, store))`; `unregister()` → clear the column the same way (ignore errors when signed out), then `FirebaseMessaging.instance.deleteToken()`; `taps()` → `async*`: `getInitialMessage()` first, then `yield* onMessageOpenedApp`, mapping `RemoteMessage.data['kind']` / `data['account_id']` into `PushTap`, skipping messages without `kind`.

- [ ] **Step 5: Bootstrap**

In `supabaseOverrides`, before the return: `if (FirebaseConfig.present) { await Firebase.initializeApp(options: FirebaseConfig.options); overrides push = SupabasePushRepository(client, store); }`. Add the override to the returned list only in that branch. `firebase.env.json`: `{"RAST_FCM_API_KEY": "", "RAST_FCM_APP_ID": "", "RAST_FCM_SENDER_ID": "", "RAST_FCM_PROJECT_ID": ""}`. In `README.md`'s run instructions, document `flutter run --dart-define=RAST_BACKEND=supabase --dart-define-from-file=firebase.env.json`.

- [ ] **Step 6: Live test** `test/live/push_test.dart`

Same shape as `test/live/location_test.dart`: skip unless `live`; `ensureDeviceId` → update `push_token = 'live-test'` → select it back equals; set it to null; update `preferences` `notify_likes = false` → read back false → restore true.

- [ ] **Step 7: Verify**

Run: `flutter analyze && flutter test && flutter build apk --debug --dart-define=RAST_BACKEND=supabase`
Expected: 0 issues; tests pass; the APK builds without Firebase config (the mock push stays).

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib test firebase.env.json README.md
git commit -m "feat(app): push repository on firebase_messaging, token on the device row"
```

---

### Task 5: PushService — permission, registration, taps, log-out

**Files:**
- Create: `lib/features/push/push_service.dart`
- Modify: `lib/app/app.dart:57` (`ref.watch(pushProvider);` next to `locationProvider`)
- Modify: `lib/features/auth/session_notifier.dart:106-118` (`logOut`)
- Test: `test/features/push_service_test.dart` (new)

**Interfaces:**
- Consumes: `PushRepository` (Task 4), `sessionProvider` (`SessionPhase.active`), `routerProvider`.
- Produces: `final pushProvider = NotifierProvider<PushService, bool>(PushService.new)` where the state is "registered at least once this session"; `static String pathFor(PushTap tap)` → `/chats/<accountId>` for `message` with an id, `/chats` for `matched` or a `message` without id, `/likes` for `liked`, `/discover` otherwise.

- [ ] **Step 1: Write the failing tests**

```dart
Future<(ProviderContainer, FakePush)> running({bool active = true}) async {
  final fake = FakePush();
  final c = await testContainer(extra: [pushRepositoryProvider.overrideWithValue(fake)]);
  if (active) makeActiveMember(c);
  c.listen(pushProvider, (_, _) {});
  await tick();
  return (c, fake);
}

test('an active member registers the first and every refreshed token', () async {
  final (c, fake) = await running();
  expect(fake.permissionRequests, 1);
  fake.tokenController.add('t1');
  fake.tokenController.add('t2');
  await tick();
  expect(fake.registered, ['t1', 't2']);
  expect(c.read(pushProvider), isTrue);
});

test('nothing happens while signed out', () async {
  final (_, fake) = await running(active: false);
  expect(fake.permissionRequests, 0);
});

test('a tap routes by kind', () async {
  final (c, fake) = await running();
  fake.tapController.add(const PushTap(kind: 'message', accountId: 'p-9'));
  await tick();
  expect(c.read(routerProvider).state.uri.path, '/chats/p-9');
  fake.tapController.add(const PushTap(kind: 'liked'));
  await tick();
  expect(c.read(routerProvider).state.uri.path, '/likes');
});

test('log out unregisters before the session ends', () async {
  final (c, fake) = await running();
  await c.read(sessionProvider.notifier).logOut();
  expect(fake.unregistered, isTrue);
});
```

`pathFor` gets one plain `test` with the four cases.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/push_service_test.dart`
Expected: compile error, `pushProvider` undefined

- [ ] **Step 3: Implement `PushService`**

Pattern of `LocationService`: `build()` watches `sessionProvider.select((s) => s.phase == SessionPhase.active)`; when active, `_start()` (once per build): `await repo.requestPermission()`; if false return; subscribe `repo.tokens()` → `await repo.register(token); state = true;` (swallow and log nothing on error, the next token retries); subscribe `repo.taps()` → `ref.read(routerProvider).go(pathFor(tap))`. `ref.onDispose` cancels both subscriptions. Return `false`. `logOut()`: insert `try { await ref.read(pushRepositoryProvider).unregister(); } catch (_) {}` before `authRepositoryProvider.signOut()`.

- [ ] **Step 4: Verify**

Run: `flutter analyze && flutter test`
Expected: 0 issues; all pass

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(app): push service registers tokens and routes taps"
```

---

### Task 6: Deploy, owner setup, device run, docs

**Files:**
- Modify: `docs/superpowers/plans/decision-log.md` (new dated entry)
- Modify: `README.md` (feature list line 83 mentions the three toggles; run command with `--dart-define-from-file`)

- [ ] **Step 1: Apply 0020 and deploy `push-send`** to project `tmgpzujqdninoavcalto` (MCP `apply_migration` with the file's content, `deploy_edge_function` with `index.ts` + `fcm.ts`). Confirm `select extname from pg_extension where extname = 'pg_net'` returns a row; if not, enable it in the dashboard (Database › Extensions) and re-run the `do` block from 0020.

- [ ] **Step 2: Secrets.** Generate `PUSH_HOOK_SECRET` (`openssl rand -hex 32`), set it as an edge function secret and `insert into app.push_hook (url, secret) values ('https://tmgpzujqdninoavcalto.supabase.co/functions/v1/push-send', '<secret>')`. The owner supplies the Firebase service account JSON → secret `FCM_SERVICE_ACCOUNT`, and the four client values → `firebase.env.json`.

- [ ] **Step 3: Smoke.** `curl -X POST .../push-send -H 'x-push-secret: wrong' -d '{"id":1}'` → 401. Insert an outbox row by hand for the owner's account (after the phone registered a token) → `result = 'sent:1'` and the notification on the locked Pixel 9a.

- [ ] **Step 4: Device run** per the spec: like, match, message from the Nothing Phone; each toggle off stops its kind (`push_outbox` shows no row). Record results in the decision log.

- [ ] **Step 5: Docs and commit**

```bash
git add README.md docs/superpowers/plans/decision-log.md firebase.env.json
git commit -m "docs: push notifications live; owner setup recorded"
```
