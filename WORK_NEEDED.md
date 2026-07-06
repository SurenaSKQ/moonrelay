<!--
Part of Moonrelay, a matrix protocol client.
Copyright (C) 2025 Surena Karimpour Ghannadi

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# WORK_NEEDED

Open work ledger for Moonrelay. Each item is anchored to a file:line or
file path.

**Tests at head:** `flutter test` → passes · `flutter analyze` → no errors.

Status key: 🟠 correctness · 🟡 performance · 🔵 refactor · 🟢 feature
· 🟣 quality · 🔴 security.

---

## 1. Open bugs & refactors

Nothing currently 🔴 or 🟠 blocks the Alpha. Remaining items are 🟡, 🔵,
or 🟣 — polish, not showstoppers.

### 1.1 Skeleton loading — boot transitions still start empty

- **Hub-screen → accounts list:** `lib/src/screens/hub_screen/accounts_page.dart`
  first-paints empty until the future completes. Should render a
  `LoadingScreen` placeholder while `accountManager.accounts` loads.
- **Login → hub navigation:** redirect chain briefly flashes an empty
  hub before first sync. Splash (`lib/src/splash_screen.dart`) shows a
  spinner but should stay visible until the hub has at least one room
  cached.

### 1.2 Future-aware surface comments

- **`TimelineView` count notifier:** `_UndecryptableBanner` reads from a
  `ValueNotifier<int>` via `findAncestorStateOfType`. Add a comment
  near the notifier noting that any future restructuring needs to keep
  it on the same `State`.
- **In-room search jump accuracy:** `ChatTimeline.jumpToEvent` estimates
  scroll from a fraction. Add a comment that users can scroll a few
  items up/down after a jump.

### 1.3 Refactor candidates

| Area | Issue |
|------|-------|
| HTML rendering | `MarkdownToHtml` & `_HtmlTagParser` each implement their own tag allow-list. Extract a single `SanitizedHtml` helper. |
| Color palette | `MoonrelayColorPalette` mixes raw swatches with `StringColor` wrappers. Either pull in or delete. |
| Provider wiring | `boot.dart` injects `clientFactory`/`onClientReady`; `app.dart` re-wraps in `Provider.value`. Consolidate into a `MoonrelayScope` widget. |
| Scattered widgets | 60+ `_buildXxx` private classes. Move into `lib/src/widgets/` for reuse. |
| Cache invalidation | `EncryptionService._cachedUnverified` reset lives in `_onSync`. Extract `markDirty()`. |

---

## 2. Open features

### 2.1 Communication surface

- **Recovery-key save dialog (post-bootstrap):** `bootstrap_screen.dart`
  shows a reminder that the SDK encrypts the key — but cannot display
  it. Action buttons: "I saved it" / "Later". Strings in `app_en.arb`.
- **Per-room encryption badge in `RoomsPane`:** wire `EncryptionBadge`.
- **"Rotate megolm session"** in room details.
- **"Export E2EE keys"** in encryption overview.

### 2.2 Timeline / chat

- **Reply expand / collapse:** `chat_event.dart` renders replies inline;
  no affordance for a thread-mode view.
- **Mention vs highlight distinction in room list:** use
  `Room.highlightCount` for a separate badge.
- **Sticker sender label:** treated identically to images in the
  timeline header.
- **Push notifications:** `NotificationService` is local-only; OS push
  bridge not wired.
- **Off-thread Markdown:** `MarkdownToHtml.convert` runs on the UI
  thread. Move to `compute()`.

### 2.3 Right-sidebar expansion

Four views today (`roomInfo / members / threads / pinned`). Search,
member management, settings, and avatar uploads stay full-page routes.
Decide whether the sidebar should grow or be replaced with context menus.

### 2.4 Room management

- **Knock-accept confirmation dialog:** show display name + Matrix ID +
  "View profile" link.
- **In-room search result highlights:** visual chip on matching terms.

---

## 3. Features shipped (July 2026 audit pass)

### 3.1 Messaging & chat

| Feature | Files |
|---------|-------|
| Message edit (`m.replace`) send + indicator + history viewer | `edit_message_dialog.dart`, `edit_history_dialog.dart`, `_EditedMarker` in `chat_event.dart` |
| Audio in-app player | `audio_message_type.dart` (scrub slider, save button) |
| Video inline playback | `video_message_type.dart` (height-constrained, tap-to-play, fullscreen) |
| Image/GIF height-constrain | `image_message_type.dart` (`BoxFit.contain` for panoramics) |
| Voice-note recorder | `voice_recorder_dialog.dart` (mic button in composer toolbar) |
| Location messages | `share_location_dialog.dart`, `location_message_type.dart` (open-in-maps) |
| Polls (MSC3381) | `poll_send_dialog.dart`, `poll_message_type.dart` |
| Typing notifications | `typing_indicator.dart` (animated footer, auto-stop after 4s) |
| Per-message read receipts | `receipt_avatars.dart` (up to 5 avatars + "+N") |
| Slash commands | `/me` → `m.emote`, `/shrug`, unknown → snackbar |

### 3.2 Rooms / users / spaces

| Feature | Files |
|---------|-------|
| Room version display + upgrade | `room_settings_page.dart:_upgradeRoom` |
| Knock approve/deny UI | `_KnockRequestsSection` in room settings |
| Room editor tiles | join rule, history visibility, encryption, alias, guest access, power levels |
| Own-profile editor | display name, status message, presence (hub `my_profile_page.dart`) |
| DM pane dedup | `LeftPaneChoice.friends` uses `RoomsPane(roomFilter: isDirectChat)` |

### 3.3 Platform support

- Permissions wired: `record` (mic), `geolocator` (location) via `permission_handler`
- Cleanup: `friend_chats_pane.dart` & `own_user_profile.dart` deleted

### 3.4 Desktop-service hardening (audit-driven)

All findings from the July 2026 audit pass in `WORK.md` were verified.
The following were already resolved in the source at audit time:

| # | Area | Fix |
|---|------|-----|
| 1 | Notification init failures | `_initPlugin` returns `bool`; `isAvailable` flag; no silent dead service |
| 2 | `eventId.hashCode` collision | String tags (`matrix:$roomId:$eventId`) on every platform |
| 3 | Tray temp-dir crash | `_setup` catches, clears `_instance`, `isAvailable` gate |
| 4 | `showTestNotification` throw | Returns `false` instead of `StateError` when plugin is null |
| 5 | Persist-on-every-sync-tick | 750ms debounce timer |
| 7 | Notification tap ignores payload | Reads `response.payload`, routes via `_navigate` / `_deepLinkService` |
| 8 | Encrypted event body leak | `"(encrypted message)"` placeholder, handles `EventTypes.Encrypted` |
| 9 | Tray ignores muted rooms | Uses `NotificationService.mutedRoomsSnapshot` + `highlightCount` |
| 10 | Temp file leak | `_iconFile` tracked, deleted in `quit()` and on `_setup` failure |
| 11 | DeepLink navigation duplication | Listener calls `navigateToMatrixUri` (single code path) |
| 12 | processUri no dedup | `_isDuplicate` with 500ms window |
| 13 | `@visibleForTesting` suppress | Documented trade-off; silent fallback is intentional |
| 15 | Stale Tray Client on switch | Re-binds via `AccountManager` listener |
| 16 | Unbounded event-id cache | LRU with `_notifiedIdsCacheLimit = 256` |
| 17 | Linux plugin missing | `InitializationSettings` covers all platforms natively |
| 26 | Method channel TypeError | `call.arguments is String` guard |
| 27 | SSO any-path accepted | `request.uri.path != '/callback'` 404 check |
| 30 | boot.dart silent short-circuit | `log.w` when `activeAccount` exists but `sdk.isLogged()` is false |

### 3.5 Test coverage added

| File | Coverage |
|------|----------|
| `test/unit/notification_service_test.dart` | muted-room persistence; last-event-id; group counts; DM/group logic; sender skip; body-empty skip; current-room skip; no-op when plugin null; first-time baseline |
| `test/unit/tray_service_test.dart` | singleton lifecycle; `isDesktop` gate; quit disposes; show/hide/toggle; tooltip format (`Moonrelay` / `Moonrelay (N)`); only writes on change |

---

## 4. Future work

Expected timeline: 2026 and beyond.

- **Custom events (events v3)**: Git events, Map events, Realtime audio/video chat
- **Application fundamentals v2**: Background process optimisation, Tighter system integration

---

## 5. Wishlist

Extremely long-term; listed here to keep the design flexible.

- Server SDK v1 — server-side Matrix SDK.
- Client SDK v1 — alternative chat protocols. (Forked `matrix-dart-sdk` from Famedly.)

---

## FIXED

Archive of items resolved in earlier passes. Listed bottom-to-top so the most recent fixes are at the bottom of each group.

### July 2026 audit pass (from WORK.md)

The 31 findings in `WORK.md` were verified against the current source:

- **30 bug/correctness items** — already resolved in code at audit time
- **1 item fixed in this pass** — #30 (boot.dart silent short-circuit): `log.w` added
- **0 items remain open**

See [§ 3.4](#34-desktop-service-hardening-audit-driven) above for the fix table.

### Chat timeline & chat box

- **🟠 Reply sending dropped markdown.** Fixed: `chat_box.dart:_send` builds relation payload once.
- **🟠 Clear input before send-result known.** Fixed: draft captured before `controller.clear()`; restored on throw.
- **🟠 `?threadRoot=` ignored.** Fixed: `room_page.dart:129` forwards `threadRootEventId`.
- **🟠 `_UndecryptableBanner` count frozen.** Fixed: `ValueNotifier<int>` updated every visible-items build and `didUpdateWidget`.

### Encryption surface

- **🟠 SSSS prompt falls to spinner.** Fixed: dedicated icon, copy, `canceledReason`, Cancel button.
- **🟠 Recovery key disclosure.** Fixed (best-effort): done state shows reminder + ack/later buttons.
- **🟠 Three network calls per sync.** Fixed: coalesced into single in-flight `Future`; 750ms debounce.
- **🟠 Bootstrap finish ignored.** Fixed: `onBootstrapFinished()` resets refresh and triggers full refresh.
- **🟠 Placeholder backup numbers.** Fixed: surfaces `{exists, cached, algorithm}`.
- **🟠 `isUserVerifiedById` comment drift.** Fixed: reads `mk.verified`.
- **🟠 Post-login setup raced first refresh.** Fixed: `_check()` awaits `enc.init()`, waits for one sync + 900ms delay.

### Markdown / HTML

- **🟢 `_processBoldItalic` greedy-forward scan.** Fixed: per-character state machine.
- **🟢 `href` attribute XSS.** Fixed `_escapeAttribute` + `_isSafeHref`. Pinned by `test/unit/markdown_round_trip_test.dart`.

### Settings / persistence

- **🟠 Comma / pipe separator split.** Fixed: `_readCommaSet`, `_readCommaList`, `_readSpaceGroups` use `jsonDecode` with legacy fallback.

### Matrix URI

- **🟠 Trailing punctuation matched.** Fixed: trailing lookbehind + bare-ID branch only accepts `@…:…` / `#…:…`.

### Rooms / avatar UX

- **🟠 `_buildAvatar` throws on whitespace.** Fixed: `_initialsForDisplayname` splits, filters, uses `characters.firstOrNull`; falls back to `untitledRoom`.

### Login / auth

- **🔴 Plaintext password leakage via login error.** Fixed: `_safeErrorMessage` maps `TimeoutException` to static copy, never touches `MatrixHttpException.toString()`. Log redaction covers `password=…`, `"password":"…"`, `password: …`.
- **🔴 SSO redirect URL unvalidated.** Fixed: `isPlausibleHomeserverUrl` + confirmation dialog. Pinned by `test/unit/login_security_test.dart`.
- **🟠 SSO callback hangs on error.** Fixed: every error branch completes the future with an exception and returns 4xx HTML.

### Boot / persistence

- **🟠 `DatabaseService` swallowed wipe failures.** Fixed: re-throws as `StateError`.
- **🟠 `SplashScreen.updateStatus` never wired.** Fixed: `_boot` forwards every status callback.
- **🟠 `AccountManager.switchToAccount` race.** Fixed: new pair built and persisted first, old pair disposed on microtask.

### Caching / perf

- **🟡 `_HtmlParseCache` keyed on `hashCode`.** Fixed: keys are `${baseFontSize}::$formattedBody`.
- **🟡 `RoomsPane._buildAvatar` re-creates FutureBuilder.** Fixed: `cachedThumbnail` with 256-entry LRU.
- **🟡 `_StringColor._colorCache` unbounded.** Fixed: bounded at 512; oldest evicted.

### Search

- **🟠 In-room search tap didn't jump.** Fixed: `onJumpToEvent` → panel-close + `_timelineKey.jumpToEvent(id)`.

### Misc

- **🟢 Tomorrow, today.** Moonrelay still doesn't have time travel.

---

*See `WORK.md` for the July 2026 audit ledger. This file tracks the alpha backlog + shipped features.*
