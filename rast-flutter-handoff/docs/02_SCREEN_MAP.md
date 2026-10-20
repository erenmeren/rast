# rast — screen and Flutter route map

## Reading this map

Version 6: `de646b9263e4c6d31dea0c0aa76d946da775ab88`. Source: [prototype/dist/app.js](../prototype/dist/app.js): `SCREENS`, `screenMarkup`, `sheetContent`, routing/actions. Quotes preserve English copy; adapt line breaks. Flutter routes/widgets are **proposals**. Source paths are ZIP-root relative.

Use a persistent shell: **Discover, Likes You, Chats, Profile**, with nested stacks. Onboarding, required introduction and matching cover it. Account/intro/safety guards protect direct routes. Desktop studio, gallery, autofill and Reset preview are development-only.

## The 16 main screens

| Prototype key | Proposed route / widget | Current copy, actions and behavior |
|---|---|---|
| `welcome` | `/welcome` · `WelcomePage` | “Good things happen nearby.”; “Let's get you out there”; “Already here? Log in”. Both enter phone verification. Terms and Privacy information open sheets. |
| `phone` | `/auth/phone` · `PhoneEntryPage` | “Your number. Your way in.”; Send code. Validate country code/number; “Your number is never shown on your profile.” Demo country list is limited. |
| `otp` | `/auth/verify` · `VerifyPhonePage` | “Check your messages.”; Verify, Change number, Send again. One six-digit input supports paste/autofill. Invalid code remains on screen; production needs expiry and resend timing. |
| `basics` | `/setup/about` · `AboutYouPage` | “A little about you.”; Your age, Your gender, optional Show my gender on my profile. Continue validates adult integer age, explicit gender and required self-description text. |
| `preferences` | `/setup/preferences` · `PreferencesPage` | “Your kind of connection.”; “Who would you like to meet?” Multi-select interests, one Age range with two handles. Continue requires an interest selection. |
| `photos` | `/setup/photos` · `PhotoSetupPage` | “Four photos. All you.”; “Your first photo leads the way.” Four numbered slots with add/change/remove; Continue disabled until four exist. Show count and image validation errors. |
| `permission` | `/setup/location` · `LocationPermissionPage` | “Out there. Closer than ever.”; Enable location / Not now. Explain background location and delayed reveal. Either choice finishes validated setup and starts the required introduction. |
| `discover` | `/discover` · `DiscoverPage` | “Discover”; “Real-life crossings. A fresh mix.” Album indicators and edge taps, Like, Pass, Rewind, profile detail/menu, encounter explanation and settings status. Use a stable shuffled deck. |
| `how` | `/how-it-works` · `HowItWorksPage` | “How a hello happens.” Required: “Watch once. Then make your next move.” and Watch to continue → Start exploring. Optional: Pause/Play, Replay, chapters, Back to Profile. Same component, guarded modes. |
| `likes` | `/likes` · `LikesYouPage` | “Likes You”; eligible incoming-like count. Free: blurred previews and See who likes you. Premium: “They made the first move. Your turn.” Tap a profile to like back or pass. |
| `premium` | `/plus` · `PremiumPage` | “Less guessing. More connecting.”; month/year choices, Get rast Plus, Restore purchases. Return to Likes You after entitlement. Example prices and demo no-charge notes belong only in the prototype. |
| `match` | `/matches/:matchId` · `MatchPage` | “It's a match.”; “You crossed paths. You both said yes.” Say hello opens its conversation; Keep exploring returns to Discover. Reject removed/unavailable pairs instead of recreating a thread. |
| `chats` | `/chats` · `ChatsPage` | “Keep a good thing going.” All messages / Unread, Your connections strip and message rows. Counts, badges and previews exclude unavailable pairs. A row opens the exact conversation. |
| `conversation` | `/chats/:threadId` · `ConversationPage` | “Small world. Good timing.”; composer “Say something good...”. Back to Chats; person menu for removal/report/block. Trim empty messages; current limit is 1,000 characters. Invalid thread returns to Chats. |
| `profile` | `/profile` · `ProfilePage` | “Your profile”; age, optional gender, visibility, four photo thumbnails. Edit, Dating preferences, Location & visibility, Appearance, How it works, Notifications, Safety & account and rast Plus. |
| `settings` | `/profile/location` · `LocationSettingsPage` | “You set the pace.” Location update target, When should you appear?, Open to encounters and Location access. Eight interval/delay choices; 30 seconds and 2 hours default. Pausing retains existing chats. |

## Supporting routes outside the 16-screen gallery inventory

| Prototype key | Proposed route / widget | Behavior |
|---|---|---|
| `detail` | `/people/:personId` · `PersonDetailPage` | Album controls; “A real-life crossing. A new possibility.”; Like profile/Like back, Pass for now, Report or block profile. Preserve originating Discover/Likes route. Recheck eligibility and entitlement; show “This profile is unavailable.” without substituting another person. |
| `editPhotos` | `/profile/photos` · `EditPhotosPage` | Four-slot editor; Save photos. Incomplete edits pause discovery. Handle cancelled selection, decode/upload failure and pending replacement without changing the wrong slot. |
| `safety` | `/profile/safety` · `SafetyAccountPage` | “Your boundaries matter.” Removed connections, Blocked profiles, Privacy information, Terms, Pause visibility, Log out, Delete account. End Premium preview appears only in the demo's active Premium state. |

## Modal sheets and dialogs

All `sheetContent` cases follow. Use phone sheets or larger-display dialogs. Preserve focus/drafts; confirm destructive actions.

| Prototype sheet | Proposed widget; exact title | Contents and transitions |
|---|---|---|
| `filters` | `PreferencesSheet` · “Your kind of connection.” | Shared interests/range editor; Save preferences commits a draft. Dismiss leaves saved settings intact. |
| `how` | `EncounterSummarySheet` · “Real-life crossings.” | Compact proximity, longer delay and two-like explanation; Got it. Legacy defined sheet; current explanation buttons launch the animated page. It is not another tab. |
| `person-menu` | `PersonActionsSheet` · age + “· Crossed paths” | Remove connection when matched; Report profile; Block profile. Preserve the selected person's ID across nested sheets. |
| `report` | `ReportSheet` · “What would you like to report?” | Five reasons, optional details, optional Also block checkbox. Complete report disabled without reason. Matched checkbox says “Also block and permanently remove this connection.” |
| `block-confirm` | `BlockConfirmation` · “Block this profile?” | Block profile / Cancel. Explain permanent connection removal for matched people; explain reversible blocking otherwise. |
| `unmatch-confirm` | `RemoveConnectionConfirmation` · “Remove this connection?” | Remove connection / Keep connection. Copy promises no future Discover/Likes visibility or matching; reporting remains possible from Removed connections. |
| `appearance` | `AppearanceSheet` · “Your kind of light.” | System, Light, Dark previews; Done. “System follows your device. Your choice applies across the app.” |
| `location` | `LocationAccessSheet` · “Let your paths cross.” | Explain precise/background access. Enable location or Turn location off. Native grant/denial and device-settings recovery require actual platform handling. |
| `notifications` | `NotificationsSheet` · “When something clicks.” | Matches & messages switch; Done. No exact location/time in notifications. Keep app preference separate from OS permission. |
| `privacy` | `PrivacyInformationSheet` · “Privacy comes first.” | Essential data, location privacy and prototype persistence disclosures; Got it. Replace demo disclosures with accurate production practices. |
| `terms` | `TermsSheet` · “A good place to start.” | Adults, respectful behavior and mutual choice; Got it. Prototype text explicitly is not a published service agreement. |
| `blocked` | `BlockedProfilesSheet` · “Blocked profiles” | List or “You have not blocked any profiles.” Unblock removes the block only; permanent disconnection still applies. |
| `removed` | `RemovedConnectionsSheet` · “Removed connections” | Permanent exclusions, Report buttons and saved-report state. Empty: “No removed connections.” No restore or rematch action. |
| `delete` | `DeleteAccountConfirmation` · “Delete your account?” | Delete demo account / Keep account. Current demo clears local state; production deletion needs server lifecycle and truthful completion states. |
| `demo` | `DemoHelpSheet` · “Take it for a spin.” | Prototype explanation, sample fill, Back to the app. Development/reference-only; omit from the production member interface. |

The build says **“no real report is sent”** and does not store optional details. Flutter mocks must retain equivalent disclosure.

## Introduction timeline and navigation guards

Reference `prototype/dist/how-it-works.js`, `HOW_STEPS` and `mountHowStory`. Chapters begin at 0, 6.2, 10.6, 16.4 and 21.2 seconds; total playback is 27.4 seconds.

| Chapter | Preserve this heading | What must be explained |
|---|---|---|
| Cross paths | “Life brings you a little closer.” | Centre distance reaches at most 20 m; generic people, no real tracking. |
| Both fit | “The connection goes both ways.” | Both people's age/gender preferences must fit. |
| Give it time | “A little space. A little time.” | Illustrated 1h versus 2h means both wait 2h; clock explicitly fast-forwarded. |
| Discover | “Now, a familiar stranger.” | First profile reveal after the wait; exact location/time stays private. |
| Say hello | “Two likes. One new beginning.” | Two distinct likes precede the chat. |

Required viewing blocks navigation, seeking and Back until completion. Exclude background/offscreen time; preserve pause. Reduced motion uses timed static chapters. Optional Profile replay retains navigation/chapter controls; native completion is account-scoped.

## State coverage for the Flutter implementation

**Already represented:** invalid phone/OTP/adult age/image, missing gender/interests/photos, disabled actions, unavailable profile/thread, empty/locked Likes You, unread chat filter, paused visibility and location-off discovery. Discover empty headings: “Your photos come first.”, “Taking a little breather.”, “Let your paths cross.”, “You're all caught up.” Chats: “It starts with a hello.” Likes: “A little spark is out there.” Distinguish causes without exposing unrevealed people.

**Native additions to design and implement:** initial loading/skeletons; retryable network failures; offline/auth-expired routes; expired OTP and rate-limited resend; pending/failed photo uploads; approximate-only, denied, permanently denied or revoked location; stale/uncertain readings; notification permission denial; purchase pending/cancelled/failed/restored; message sending/failed/retry; report/removal request failure and server confirmation. These are required implementation states, not screens already functioning in the static prototype.

Offline/pending safety actions keep the person locally excluded without claiming remote completion. Remote removal invalidates cards, details, likes, match CTAs, composers and notification destinations. Return routes to a safe parent or explicit unavailable state. Browser persistence is not native synchronization.
