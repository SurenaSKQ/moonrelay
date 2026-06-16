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

# Current work

Expected timeline: ~~Mid 2026 (This will eventually become a lesson in wishful thinking)~~ lmao, it sure did

## Chat events v1
- Chat timeline needs rework.
- Text Messages **[DONE]**
- Images **[DONE]**
  - Still needs some work — dedicated image view screen needed
- Audio **[DONE]**
  - No in-app player yet
- Video **[NOT STARTED]**
- Files **[DONE]**
  - Widget needs polish

## Chat events v2
- Dynamically built text with inline images
- Code blocks support
- Right-click context menu
- Replies **[IN PROGRESS]**
- Threads **[INVESTIGATION NEEDED]**
- Stickers **[INVESTIGATION NEEDED]**

## Application fundamentals v1
- Settings controller and service integration **[DONE]**
- More configurable UI values **[IN PROGRESS]**
- Full integration with internationalisation (particularly embarrassing for a non-English project) **[IN PROGRESS]**
- State management rework **[IN PROGRESS]**

## UI revamp v1
- Overall dynamic scaling and scaling fixes
- Chat screen rework v1 **[DONE]**
  - New text entry **[DONE]**
  - New user profiles page **[DONE]**
  - New server profile design **[DONE]**
- Rework settings **[DONE]**
  - Reworked into a hub page
- Rework sidebar **[IN PROGRESS]**
  - The right sidebar is useless and the sidebar settings needs rework.

## Login & Registration Flow
- Support third-party sign-in **[DONE]**
  - Proper SSO support is done
- Support registration **[DONE]**
  - Untested!!!

## UI revamp v2
- New UI framework **[in progress]**
  - Custom sidebar widget **[DONE]**
  - Custom frame widget **[DONE]**
    - Well, we use a dynamic layout widget to build the dashboard dynamically now
  - Custom input widget
  - Custom header v2 **[DONE]**
  - ~~Custom scaffold~~ No longer a good idea

## Branding & Identity
- Welcome screen settings page **[DONE]**
- Credits / developer information screen **[DONE]**
- Supporters card with links **[DONE]**
- Logo replaced with vector icon + text **[DONE]**
- Project monicker: Moonrelay (Alpha)

---

# Future work

Expected timeline: 2026 and beyond

- Custom events (events v3)
  - Git events
  - Map events
  - Realtime audio and video chat
- Application fundamentals v2
  - Optimise for background processes
  - Tighter system integration

# Wishlist

Extremely long-term wishlist that may or may not come to fruition; only
introduced here to remain flexible in the face of the inescapable temporal
burden we carry.

- Server SDK v1
  - Server-side SDK for Matrix protocol
- Client SDK v1
  - Potentially explore new chat protocols as time moves onwards; XMPP was
    once here and now it is no more
  - Who can truly proclaim to know where Matrix will go, especially with the
    strong disdain certain communities show towards the Matrix protocol.
  - I have forked matrix-dart-sdk from Famedly; just in case

# Bad Design

This category captures underlying work needed to fix accumulated design debt.

- FutureBuilders **[DONE]**
- New Chat Timeline **[DONE]**
- Skeletonised loading
  - Better UX
  - Without proper loading animations, the app shows a blank screen on Linux until loaded
  - There is currently a long delay when logging in
- Own blur widget **[DONE]**
- Potential global key issue? **[DONE]**
- Use layout building instead of static layout widgets **[DONE]**
- FIXME Handle cases where user profile response is invalid! **[DONE, I THINK?]**
- FIXME List tiles are not adaptive, causing an exception when the list tile becomes smaller than the title widget **[DONE]**
  - Ended up changing the entire infra behind this to fix it lmao


---

## I had DeepSeek generate a list of missing features, please feast thine eyes:

## Comprehensive Feature Gap Analysis — Moonrelay vs. Full Matrix Client

I analyzed every file in your codebase and cross-referenced it against the `matrix-dart-sdk` v7.2.3 API surface. Below is everything that's either missing, incomplete, or known-broken.

---

### 🧵 Messaging & Content Types

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | **Stickers** (`m.sticker`) | ❌ Missing | `EventTypes.Sticker` exists in SDK, not handled in `MessageEventHandler` |
| 2 | **Emotes** (`m.emote`) | 🔶 Partial | `MessageTypes.Emote` matched in switch but falls through to same renderer as text — no `/me` styling |
| 3 | **Notices** (`m.notice`) | 🔶 Partial | `MessageTypes.Notice` matched but rendered same as plain text; should be styled differently (e.g. muted) |
| 4 | **Location messages** (`m.location`) | ❌ Missing | `Room.sendLocation()` exists in SDK, no send or render support in app |
| 5 | **Video playback** (in-app) | ❌ Missing | `VideoMessageType` only shows download button — no video player |
| 6 | **Audio playback** (in-app) | ❌ Missing | `AudioMessageType` only shows download button — no audio player |
| 7 | **Image viewer (dedicated)** | 🔶 Partial | Fullscreen via dialog `_openFullscreen` works but minimal — no pinch-to-zoom toolbar, no swipe between images, no save/share |
| 8 | **File preview** | 🔶 Partial | `FileAttachedMessage` is very bare — tiny icon + filename, poor UX |
| 9 | **Code block rendering** | ❌ Missing | `FormattedTextWidget` has `_HtmlTagParser` but no `<pre><code>` syntax highlighting |
| 10 | **Inline images in text** | ❌ Missing | Matrix supports `img` tags in `formatted_body` — not rendered by `_HtmlTagParser` |
| 11 | **Reply fallback stripping** | ✅ Done | `_stripReplyHtml` works, but no UI for *sending* rich replies with formatted body |

---

### 🔗 Event Relationships (Replies, Edits, Threads)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 12 | **Replies (receiving)** | ✅ Done | Renders reply preview via `_ReplyPreview` with jump-to-event |
| 13 | **Replies (sending)** | ❌ Missing | `ChatBox` has `replyTarget` ValueNotifier but the actual send path in `sendFn` doesn't include the `m.relates_to` with `m.in_reply_to` — reply preview is shown but reply relationship not sent |
| 14 | **Message edits (receiving)** | ❌ Missing | `RelationshipTypes.edit` (`m.replace`) is filtered out by `relationshipEventId != null` check in `_visibleIndices()`, but the replacement logic (replace original event with edit) is not implemented |
| 15 | **Message edits (sending)** | ❌ Missing | No edit UI (long-press → edit, or edit button in message actions) |
| 16 | **Threads (receiving)** | ❌ Missing | `RelationshipTypes.thread` (`m.thread`) events are filtered out — no thread panel or thread-summary UI |
| 17 | **Threads (sending)** | ❌ Missing | `Room.sendTextEvent()` has `threadRootEventId`/`threadLastEventId` params — not used in `ChatBox` |
| 18 | **Threads root event detection** | ❌ Missing | Events that *are* thread roots should show a reply count / thread summary chip |

---

### 👤 User & Room Management

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 19 | **User search / directory** | ❌ Missing | `Client.searchUser()` exists in SDK — no UI for finding users |
| 20 | **Room directory / explorer** | ❌ Missing | No public room browser — `Client.getPublicRooms()` exists |
| 21 | **Room creation with options** | 🔶 Partial | `CreateNewRoom` calls `client.createRoom()` with zero options — no way to set name, topic, visibility, preset, invites |
| 22 | **Room invite flow** | ❌ Missing | No way to invite users from the UI (`Room.invite()` exists in SDK) |
| 23 | **Room kick/ban UI** | 🔶 Partial | `Room.kick()`, `Room.ban()`, `Room.unban()` exist in the members view context menu — need to verify they work end-to-end |
| 24 | **Power level management** | ❌ Missing | `Room.setPower()` exists in SDK, but no UI for changing roles (Admin/Moderator) |
| 25 | **Room aliases management** | ❌ Missing | `Room.setCanonicalAlias()` exists — no UI to set aliases |
| 26 | **Room tags (favorites, low priority)** | ❌ Missing | `Room.setFavourite()`, `Room.setLowPriority()` exist — no UI |
| 27 | **Leave room** | 🔶 Partial | `_leaveRoom` exists in `RoomInformations` — verify it works |
| 28 | **Forget room** | ❌ Missing | After leaving, no "forget" option to remove from room list |
| 29 | **Room upgrade / tombstone handling** | ❌ Missing | `m.room.tombstone` state event is rendered but no follow-redirect to the new room |
| 30 | **Knocking support** | ❌ Missing | `Membership.knock` state event is rendered (`stateKnocked`) but no way to knock on restricted rooms |

---

### 🏠 Spaces

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 31 | **Space creation** | ❌ Missing | No UI to create a space (SDK rooms can be created with `RoomCreationTypes.mSpace`) |
| 32 | **Space child management** | ❌ Missing | `Room.setSpaceChild()` exists — no UI to add/remove rooms from a space |
| 33 | **Space hierarchy / tree view** | ❌ Missing | Spaces are a flat list in the nav pane — no nested/expandable tree showing sub-spaces and their rooms |
| 34 | **Space home / landing page** | ❌ Missing | Selecting a space shows nothing useful — should show space info, members, recent activity |
| 35 | **Suggested rooms in space** | ❌ Missing | Space children can have `suggested` flag — not used |

---

### 🔐 Encryption

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 36 | **E2EE (core)** | ✅ Done | Uses `flutter_vodozemac`, cross-signing bootstrapping, device management |
| 37 | **Key backup (server-side)** | 🔶 Partial | `_refreshBackupState` and `isKeyBackupEnabled` exist — but no UI to configure/restore from backup |
| 38 | **Recovery key management** | 🔶 Partial | `_keyBackupHasRecoveryKey` tracked — no UI to export/reveal recovery key |
| 39 | **Device verification (SAS/QR)** | 🔶 Partial | `VerificationScreen` exists — needs testing with actual device verification flows |
| 40 | **Incoming verification requests** | 🔶 Partial | `IncomingVerificationListener` widget exists — need to verify it works end-to-end |
| 41 | **Post-login setup checker** | ✅ Done | `PostLoginSetupChecker` guides user through bootstrap |
| 42 | **Undecryptable messages (key request)** | 🔶 Partial | Banner shown, but `can_request_session` button action is missing — user can't request decryption keys for undecryptable messages |
| 43 | **Device deletion** | ✅ Done | `EncryptionService.deleteDevice()` exists |
| 44 | **User trust / verification status (visual)** | ✅ Done | Trust indicator shown in timeline |
| 45 | **Encryption settings in room** | 🔶 Partial | Room details shows encryption info — no way to enable/disable per-room (though this is typically set at creation) |

---

### 📡 Presence & Read Receipts

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 46 | **Read receipts / markers** | ❌ Missing | `Room.setTyping()` exists but `setReadMarker()` / `sendReadReceipt()` is never called — the app doesn't mark messages as read |
| 47 | **Read status in room list** | ❌ Missing | No visual indicator of read/unread per-room (e.g. read marker position) |
| 48 | **Typing indicators (displaying)** | ❌ Missing | `Room.typingUsers` exists in SDK — no "X is typing…" UI |
| 49 | **Typing indicators (sending)** | ❌ Missing | `Room.setTyping(true/false)` never called — app doesn't broadcast typing |
| 50 | **Presence display** | ❌ Missing | `User.presence` exists in SDK — no online/offline/busy indicator anywhere |
| 51 | **Presence settings** | ❌ Missing | No UI to set own presence (`Client.setPresence()`) |
| 52 | **Last seen / active time** | ❌ Missing | `User.lastPresenceTs` exists — not displayed in profiles |

---

### 🔔 Notifications & Push

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 53 | **Push notification rules** | ❌ Missing | SDK has `PushRules` / `tryGetPushRule()` — no UI to view or edit notification preferences |
| 54 | **Local notifications** | ❌ Missing | No `flutter_local_notifications` integration — no push-to-notification bridge |
| 55 | **Notification count display** | 🔶 Partial | Room list shows `notificationCount` badge — but highlight count (mentions) is not distinguished |
| 56 | **Background sync support** | ❌ Missing | No mention in SDK usage of background sync — relevant for mobile platforms |

---

### 🖼️ Content & Media

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 57 | **Content scanning / moderation** | ❌ Missing | `Client.getContentScannerConfig()` exists — no integration for blocked/safe content |
| 58 | **Blurhash placeholders** | ❌ Missing | `blurhash_dart` is in pub cache (likely a transitive dep) — images load without low-res placeholder |
| 59 | **Upload progress indicator** | ❌ Missing | When sending files/images, no upload progress shown in timeline |
| 60 | **Multiple file download** | ❌ Missing | FIXME/TODO in code — can only download one file at a time |
| 61 | **Image gallery view** | ❌ Missing | No grid/album view of all images shared in a room |

---

### 🧹 Room & Timeline Features

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 62 | **Read marker (visual line)** | ❌ Missing | No visual "you read up to here" line in timeline |
| 63 | **Jump to bottom / new messages** | ❌ Missing | No FAB to jump to latest messages when scrolled up |
| 64 | **Message search in room** | ❌ Missing | `Client.search()` exists — no search UI |
| 65 | **Pinned messages** | ❌ Missing | `m.room.pinned_events` state is rendered (one-liner) — no dedicated pinned-messages panel |
| 66 | **Room context menu (right-click)** | ❌ Missing | Listed as v2 in WORK_NEEDED.md — not implemented |
| 67 | **Event details / source view** | ✅ Done | `MessageDetailsPage` is comprehensive |
| 68 | **Message redaction (delete)** | ✅ Done | Works with confirmation dialog |
| 69 | **Reactions** | ✅ Done | Add/toggle reactions works, quick emoji picker |
| 70 | **Redacted event rendering** | ✅ Done | `_RedactedEvent` widget exists |

---

### 🧭 Navigation & UI

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 71 | **Direct message discovery** | ❌ Missing | `Client.directChats` available — `FriendsChatsPane` is still a `Placeholder()` |
| 72 | **Room filtering / sorting** | ❌ Missing | No alphabetical sort, no unread-first, no filtering by name |
| 73 | **Mobile layout** | ❌ Missing | `DashboardLayout` has responsive breakpoints but mobile shell route is commented — no bottom nav, no slide-up panels |
| 74 | **Keyboard shortcuts** | ❌ Missing | Desktop app — no Ctrl+K (quick switcher), Ctrl+Tab (next room), Escape (mark read), etc. |
| 75 | **Welcome / onboarding revamp** | 🔶 Partial | `StartupScreen` exists but is minimal |
| 76 | **Room list avatars (fix)** | ❌ Missing | `// FIXME: Avatar & Badge` in `RoomsPane` — room avatars sometimes broken |
| 77 | **Rich room list preview** | 🔶 Partial | Shows `lastEvent.body` — doesn't handle encrypted events showing as "undecryptable" in preview |

---

### ⚙️ Settings & Configuration

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 78 | **Multi-account support** | ❌ Missing | Single `Client` provider — no account switcher |
| 79 | **Ignore list / user blocking** | ❌ Missing | `Client.ignoreUser()` exists — no UI |
| 80 | **Account data management** | ❌ Missing | No way to view/edit account data (broadcast list, push rules, etc.) |
| 81 | **Homeserver discovery / .well-known** | 🔶 Partial | SSO auto-discovery works — manual HS entry always available |
| 82 | **Language/regional settings** | 🔶 Partial | `supportedLocales` only en — Persian mentioned as TODO |
| 83 | **Theme customization** | ✅ Done | Light/dark/system + accent color + layout options |
| 84 | **Font scaling** | ❌ Missing | `SettingsController` doesn't expose font scale factor |

---

### 🧪 Testing

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 85 | **Unit tests for encryption service** | ❌ Missing | No tests for `EncryptionService` |
| 86 | **Unit tests for chat events** | ❌ Missing | No tests for `MessageEventHandler`, `FormattedTextWidget`, event rendering |
| 87 | **Widget tests for room list** | ❌ Missing | No tests for `RoomsPane`, `SpacesPane`, `NavigationPane` |
| 88 | **Widget tests for chat/timeline** | ❌ Missing | No tests for `ChatTimeline`, `TimelineView`, `ChatBox` |
| 89 | **Integration tests** | ❌ Missing | No end-to-end tests with a mock Matrix server |
| 90 | **Snapshot / golden tests** | ❌ Missing | No visual regression tests |

---

### 📦 Infrastructure & Polish

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 91 | **Skeleton loading / shimmer** | ❌ Missing | Mentioned in WORK_NEEDED.md as "Bad Design" — not implemented |
| 92 | **Error handling for invalid profiles** | 🔶 Partial | FIXME mentions "Handle cases where user profile response is invalid" — may not be fully resolved |
| 93 | **Offline support / cached timelines** | ❌ Missing | Database is set up (`sqflite`) but the app likely can't browse cached messages offline |
| 94 | **Persian / RTL localization** | ❌ Missing | TODO in `app.dart` — only English ARB file exists |
| 95 | **SSO registration** | ❌ Missing | Only password registration flow — no SSO registration |
| 96 | **Dehydrated devices** | ❌ Missing | `Client.enableDehydratedDevices` exists — not used |
| 97 | **OIDC / Matrix Native OIDC** | ❌ Missing | `Client.oidcClientId` is mentioned in SDK — not integrated in login flow |
| 98 | **Session management (list active sessions)** | ❌ Missing | No way to see/terminate other sessions |
| 99 | **Logout cleanup** | 🔶 Partial | `_logout` exists — verify it clears crypto state, database, and uploaded keys |
| 100 | **Accessibility (semantics, screen reader)** | ❌ Missing | No `Semantics` widgets, no accessibility labels on custom widgets |

---

### 🚨 Critical Path to Alpha (Top 10)

If you want to ship an Alpha today, these are the blockers:

1. **Read receipts / markers** — without these, rooms always show as unread
2. **Reply sending** — reply preview UI is done, but the actual reply relationship is never attached to the sent event
3. **Typing indicators** — sending and receiving (small but very noticeable)
4. **Sticker support** — extremely common on Matrix, falls to unsupported
5. **Location messages** — similarly common, rendered as unknown
6. **FriendsChatsPane** — the direct messages pane is still a `Placeholder()`
7. **Room list avatars fix** — the FIXME in `RoomsPane` means many rooms show broken avatars
8. **Undecryptable key request** — banner is shown, but the button to request session keys does nothing
9. **Message search** — users can't find past messages
10. **Skeleton loading** — the app shows a blank screen on cold start on Linux

### 📊 TL;DR Summary

| Category | Total | Done | Partial | Missing |
|----------|-------|------|---------|---------|
| Messaging & Content | 11 | 1 | 6 | 4 |
| Event Relationships | 7 | 1 | 2 | 4 |
| User & Room Management | 12 | 0 | 4 | 8 |
| Spaces | 5 | 0 | 0 | 5 |
| Encryption | 10 | 6 | 4 | 0 |
| Presence & Read Receipts | 7 | 0 | 0 | 7 |
| Notifications | 4 | 0 | 1 | 3 |
| Content & Media | 5 | 0 | 1 | 4 |
| Room & Timeline | 9 | 4 | 1 | 4 |
| Navigation & UI | 7 | 0 | 3 | 4 |
| Settings | 7 | 1 | 2 | 4 |
| Testing | 6 | 0 | 0 | 6 |
| Infrastructure & Polish | 10 | 0 | 3 | 7 |
| **Total** | **100** | **13** | **27** | **60** |

The codebase has solid bones — good architecture, clean separation of concerns, proper state management, and solid encryption support. The gaps are mostly in the Matrix-specific feature surface rather than fundamental design issues. The encryption work in particular is quite thorough. Most missing items are "just" UI work to expose SDK capabilities that already exist.
