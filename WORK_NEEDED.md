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

Expected timeline: 2026 and beyond — at this point every gap listed below is a known bug or missing wire-up that has already shipped as "done" in earlier revisions of this document. This file should be re-read every few weeks; the previous version was badly out of date.

> Note on terminology used below:
> - **🔴 [Security]** — actual security vulnerability; fix before any public build.
> - **🟠 [Correctness]** — bug or footgun a user will trip over.
> - **🟡 [Perf]** — measured or obvious performance problem.
> - **🔵 [Refactor]** — would meaningfully reduce complexity / duplication.
> - **🟢 [Feature]** — finished work; cite the file/line so it stays closed.

---

## Chat events v1

- Text messages **🟢 [Feature]** — `lib/src/chat/events/message_body.dart`, `formatted_text_widget.dart`, `markdown_to_html.dart`.
- Images **🟢 [Feature]** — `lib/src/chat/events/matrix_events/Message/image/image_message_type.dart`.
  - Dedicated image viewer **🟢 [Feature]** — `lib/src/screens/image_viewer_screen.dart`.
- Audio **🟢 [Feature]** — `lib/src/chat/events/matrix_events/Message/audio/audio_message_type.dart`.
  - In-app audio player **🔵 [Refactor]** — currently the renderer still shows only a download button; an inline MediaKit-backed player would need a new wrapper widget and a small `MediaPlayerService`.
- Video **🟢 [Feature]** — `lib/src/chat/events/matrix_events/Message/video/video_message_type.dart` (downloads + thumbnail).
  - In-app video playback **🔵 [Refactor]** — add a `VideoPlayer`-backed overlay so the viewer screen is one screen, not three.
- Stickers **🟢 [Feature]** — `lib/src/chat/events/matrix_events/Message/sticker/sticker_message_type.dart`.
- Files **🟢 [Feature]** — `lib/src/chat/events/matrix_events/Message/file/file_attached_message.dart`.

## Chat events v2

- Dynamically built text with inline images **🟠 [Correctness]** — `formatted_text_widget.dart:_HtmlTagParser` silently drops `<img>` tags because it only handles a fixed allow-list. Either render `mxc://`/`https://` images via `Image.network` or document the decision.
- Code blocks **🟢 [Feature]** — `markdown_to_html.dart` produces `<pre>` and `formatted_text_widget.dart` styles it (`_wrapBlock` `case 'pre':`).
  - No syntax highlighting **🔵 [Refactor]** — wire `flutter_highlight` and a language hint from the `lang` attribute.
- Right-click context menu **🟢 [Feature]** — `lib/src/chat/message_actions.dart`.
- Replies (receiving) **🟢 [Feature]** — `lib/src/chat/chat_event.dart:_buildReplyContent`, `_ReplyPreview`.
- Replies (sending) **🟢 [Feature]** — `lib/src/chat/chat_box.dart:_send` uses `sendTextEvent(..., inReplyTo: replyTo)`.
  - **🟠 [Correctness]** When the message has markdown, the reply is sent as **plain** `text` only; the `formatted_body` is dropped because the markdown branch lives in the `else` branch. Fix by building the same relation payload in both branches.
- Threads (receiving + sending) **🟢 [Feature]** — `lib/src/screens/thread_view.dart`, `lib/src/helpers/thread_utils.dart`, `lib/src/helpers/threads_provider.dart`. `ChatBox.threadRootEventId` is wired, `timeline_view.dart:_visibleIndices` keeps thread roots visible.
  - **🟠 [Correctness]** `lib/src/screens/room_page.dart:127` instantiates `ChatBox` without `threadRootEventId`, so replying from the main room never lands in a thread even when the user came from a `RoomDelegate` whose route has a `threadRoot` query parameter (no such parameter is read yet — add it).

## Application fundamentals v1

- Settings controller and service integration **🟢 [Feature]** — `lib/src/settings/settings_controller.dart`, `settings_service.dart`.
- More configurable UI values **🟢 [Feature]** — `fontSize`, `uiScale`, sidebar widths, tray behaviour all live in `SettingsController` now.
- Full integration with internationalisation — **🟠 [Correctness]** English-only. `lib/src/app.dart:52` explicitly says `// TODO: Support persian`. Add an `app_fa.arb`, drop it under `lib/src/localization/`, regenerate via `flutter gen-l10n`, and drop the TODO. Most widgets already use `AppLocalizations.of(context)!`, so the wiring is straightforward.
- State management rework **🟢 [Feature]** — Provider-only, no Riverpod/Bloc mixed in.

## UI revamp v1

- Overall dynamic scaling and scaling fixes **🟢 [Feature]**.
- Chat screen rework v1 **🟢 [Feature]**.
  - New text entry **🟢 [Feature]** — `lib/src/chat/chat_box.dart`.
  - New user profiles page **🟢 [Feature]** — `lib/src/screens/user_profile.dart`.
  - New server profile design **🟢 [Feature]** — `lib/src/screens/own_user_profile.dart`.
- Rework settings **🟢 [Feature]** — `lib/src/screens/hub_screen/`.
- Rework sidebar **🟢 [Feature]** — `lib/src/layouts/dashboard_layout.dart`, plus the `NavigationPane` / `RoomsPane` / `SpacesPane` widgets.
  - Right sidebar is still largely stub **🟠 [Correctness]** — `lib/src/screens/hub_screen.dart` plus `_RightSidebarContent` (in `dashboard_layout.dart`) only switch between room info / threads / pinned. Several panels (search, members, settings, etc.) are routed to full pages instead of the sidebar.

## Login & Registration Flow

- Third-party sign-in (SSO) **🟢 [Feature]** — `lib/src/screens/login_page.dart:_doSsoOpenBrowser`, `_doAutomaticSso`. Local callback server in `lib/src/services/sso_server.dart`.
  - **🔴 [Security]** `SsoCallbackServer._handleRequest` validates the `Host` header, but `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` only constrains the **bind address**, not the `Host` header an attacker on the same machine can forge. An attacker on the loopback adapter can call the callback with a forged Host to flood the server; the bigger concern is `state` reuse. The current code does single-use (state is cleared), but the **redirect URI is built from the user-supplied `homeserver` field** (`homeserverUri.replace(path: ...)`). A user that types a hostile URL gets `redirectUrl` pointed at our server. Acceptable, but document the threat model.
  - **🟠 [Correctness]** `_handleRequest` returns a `200` HTML page even on error paths when `_completer` is never completed. The browser tab hangs until the user closes it. Add a small "error" page and complete with `null` to let the login page abort cleanly.
- Registration **🟢 [Feature]** — `lib/src/screens/register_page_inclient.dart`.
  - Still largely untested **🟠 [Correctness]** — see "Tests" below.

## UI revamp v2

- Custom sidebar widget **🟢 [Feature]**.
- Custom frame widget **🟢 [Feature]** — `lib/src/layouts/app_frame.dart`, `dashboard_layout.dart`.
- Custom input widget **🟢 [Feature]** — `lib/src/chat/chat_box.dart`.
- Custom header v2 **🟢 [Feature]** — `lib/src/chat/room_info_card.dart` (room header) and the app-frame header.

## Branding & Identity

- Welcome screen settings page **🟢 [Feature]**.
- Credits / developer information screen **🟢 [Feature]** — `lib/src/screens/licenses.dart`, `about_page.dart`.
- Supporters card with links **🟢 [Feature]**.
- Logo replaced with vector icon + text **🟢 [Feature]** — `lib/src/widgets/logo_with_text_themed.dart`.
- Project monicker: Moonrelay (Alpha).

---

## Bugs and Security findings (highest priority first)

These are issues encountered during the walkthrough that aren't captured elsewhere in this file. Fix them before shipping any "Alpha" build to anyone who isn't the developer.

### 🔴 Security

- **Plaintext password leakage via login error handling.**
  `lib/src/screens/login_page.dart:777` formats the SDK's `MatrixHttpException` with `'$error'`, and `MatrixHttpException.toString()` echoes the request body back, which the homeserver echoes the `password` field in some 4xx/5xx responses (Element web, Synapse, Dendrite have all done this at various times). Worse, every login failure is logged via `_log.e('Login failed after ...', error: error)` — the password ends up in redacted logs (the regex doesn't catch it because `password=...` with `=` is not in the patterns) **and** in the redacted `Bearer` set by `log_service.dart:_RedactingLogOutput`.
  - Stop formatting the raw exception. Map known errors to user-facing copy via a helper that explicitly strips request bodies; only show the error class.
  - Add `password[\"=:]?\\s*([^&\\s]+)` to the redaction list in `log_service.dart`.
- **Custom-scheme hostname validation in `DeepLinkService._processCommandLineArgs` is broken.**
  `lib/src/services/deep_link_service.dart:100-108` looks at `Platform.environment.values` on Windows, never at `Platform.arguments`, so the URI from `matrix:r/...` invocations never reaches `processUri` on Windows. The Linux branch reads `ARGV` (a Linux-only variable) and silently returns an empty list on every other platform. Result: deep links only work on Linux, and only by coincidence.
  - Use `Platform.executableArguments` (added in Flutter 3.3) or a small platform-channel call so the OS-passed argument is read consistently across Windows/Linux/macOS.
- **Matrix ID regex for URI parsing allows trailing punctuation.**
  `lib/src/helpers/matrix_uri_parser.dart:78-83` uses `[^\s<>")()]+` which accepts both leading and trailing junk. A message `Visit matrix.org!` will detect `matrix.org` as a `MatrixUri` because of the bare-ID fallback (line 126 — anything starting with `@`, `!`, or `#`). This produces bogus banners and, worse, can be used to inject a fake room alias that the user then opens.
  - Tighten the regex with a trailing-word-boundary assertion and require the bare form to start with `#` or `@`, not `!`.
- **Cache splitting in `settings_service.dart` ignores IDs that contain commas / pipes.**
  `lib/src/settings/settings_service.dart:204-228` joins pinned spaces, space order, collapsed groups, space-groups map, and last-notified event IDs using `,` and `|` as separators, but room IDs and event IDs (`$…`, `!…`) can legally contain both characters. The rehydration splits on the first occurrence and silently drops entire suffixes.
  - Same bug appears in `notification_service.dart:_persistLastEventIds` and `_persistGroupNotifiedCounts` which join `roomId|eventId` and `roomId|count` and split on the **first** `|`. Room IDs with `|` will collide.
  - Replace with `jsonEncode`/`jsonDecode` into `setString` / `getString` (the values are already `Set<String>` and `Map<String, T>`). The current shared-preferences stringly-typed API has no business being the storage for structured data.
- **SSO redirect URL is not validated.**
  `lib/src/screens/login_page.dart:954-959` builds `ssoUrl` with the user-supplied homeserver. A user can be phished into typing `https://evil.example.com` and the resulting page is shown in their browser. The local callback server only protects against state-forgery, not against the user being redirected to a hostile endpoint after we throw the login token into the void. At minimum, log the homeserver and warn in the UI if it doesn't equal the user's `client.homeserver`.

### 🟠 Correctness

- **`SplashScreen.updateStatus` is never wired.**
  `lib/src/splash_screen.dart:63-65` defines `updateStatus`, but `lib/main.dart:_initialize` only calls `onStatus: (msg) => log.t(msg)` — it never reaches the splash widget. That's why the splash shows `Starting…` forever and the user only sees a blank screen on Linux until the bootstrap completes. Wire `SplashScreen.updateStatus` into `_MoonrelayBootstrapState` (currently `_appState/_errorTitle/_errorBody` are stored on the bootstrap state but never fed into a mounted splash widget).
- **`RoomsPane._buildAvatar` will throw on multi-byte Unicode or empty parts.**
  `lib/src/widgets/rooms_pane.dart:250-255` does `s[0]` after `split(RegExp(' +'))`. If `displayname` starts with whitespace, an element is empty and the `[0]` access throws. `Room.getLocalizedDisplayname()` always returns a non-empty string but a user-renamed space can have leading/trailing whitespace from arbitrary input handling.
  - Use `String.characters.firstOrNull ?? '?'` instead.
- **`MarkdownToHtml._processBoldItalic` mishandles mixed emphasis.**
  `lib/src/helpers/markdown_to_html.dart:244-265` uses a manual scanner that handles `**bold**` then `*italic*`. The italic path's `(i == 0 || text[i - 1] != '*')` rejects nested `**` but **greedy forward scanning** (`text.indexOf('*', i + 1)`) means `*a**b*c*` becomes `<i>a**b*c</i>` and the trailing `*` is never closed. Switch to a real markdown library (`markdown` package) or document as unsupported.
- **`MarkdownToHtml._escapeHtml` processes `processed` instead of escaping raw text.**
  `lib/src/helpers/markdown_to_html.dart:299-326`: the second argument `raw` is **ignored** in the loop body. The intent was clearly to escape text outside tags in `processed` (which it does) — but the code doesn't validate that `<...>` sequences in `processed` correspond to source construct in `raw`, so a user-supplied `<b>hello</b>` followed by a markdown marker creates tags that bypass the allow-list path. See `_knownTag` line 288 — the regex matches `^</?(b|i|...)>$` only, but `<b onclick="...">` is escaped via `_escapeHtmlRaw(processed.substring(i + 1, close))` which means quotes inside **legitimate** `<a href="https://x?a=1&b=2">` get re-escaped by the second-pass walk. Functionally safe but visually broken — `&` becomes `&amp;` **twice** in some pre-formatted URLs.
  - Replace `MarkdownToHtml` with `package:markdown` and pipe through `md.TextToHtml().convert`, then run a single sanitizer pass.
- **`EncryptionService.startBootstrap` returns a `Bootstrap` object but the call chain ignores it.** **🟢 [Fixed]** — `EncryptionService.onBootstrapFinished()` now resets `_initialRefreshComplete` and triggers a full state refresh on every wizard transition; `EncryptionOverviewScreen._startBootstrap` always calls it (success or failure path). Setup post-login prompts no longer race the SDK's first sync because `init()` now `await`s its first refresh internally and `setupRequirement` suppresses prompts until `_initialRefreshComplete` flips true.
- **`EncryptionService.init` spawns three concurrent network calls on every sync.** **🟢 [Fixed]** — `_runRefresh` coalesces concurrent refreshes into a single in-flight `Future` and `_onSync` debounces by 750ms so multiple ticks inside the window don't spam `getDevices()`/`m.cross_signing`/`keyManager.enabled`.
- **`EncryptionService._refreshBackupState` exposes placeholder values.** **🟢 [Fixed]** — the always-zero version / key counts and the cross-signing-proxy "has recovery key" flag are gone; the overview now uses `keyBackupExists` (driven by `enc.keyManager.enabled`) and `keyBackupCached` (driven by `crossSigning.enabled`, the closest reliable proxy), plus `keyBackupAlgorithm` which falls back to `null` rather than a hard-coded string. The Matrix SDK does not publicly expose the backup version or upload progress; document that the surface is `{exists, cached, algorithm}` until upstream exposes more.
- **`EncryptionService.isUserVerifiedById` is correct on the SDK side but the in-house comment was misleading.** **🟢 [Fixed]** — dropped the false "reject self-trust" claim; the getter now reads `mk.verified` (which is the SDK's combined `directVerified || crossVerified` flag) which is exactly what consumers want.
- **`PostLoginSetupChecker` races the first refresh.** **🟢 [Fixed]** — `_check()` calls `await enc.init()` (already awaited internally) so cross-signing flag is populated before `setupRequirement` is consulted; the 500ms `Future.delayed` is replaced by a 900ms wait that lines up with the new debounce window.
- **`TimelineView._UndecryptableBanner` count is computed once and frozen.**
  `lib/src/chat/timeline_view.dart:322-324` calls `_buildItemList` only on cache miss, then inserts the banner based on the count at build time. The cache is invalidated only by `_cacheKey`, so an encrypted event that arrives between two rebuilds will not update the banner until the user changes something. Read the count from a stream-driven `ValueListenable` instead.
- **`AccountManager.switchToAccount` won't move between two logged-in accounts cleanly.**
  `lib/src/helpers/account_manager.dart:218-244` disposes the client then creates a new one, but `EncryptionService.init()` runs inside `onClientReady` which only sets `_isInitialized`. The widgets under the `Provider<EncryptionService>` continue to hold a reference to the old service until `notifyListeners` propagates, and there's no `await encryptionService.init()` between switch and notify. Easy crash on quick switching.
- **`DatabaseService` swallows wipe failures.**
  `lib/src/services/database_service.dart:62-66`: `sql.deleteDatabase` errors are caught and silently dropped, but if the deletion fails the *next* call to `openDatabase` opens the **old** database with the new schema version, producing schema errors mid-use that bubble up as `SqliteException`. Log and propagate.
- **`ChatBox._send` clears the input before knowing whether send succeeded.**
  `lib/src/chat/chat_box.dart:162-163`: this is intentional UX, but no draft is preserved when send fails. If the user pasted a long message and the network drops, they lose it. Stash the unsent text in a `_draftValue` and restore on error.
- **`TimelineView._jumpToEvent` calculates position on `eventIdToItemIndex.length`, but that map is rebuilt on every cache miss.**
  `lib/src/chat/timeline_view.dart:390-396`: when the cache is fresh, `eventIdToItemIndex.length` differs from the full visible list length because of date separator and undecryptable-banner entries. Acceptable as an approximation but document it.

### 🟡 Performance

- **`EncryptionService.init` spawns three concurrent network calls on every sync.**
  `lib/src/encryption/encryption_service.dart:148-158`: every sync tick fires `Future.wait` for cross-signing, backup, and devices. The Matrix SDK's sync is ~30s nominal; on a slow network or a fast account switch we spam the homeserver. Debounce (`Timer`) and coalesce.
- **`_HtmlParseCache` is shared across all events.**
  `lib/src/chat/events/formatted_text_widget.dart:163-185`: keyed on `hashCode ^ baseFontSize.hashCode`. Two different messages that happen to hash to the same value will return each other's parsed spans. Use a `Map<String, ...>` keyed by the raw string instead.
- **`RoomsPane` rebuilds the whole ListView on every sync.**
  `lib/src/widgets/rooms_pane.dart:51-148` (`StreamBuilder(client.onSync.stream, ...)`). With many rooms this is O(n) per sync tick. Use `ValueListenableBuilder<SyncUpdate>` or compute the diff.
- **`AvatarFromUriOrFallbackImage` recomputes the thumbnail URL on every rebuild.**
  `lib/src/widgets/avatar_from_uri.dart:48-69`: the `Future` passed to `FutureBuilder` is re-created every build, so the resolution never completes inside a frequently-rebuilding parent. Cache the resolved URI via a small `Map<mxcUri, Future<Uri>>`.
- **Same problem in `RoomsPane._RoomAvatar._buildAvatar`** (`lib/src/widgets/rooms_pane.dart:260-298`).
- **`_StringColor` cache is unbounded and never released.**
  `lib/src/helpers/string_color.dart:8-46`: `_colorCache` accumulates by full string. A long-running session against big rooms with thousands of unique senders will leak `Map` entries forever. LRU with ~512 entries.

### 🔵 Refactors

- **Two parallel HTML rendering paths.**
  `MarkdownToHtml` (outgoing) and `_HtmlTagParser` (incoming) each implement their own tag-allow-list. Extract a single `SanitizedHtml` helper used in both directions.
- **`SettingsService` has both individual-key getters and `loadAll`.** A handful of call sites still use the per-key async getters (`themeOption()`, `displayType()`, etc.); `settings_controller.dart` already uses `loadAll` so the per-key getters are dead weight. Delete.
- **`MoonrelayColorPalette` mixes RAW palette swatches with API methods that all delegate to `string_color.dart`**. Either pull `StringColor` in as the implementation detail, or delete `getColorFromString` etc. and force callers to import `string_color.dart` directly.
- **AccountManager / Provider wiring is split across `app.dart` and `boot.dart`.** `boot.dart` injects `clientFactory` / `onClientReady`, then `app.dart` re-wraps the active client + encryption service in `Provider.value`. Move all of this into a `MoonrelayScope` widget that consumes a single `BootContext`. Reason: account switching currently requires an `AppFrame` rebuild because of the wrapping order.
- **Hardcoded `MoonRouter` lists every route once for `/welcome` and once at the root.** `lib/src/router.dart:99-147` and `155-200` repeat the route table layout. Extract `routesFor(...)` so deep-link generation matches the route definitions.
- **60+ `_buildXxx` private widget classes scattered across pages** (e.g. `_PinnedFilterButton`, `_UndecryptableBanner`, `_SidebarPane`, etc.). Move into `lib/src/widgets/` and reuse.

### 🟢 Missing features (still)

These are still pending from the earlier "Bad Design" / DeepSeek lists. I've grouped them by priority for the Alpha cutoff.

- Read receipts (`Room.setReadReceipt`) — currently we never mark messages as read, so badge counts never reset and the `_markRoomRead` call in `chat_timeline.dart:165` is a no-op (`Room.markAsRead` differs from the SDK's API). Confirm and wire.
- Reply markdown formatting (the bug called out above).
- True mention/highlight distinction in the room list (currently just `notificationCount`).
- Skeleton loading screens — `lib/src/screens/loading_screen.dart` exists but only for the boot, not for individual rooms/panes; the Linux "blank screen" complaint is real.
- Sticker picker UI is decent (`lib/src/chat/chat_box_sticker_picker.dart`) but the sender of a sticker event is shown as plain text — the renderer treats it identically to an image.
- Direct chat list (`FriendsChatsPane`) is a placeholder that just shows the user-search widget.
- Avatar fallback: many rooms show broken avatars in `RoomsPane` (`// FIXME: Avatar & Badge` from earlier revisions isn't in the current code but the symptom remains — when `room.avatar == null` and the SDK hasn't synced state yet the initials render with an empty string from `Room.getLocalizedDisplayname()`).
- Push notifications: `NotificationService` is local-notifications-only; real push isn't bridged.
- **Off-thread compute.** `MarkdownToHtml.convert` is called from the UI thread for every send. Move into an isolate (`compute()`) for messages over a few kB.

---

## Encryption v1 (now)

- Service state model **🟢 [Feature]** — `lib/src/encryption/encryption_service.dart` exposes `{crossSigningBootstrapped, isThisDeviceVerified, masterKeyFingerprint, isUserVerified, isDeviceVerifiedById, isUserVerifiedById, keyBackupExists, keyBackupCached, keyBackupAlgorithm, myDevices, setupRequirement, onKeyVerificationRequest, refresh, onBootstrapFinished, startBootstrap, requestSelfVerification}` to a single `ChangeNotifier`. The previous "mix of placeholder strings and proxy fields" on the key-backup side has been replaced with what the public Matrix SDK can actually answer for: `{exists, cached, algorithm}`.
- Post-login prompts **🟢 [Feature]** — `lib/src/widgets/encryption/post_login_setup_checker.dart` uses an `_initialRefreshComplete` flag exposed by the service so the bootstrap / verify dialogs no longer race the first sync and no longer rely on a 500ms `Future.delayed` crutch.
- Incoming verification listener **🟢 [Feature]** — `lib/src/widgets/encryption/incoming_verification_listener.dart` (placed in `DashboardLayout`) shows a non-modal accept dialog for every to-device verification request and pushes `VerificationScreen` for the SAS step.
- SAS / emoji verification **🟢 [Feature]** — `lib/src/screens/encryption/verification_screen.dart` handles the full state machine (`askAccept`, `askChoice`, `askSas`, `waitingSas`, `done`, `error`).
- Bootstrap wizard **🟢 [Feature]** — `lib/src/screens/encryption/bootstrap_screen.dart` drives every `BootstrapState` from SSSS wipe through cross-signing setup through online-backup setup, with a destructive-action confirmation on SSSS wipe.
- Encryption overview **🟢 [Feature]** — `lib/src/screens/encryption/encryption_overview.dart` exposes cross-signing status, this-device verification, the master-key fingerprint, key-backup state with backup-algorithm and recovery-key detection, and the unverified-users count with a manual Refresh button in the AppBar.
- Device list **🟢 [Feature]** — `lib/src/screens/encryption/device_list_screen.dart` now shows a relative last-seen timestamp per device (handled inline, no date-formatting dependency).
- User device list **🟢 [Feature]** — `lib/src/screens/encryption/user_devices_screen.dart` shows the per-device trust state for an arbitrary user from a room, including the master-key verification status header.
- Trust badges **🟢 [Feature]** — `lib/src/widgets/encryption/trust_indicator.dart` renders the per-message `shieldCheck` / `shieldOff` icon used by `lib/src/chat/chat_event.dart:_isDeviceVerified` (original `device_id` → user-level master-key fallback).

### 🟠 Encryption correctness still outstanding

- **`AccountManager.switchToAccount` won't move between two logged-in accounts cleanly** — `lib/src/helpers/account_manager.dart:218-244` disposes the client then creates a new one, but `EncryptionService.init()` runs inside `onClientReady` which only sets `_isInitialized`. The widgets under the `Provider<EncryptionService>` continue to hold a reference to the old service until `notifyListeners` propagates, and there's no `await encryptionService.init()` between switch and notify. Easy crash on quick switching. The boot-side `encryptionService` field in `_AppState` is also constructed once and not updated on switch. Recommended: route the live `EncryptionService` through `AccountManager.encryptionService` (already there as a getter — just need to inject it into the provider tree after every switch).
- **`Client.accountDataLoading` is awaited inside the SDK's `CrossSigning.isCached`, but `EncryptionService._refreshCrossSigningStatus` does not await it.** The debounced refresh may read `CrossSigning.enabled` while account data is still being parsed from a sync, producing a transient `false` that flips the overview's "Cross-signing is active" badge to "not set up" and then back. Wrap the read in `client.accountDataLoading.future` (Flutter 3.3+) before returning a value.
- **SSO callback during bootstrap.** `EncryptionService.requestSelfVerification` does not handle the case where the user starts the flow with SSSS locked; the to-device request fails silently and `KeyVerification.canceledReason` is never surfaced in the GUI. The `VerificationScreen._buildBody` returns `_statusColumn(loading)` for `KeyVerificationState.askSSSS`, which spins forever — the user must reopen the encryption overview and click Verify again.

### 🟢 Encryption follow-ups deferred to Alpha+1

- Surface the **recovery passphrase** to the user at the end of the bootstrap wizard. Element generates one and shows a confirmation dialog ("I have saved my recovery key"). Without that step users cannot actually restore their account.
- Wire a **per-room encryption indicator** (the small badge already implemented in `EncryptionBadge`) into the room list so users can spot unencrypted rooms before they send a message.
- Add a **"rotate megolm session"** action in room details for paranoid users.
- Wire an **explicit "export E2EE keys"** action (currently the recovery key is the only path).

---

## Future work

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

- FutureBuilders **🟢 [Done]**
- New Chat Timeline **🟢 [Done]**
- Skeletonised loading — **🟠 [Correctness]** Above: skeleton screens for rooms / login → hub transition / room list.
- Own blur widget **🟢 [Done]**
- Potential global key issue? **🟢 [Done]**
- Use layout building instead of static layout widgets **🟢 [Done]**
- FIXME Handle cases where user profile response is invalid! **🟢 [Done]**
- FIXME List tiles are not adaptive, causing an exception when the list tile becomes smaller than the title widget **🟢 [Done]**

---

## I had DeepSeek generate a list of missing features, please feast thine eyes:

> The DeepSeek audit was thorough but stale relative to the current code (the project has gained threads, in-room search, multi-account, a hub settings screen, in-app encryption bootstrapping, a verified-event rail, …). I'm not duplicating that table here — the unresolved items are folded into the "Missing features" list above.

### Status of the original 100-item table

| Category | Done since last audit | Partial → done | New work added |
|----------|----------------------|----------------|---------------|
| Messaging & Content | 4 | 3 | Inline images, syntax highlight |
| Event Relationships | 6 | — | Reply markdown formatting |
| User & Room Management | 0 | 4 | All still TODO except kick/ban (UI in `MessageActions`) |
| Spaces | 0 | 1 (hierarchy flat-only) | Tree rendering |
| Encryption | 9 | — | Recovery-key export, key-request action |
| Presence & Read Receipts | 0 | 1 (typing state struct exists) | Read-receipt wiring |
| Notifications | 1 (local-only) | — | Real push bridge |
| Content & Media | 0 | 1 (thumbnails) | Blurhash, inline player |
| Room & Timeline | 4 | 1 (jump-to-event) | Read marker line, jump-to-bottom FAB |
| Navigation & UI | 1 (FriendsChatsPane shows search) | — | Mobile shell, keyboard shortcuts |
| Settings | 1 (font size, UI scale) | — | Multi-account switcher UI |
| Testing | 0 | — | See below |
| Infra & Polish | 0 | 1 (l10n partial) | Storage hardening (see Security) |

### Testing (still essentially green-field)

`test/widget/` covers single widgets in isolation; `test/unit/` covers small helpers. There are **no** tests for:
- `LoginPage._doPasswordLogin` (the most security-critical path)
- `SsoCallbackServer._handleRequest`
- `EncryptionService.startBootstrap` / `requestVerification`
- `ChatBox._send` (reply path, markdown path, error path)
- `MarkdownToHtml` round-trips (escaping is tricky; the bug above would have been caught by a property test)
- `AccountManager.switchToAccount` / `logout`
- `NotificationService` redaction / persistence
- `DatabaseService` wipe-and-recreate

Add `test/unit/login_security_test.dart`, `test/unit/markdown_round_trip_test.dart`, and `test/widget/account_switching_test.dart` as the first three writes. The E2E harness in `integration_test/helpers/` is the right starting point but it does not yet exercise any of these.
