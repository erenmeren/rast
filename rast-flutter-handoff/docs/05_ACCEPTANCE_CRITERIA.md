# Acceptance criteria for the Flutter implementation

These are implementation targets, not a claim that a Flutter app has already passed them. Existing JavaScript checks under `prototype/checks/` are useful behavioral references. Production-only checks need two authenticated accounts and the chosen backend; use injected clocks and reproducible fixtures for domain rules.

## 1. Identity and setup

| ID | Scenario | Expected result |
| --- | --- | --- |
| AUTH-01 | New signup begins | No gender is preselected; own age and gender must be entered. No name, job, religion or biography field is required. |
| AUTH-02 | Wrong, expired or previously used OTP | Access is rejected with a recoverable state; a real server/provider validates the code. |
| AUTH-03 | OTP resend or verification is retried | Rate limits, resend timing and duplicate responses are handled; the same request cannot create duplicate accounts. Provider settings are selected during implementation. |
| AGE-01 | Enter 17, a fractional age or malformed input | Setup cannot complete; provide a clear English error. |
| AGE-02 | Enter 18 | Age gate accepts. Production age assurance remains a separately implemented policy, not a claim proved by typed age. |
| AGE-03 | Display an adult aged 99 or above | Display 99+. A maximum filter set to 99 includes older adults. Do not replace the source's actual age with a string in age calculations. |
| PREF-01 | Select Everyone | All supported identities, including self-description, are eligible subject to reciprocal preferences. No category is inferred from a self-description string. |
| PREF-02 | Select several interest categories | Preserve the selections and require at least one; match both directions. |
| PREF-03 | Adjust age limits | Use one range track with two accessible handles, keep minimum <= maximum, and apply sheet edits only on Save. Cancel discards the draft. |
| PHOTO-01 | Only three photos are present | Discovery is unavailable; explain the missing photo. Four valid uploads enable the next step. |
| PHOTO-02 | An upload completes after deletion, logout or account switching | Do not attach it to a stale slot/account. Failed upload is retryable. Production removes location EXIF before serving user media. |
| PHOTO-03 | A completed profile loses one of its four photos | Pause new discovery eligibility until the four-photo requirement is restored. |

Keep the existing age input upper sanity bound (130) as a prototype detail until the production age model is explicitly decided. The agreed 99+ value is a display/filter convention, not approval to collect unnecessary additional identity data.

## 2. Required introduction

| ID | Scenario | Expected result |
| --- | --- | --- |
| INTRO-01 | Setup completes with either location choice | Open the five-scene introduction before entering the app. Deferring location must not bypass it. |
| INTRO-02 | Introduction is still playing | Pause/resume works. Start exploring is disabled. App navigation, back gestures and deep links do not skip the gate. |
| INTRO-03 | App is backgrounded or the story is no longer visible | Do not count hidden time as watched time. Resume from valid progress or restart according to the documented policy. |
| INTRO-04 | Process is killed before completion | The pending account remains gated at next launch; source behavior restarts the story. |
| INTRO-05 | All five scenes are actually completed | Mark completion for the authenticated account. Start exploring works; later login and relaunch do not require another watch. |
| INTRO-06 | Reduced motion or large text is enabled | Provide static/reduced-motion scenes and equivalent content without bypassing the required first viewing. Controls remain readable and usable. |
| INTRO-07 | Open Profile → How it works later | Optional replay has playback/chapter controls and a return to Profile. Main navigation remains four tabs. |
| INTRO-08 | Inspect crossing/reveal scenes | The geometry represents centre distance <=20 m. Both preferences and the longer delay appear before a recognizable profile. Show two separate likes before chat. |

## 3. Crossing, delay and discovery

| ID | Scenario | Expected result |
| --- | --- | --- |
| RULE-01 | Valid distance is exactly 20 m | The distance boundary passes, subject to every other gate. |
| RULE-02 | Distance is 20.001 m, 40 m, negative or invalid | The encounter is not eligible. |
| RULE-03 | Two 20 m circles overlap but users are 35 m apart | No eligible crossing. |
| RULE-04 | Either user is underage, hidden, blocked, disconnected or outside the other's filters | No candidate on either side. |
| RULE-05 | Location is stale, inaccurate or not sufficiently contemporaneous | Do not create a confirmed encounter. Implement the explicitly chosen evidence policy; do not hard-code the demo's accurate=true. |
| DELAY-01 | A chooses Instant and B chooses 2 h | Neither appears until 2 h have elapsed. |
| DELAY-02 | A chooses 1 day and B chooses 1 h | Neither appears until 24 h have elapsed. At 23:59:59.999 it is still unavailable. |
| DELAY-03 | Both choose Instant | The delay gate can pass immediately, with all other gates still active. |
| DELAY-04 | Test every combination of the eight delay values | Effective delay equals the larger value. Invalid values do not silently make profiles appear earlier; source fallback is 2 h. |
| DELAY-05 | Client clock is manually advanced | The server's reveal decision is unchanged. |
| DELAY-06 | A user changes delay while an encounter is pending | Follow a documented monotonic/snapshot policy selected in implementation; record the decision and test it. The prototype recomputes from its current preference. |
| FEED-01 | Several eligible crossings have different timestamps | Display a randomized order independent of timestamps. |
| FEED-02 | Change photo, rebuild widgets, navigate away/back or open a sheet | Preserve the current deck's relative order; do not reshuffle on each build. A photo tap changes only the current album frame. |
| FEED-03 | Load the next page, retry it or reconnect | No duplicate profiles, missing cursor boundary or chronological fallback. Persist or regenerate session ordering according to the explicit policy. |
| FEED-04 | A current card becomes unavailable remotely | Clear its actions/photo and show a suitable empty or unavailable state. Do not silently substitute another person's detail. |
| FEED-05 | Swipe and tap photo edges | Swipes like/pass; photo taps change the album. A drag must not also trigger an accidental photo tap. |
| FEED-06 | Rewind after a pass | Restore only an eligible, available previous profile. Rewind never revives a removed connection. |
| FEED-07 | No candidates, permission denied or location service off | Render the correct distinct state and a meaningful recovery action; do not invent nearby profiles. |

Show no encounter timestamp, exact distance, personal countdown or precise location in profile cards, chat, notifications or feed response fields intended for the client. Message timestamps are a separate feature and may remain.

## 4. Likes and entitlements

| ID | Scenario | Expected result |
| --- | --- | --- |
| LIKE-01 | An incoming like is eligible but the user is free | Display only the intended protected preview and subscription entry. |
| LIKE-02 | Inspect the free client network/cache | No unauthorized original photo URLs or profile detail payload are delivered solely to be blurred locally. Use a server-approved derivative or an equivalent protected presentation. |
| LIKE-03 | A person has not passed the privacy delay | Do not reveal them through an identifiable blurred preview, personal countdown, stale badge or Premium. |
| LIKE-04 | Both accounts like each other without Premium | A unique active match is created and chat is available. |
| SUB-01 | Purchase/restore completes | Server-verified entitlement controls access. Client-only flags cannot unlock protected media. |
| SUB-02 | Subscription expires or is refunded | Protected like details close appropriately; existing valid matches and free chats remain available. |
| SUB-03 | Premium user tries to access a removed, blocked or otherwise ineligible profile | Access remains denied. |
| SUB-04 | Subscription screen is shown | Product names and localized prices come from the chosen store flow; web demo prices are not release pricing. |

## 5. Chat, removal, blocks and reports

| ID | Scenario | Expected result |
| --- | --- | --- |
| CHAT-01 | Open a valid match, send, retry or reconnect | Messages belong to the correct thread and account; idempotency avoids duplicates. Handle sending, failed, offline and incoming states. |
| SAFE-01 | Cancel Remove connection confirmation | The connection and conversation remain. |
| SAFE-02 | Confirm Remove connection | Remove the match, conversation, card, incoming like and actionable notifications for both accounts. Persist a pair-level permanent removal. |
| SAFE-03 | Like, match-create and message-send race with removal | The authoritative transaction rejects or invalidates subsequent access. Neither account can recreate the pair. |
| SAFE-04 | Reopen an old route, notification, cached card or message form | Show unavailable; no send or match side effect occurs. Never fall back to an unrelated profile. |
| SAFE-05 | Restart, sign out/in or use a second device | The same account pair remains removed. Client reset does not erase the server decision. |
| SAFE-06 | Block an existing match, then unblock it | Block state may clear, but permanent connection removal remains; no rematch. |
| SAFE-07 | Block an unmatched profile, then unblock it | Reversible blocking may permit future eligibility if all rules pass. Do not implicitly restore an old match. |
| SAFE-08 | Report with “also block” unchecked | Submit the report and preserve the existing connection unless another authoritative action changes it. |
| SAFE-09 | Report an existing connection with “also block” checked | Submit the report, block the profile and permanently remove that connection. |
| SAFE-10 | Report someone after removal | A report action remains available from Removed connections, using only the limited information the production policy permits. |
| SAFE-11 | Submission fails | Do not claim that a real report was delivered. Allow a safe retry with idempotency. |
| SAFE-12 | Older events arrive after newer remove/unblock state | Apply versions monotonically and fetch current state where necessary. Old events cannot resurrect the pair or undo an explicit newer change. |
| SAFE-13 | A local persistence write fails | Keep the removal pending in the current session and visible as such; reconnect must retry against the server. Do not restore the profile after the next unrelated action. |
| SAFE-14 | Account is deleted and later recreated | Implement the explicitly agreed identity/retention policy. The “never rematch” guarantee must state its account-pair scope; do not promise identity-wide enforcement without such a policy. |

Reporting, moderation retention and account deletion need real server workflows. A deletion from the user's chat list is not proof that every backend record or moderation record is physically erased.

## 6. Theme, accessibility and native devices

Verify all screens and sheets in System/Light/Dark. The explicit choice survives relaunch; System follows OS changes while an explicit Light/Dark preference stays fixed. Cover photo overlays, disabled buttons, selected chips, unread badges, warning text, the composer and the whole story illustration.

Use small-phone and large-phone layouts, keyboard open/closed, display cutouts, Android gesture navigation, text scaling and screen-reader focus. Do not copy the desktop phone shell or fake 9:41 status bar into the native app. Inspect the user's real photo and font assets, not only placeholder rectangles.

Test the actual target phones while stationary, walking, indoors, backgrounded, battery-saving, network-disconnected and after permission changes. Measure delivered sample cadence, timestamp skew, accuracy and battery cost at the available interval targets. OS-restricted delivery must produce an honest state, not a claim that a periodic Dart timer is still collecting exact positions.

## 7. Evidence required before marking a phase complete

Record the source revision, SDK/package versions, platforms and devices used, commands run, pass/fail counts, screenshots for visual parity when available, and any unresolved result. Separate mock UI coverage, backend integration coverage and native-device evidence.

Do not convert this checklist into hundreds of superficial snapshot tests. Use focused domain tests for boundaries, widget tests for critical controls, two-user integration tests for authoritative access and permanent removal, and direct device measurements for location behavior.

