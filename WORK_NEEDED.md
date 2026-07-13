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

### 1.1 Skeleton loading — login → hub navigation still flashes empty

- **Login → hub navigation:** redirect chain briefly flashes an empty
  hub before first sync. Splash (`lib/src/splash_screen.dart`) shows
  a spinner but should stay visible until the hub has at least one
  room cached.

The accounts-page skeleton (`lib/src/screens/hub_screen/accounts_page.dart`,
`_buildLoading(theme)` placeholder while `Future<Profile>` is in
flight) is already in place and no longer needs work.

### 1.2 Future-aware surface comments

- **`TimelineView` count notifier:** `_UndecryptableBanner` reads from a
  `ValueNotifier<int>` via a static late reference
  (`lib/src/chat/timeline_view.dart:118`). Add a comment near the
  notifier noting that any future restructuring needs to keep it on the
  same `State`.
- **In-room search jump accuracy:** `ChatTimeline.jumpToEvent`
  (`lib/src/chat/chat_timeline.dart:1134`) estimates scroll from a
  fraction. Add a comment that users can scroll a few items up/down
  after a jump.

### 1.3 Refactor candidates

| Area | Issue |
|------|-------|
| HTML rendering | `MarkdownToHtml` & `_HtmlTagParser` each implement their own tag allow-list. Extract a single `SanitizedHtml` helper. |
| Color palette | `MoonrelayColorPalette` mixes raw swatches with `StringColor` wrappers. Either pull in or delete. |
| Provider wiring | `boot.dart` injects `clientFactory`/`onClientReady`; `app.dart` re-wraps in `Provider.value`. Consolidate into a `MoonrelayScope` widget. |
| Scattered widgets | 60+ `_buildXxx` private classes. Move into `lib/src/widgets/` for reuse. |
| Encryption cache invalidation | `EncryptionService._cachedUnverified` (`lib/src/encryption/encryption_service.dart:738`) is only cleared on `onLogout`; never invalidated on sync. `EncryptionService._userVerifiedCache` / `_deviceVerifiedCache` (lines 79/82) are declared but never read or invalidated — they are dead state. Extract a `markDirty()` API and have `_onSync` call it for both `_cachedUnverified` and the verified caches. |

---

## 2. Open features

### 2.1 Communication surface

- **Recovery-key save dialog (post-bootstrap):** `bootstrap_screen.dart`
  shows a reminder that the SDK encrypts the key  but cannot display
  it. Action buttons: "I saved it" / "Later". Strings in `app_en.arb`.

The following previously-tracked surface items have shipped:

- Per-room encryption badge in `RoomsPane` — wired at
  `lib/src/widgets/rooms_pane.dart:576` (RoomEncryptionBadge).
- "Rotate megolm session" — wired at `lib/src/screens/room_details_page.dart:107`,
  backed by `EncryptionService.rotateMegolmSession`
  (`lib/src/encryption/encryption_service.dart:148`).
- "Export E2EE keys" — wired at
  `lib/src/screens/encryption/encryption_overview.dart:375`, backed by
  the SSSS export path and confirmed via dialog
  (`encryptionExportKeysConfirm`).

### 2.2 Timeline / chat

- **Reply expand / collapse:** `chat_event.dart` renders replies inline;
  no affordance for a thread-mode view.
- **Sticker sender label:** sticker messages are routed through
  `StickerMessageType` (`lib/src/chat/chat_event.dart:222 / 244`) and
  rendered with the same sender-name treatment as images. Differentiate
  the label (e.g. "Sent a sticker:") in
  `lib/src/chat/timeline_item_sender_name_and_timestamp.dart`.
- **Push notifications:** `NotificationService` is local-only; OS push
  bridge not wired.

The following previously-tracked timeline items have shipped:

- Mention vs highlight distinction in room list — `_RoomUnreadBadges`
  (`lib/src/widgets/rooms_pane.dart:457`) keys off
  `Room.highlightCount` first and falls back to
  `Room.notificationCount`.
- Off-thread Markdown — `MarkdownToHtml.convertAsync`
  (`lib/src/helpers/markdown_to_html.dart:55`) runs the parser on a
  background isolate via `compute()`; the chat-box send path awaits the
  async variant.

### 2.3 Right-sidebar expansion

Four views today (`roomInfo / members / threads / pinned`). Search,
member management, settings, and avatar uploads stay full-page routes.
Decide whether the sidebar should grow or be replaced with context menus.

### 2.4 Room management

The following previously-tracked room-management items have shipped:

- **Knock-accept confirmation dialog:** `_approve` in
  `lib/src/screens/room_settings_page.dart:1666` shows display name +
  Matrix ID + "View profile" link before calling the underlying
  approve API.
- **In-room search result highlights:** `_HighlightedText` +
  `_MatchCountChip` in `lib/src/chat/in_room_search_panel.dart:690`
  highlight matching terms in result tiles and surface a match count
  pill next to the sender name.

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
| Slash commands | `/me` → `m.emote`, `/shrug`, unknown → snackbar (`chat_box.dart:_send`) |
| Delivery indicator on outgoing messages | `lib/src/chat/events/delivery_indicator.dart` consumed in `lib/src/chat/timeline_item.dart:251` |

### 3.2 Rooms / users / spaces

| Feature | Files |
|---------|-------|
| Room version display + upgrade | `room_settings_page.dart:_upgradeRoom` |
| Knock approve/deny UI with confirmation dialog | `_KnockRequestsSection` in room settings; `_approve` at `room_settings_page.dart:1666` |
| Room editor tiles | join rule, history visibility, encryption, alias, guest access, power levels |
| Own-profile editor | display name, status message, presence (hub `my_profile_page.dart`) |
| DM pane dedup | `LeftPaneChoice.friends` uses `RoomsPane(roomFilter: isDirectChat)` |
| Per-room encryption badge in rooms list | `encryption_badge.dart` consumed in `rooms_pane.dart:576` |
| Highlight-vs-unread badge split | `_RoomUnreadBadges` in `rooms_pane.dart:457` |
| Rotate megolm session from room details | `room_details_page.dart:107`, `encryption_service.dart:148` |
| Export E2EE keys from encryption overview | `encryption_overview.dart:375` |

### 3.3 Platform support

- Permissions wired: `record` (mic), `geolocator` (location) via `permission_handler`
- Cleanup: `friend_chats_pane.dart` & `own_user_profile.dart` deleted
- Global keyboard shortcuts mounted: `Ctrl+K` (command palette),
  `Ctrl+Shift+K` (global search), `?` (cheat-sheet overlay) via
  `GlobalShortcutListener` (`dashboard_layout.dart:260`,
  `global_shortcut_listener.dart:34`)
- Per-room notification preferences sheet
  (`showRoomNotificationSheet`) reachable from room details
  (`room_details_page.dart:1294`) and room settings
  (`room_settings_page.dart:29`)

---

## 4. Future work

Expected timeline: 2026 and beyond.

- **Custom events (events v3)**: Git events, Map events, Realtime audio/video chat
- **Application fundamentals v2**: Background process optimisation, Tighter system integration

---

## 5. Wishlist

Extremely long-term; listed here to keep the design flexible.

- Server SDK v1  server-side Matrix SDK.
- Client SDK v1  alternative chat protocols. (Forked `matrix-dart-sdk` from Famedly.)

---

*See `WORK_DONE.md` for the closed-work ledger covering the July 2026
audit pass and the August 2026 performance/memory follow-up. This file
tracks the alpha backlog + shipped features.*
