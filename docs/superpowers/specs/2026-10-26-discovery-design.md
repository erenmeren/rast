# Discovery, passes and Likes You (Phase 5b) design

Date: 2026-10-26. Builds on the Phase 5a schema (`docs/superpowers/specs/2026-10-25-backend-core-design.md`). The owner asked for Phase 5b to start without a question round, so every choice below is an engineering call, marked as such in the decision log and reversible. Handoff sources: docs/01 "Encounters, privacy and ordering", docs/04 §5 and §7, docs/05 FEED, LIKE and SUB rows.

## Goal

The server side of the Discover deck and the Likes You tab: a scheduled release of due encounters, random but stable deck order with cursor pagination, pass and rewind, the eligible incoming-like set with entitlement-aware presentation, and the photo-access rule that Storage will enforce in the next phase. Plain SQL migrations under `supabase/migrations/`, proven by the existing Python harness.

## Non-goals

- Serving photo bytes: Storage buckets, signed URLs, the blurred derivative and its Edge Function (Phase 5c). This phase only decides *who may see whose photos* (`app.can_view_photos`) and hands out opaque preview tokens.
- Flutter adapters (Phase 5d), Twilio Verify wiring (owner dashboard task, Phase 5c), realtime delivery of `pair_event`.
- An eligibility revision on the session. Every page re-evaluates eligibility, so a revision would only be a cache hint.

## Release schedule

`app.release_due_encounters()` runs every minute under pg_cron (`release-due-encounters`, `* * * * *`), skipped when pg_cron is absent like the purge jobs. Release is therefore at most one minute after `release_at` and never before it (DELAY-02).

## Deck membership

`app.candidate(me, pair)` is true when the pair has a `released` encounter, is not matched, `app.pair_open` holds and `app.eligible_pair(me, other)` holds (which re-checks both setups, so an incomplete profile empties the deck, PHOTO-03). The deck is the candidates minus pairs the caller has liked or passed.

## Discovery sessions and cursor

- `discovery_session(id uuid pk, account_id, seed bigint, created_at, expires_at = created_at + 24 h)`. Clients may select their own rows; writes go through RPCs. One session per account: starting a new one deletes the caller's previous sessions.
- Order key: `app.order_key(seed, pair_id) = hashtextextended(seed::text || pair_id::text, 0)`. It depends on the seed and the pair id only, never on any timestamp (FEED-01), and is stable for the life of the session (FEED-02).
- `public.start_discovery_session() -> {"outcome":"ok","session_id":…}`.
- `public.discovery_cards(session_id uuid, after text default null, page_size int default 20) -> {"outcome":"ok","cards":[…],"next":text|null}` or `{"outcome":"session_expired"}` when the session is unknown, not the caller's or past `expires_at`. Cards are the deck ordered by `(order_key, pair_id)` with `order_key > after`; `page_size` is clamped to 1..50; `next` is the last card's key when more cards exist, else null. Removals never skip anything (the next page starts after the cursor); candidates released after the cursor passed their position appear only when the client starts a new session. This is the "explicit policy" FEED-03 asks for.
- Card: `{"account_id","age","gender"|null,"custom_gender","photos":[storage_path × 4]}`. `gender` is null unless `show_gender`; `custom_gender` is `''` unless `gender = 'self'` and shown. No timestamps, distances or like status. Age is `app.age_on(birth_date, current_date)`.

## Pass and rewind

- `pair_pass(pair_id, from_account, created_at)`, pk `(pair_id, from_account)`, own-row select. A pass is per pair and permanent until rewound; it writes no `pair_event` and no revision bump, the other person never learns of it.
- `public.pass_account(target uuid, client_op_id uuid) -> {"outcome":"passed"|"unavailable"}`: `unavailable` unless the pair is a candidate (same gate as `like_account`). Idempotent: a repeat is `passed`.
- `public.rewind_pass() -> {"outcome":"restored","account_id":…}` or `{"outcome":"unavailable"}`: removes the caller's most recent pass only if that pair is still a candidate; otherwise nothing changes (FEED-06: rewind restores only an available profile and never revives a removed connection). Not entitlement-gated in this phase.

## Likes You

- `app.is_premium(acct)`: an `entitlement` row with `product = 'premium'`, `status = 'active'` and `valid_until` null or in the future.
- Eligible incoming likes for `me`: candidates where the other account has a `pair_like` row and `me` has neither liked nor passed. This set is computed before any entitlement logic (LIKE-03, SUB-03).
- `public.likes_you() -> {"outcome":"ok","premium":bool,"count":n,"cards":[…]}` for premium (full cards, ordered by `hashtextextended(pair_id::text, 0)`), or `{"outcome":"ok","premium":false,"count":n,"previews":[{"token":uuid,"age":int}]}` for free members. The preview carries no identity, no photo path and no per-person timer (LIKE-02). Age is shown because the mock's locked card shows it.
- `like_preview(token uuid pk, viewer, pair_id, created_at, expires_at = + 24 h)`, unique `(viewer, pair_id)`, closed to clients. `likes_you()` upserts a token per eligible like and refreshes `expires_at`. Phase 5c resolves a token to the blurred derivative of the liker's first photo, re-checking eligibility at that moment.

## Photo access

`app.can_view_photos(viewer, owner)` is true when `viewer = owner`; when the pair is matched and open; when `app.candidate(viewer, pair)` holds (deck or Likes You card); or when the viewer is premium and `owner` has an eligible incoming like for `viewer`. Phase 5c attaches it to the Storage policy; this phase proves it in SQL.

## Retention

`app.purge_discovery()` deletes expired `discovery_session` and `like_preview` rows; scheduled daily (`purge-discovery`, `41 3 * * *`).

## Privileges

Every new `app` function gets an explicit `revoke execute … from public, anon, authenticated` (the 0001 default-privilege revoke is a no-op on Supabase, see 0009). Every new function pins `search_path = public, app, extensions`. New public RPCs are `security definer`, revoked from `public, anon`, granted to `authenticated`.

## Scenarios the tests prove

- Release job: a due pending encounter is released by `app.release_due_encounters()`; cron row exists when pg_cron does.
- Deck: three released candidates come back in an order that differs from encounter order for at least one seed and is identical across repeated calls and pages; liked and passed pairs are absent; a block, disconnect, hidden profile or lost photo removes a card on the next page; a foreign or expired session returns `session_expired`; a page of size 2 then `after` yields the third card once and no duplicates; a candidate released after the cursor passed its slot is absent until a new session.
- Pass and rewind: pass hides, rewind restores and the card returns; rewind after the pair was blocked returns `unavailable` and keeps the pass; pass on a pending (unreleased) pair is `unavailable`.
- Likes You: a like from an unreleased pair is not counted; free member gets count + tokens with age and no `account_id`; premium gets cards; expired entitlement behaves as free; a passed liker is excluded; tokens are reused within 24 h.
- Photo access: self, matched, candidate, premium-with-like are true; stranger, blocked, pending-only, free-with-like are false.
- Privileges: `anon` cannot call any new RPC; `authenticated` cannot call any new `app` function; clients cannot read `like_preview`.
