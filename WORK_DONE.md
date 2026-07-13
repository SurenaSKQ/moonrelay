# WORK_DONE

Closed-work ledger for Moonrelay. Tracks everything that has shipped
or been resolved across the July 2026 audit pass and the follow-up
performance/memory audit.

| Source ledger | Period | Scope |
|---------------|--------|-------|
| `audit_6_7_26.md` | July 2026 audit pass | 31 findings; 30 verified already resolved, 1 fixed in-pass (#30) |
| `WORK_NEEDED.md` § 3.4 | July 2026 audit pass | Desktop-service hardening, chat/encryption surface, settings, login, boot, search, perf |
| Performance/memory audit | August 2026 follow-up | 38 tickets across chat, encryption, services, settings, panes, dialogs, dashboards |

**Tests at head:** `flutter test test/unit/` → all green
· `flutter analyze` → 0 errors.

---

## 1. Desktop-service hardening (audit #1–10, #12, #15–17, #19, #22, #25, #26, #30)

| # | Area | Resolution | Where |
|---|------|------------|-------|
| 1 | `NotificationService` swallowed plugin-init failures | `_initPlugin` returns `bool`; `isAvailable` flag exposed; service is no-op when plugin is null but `init` never crashes | `lib/src/services/notification_service.dart` |
| 2 | `eventId.hashCode` collision in `_showNotification` | String tags `matrix:<roomId>:<eventId>` on every supported platform (see `_eventTag`); summary uses `NotificationService.groupSummaryTag` | `lib/src/services/notification_service.dart:_eventTag` |
| 3 | `TrayService` crashes on `getTemporaryDirectory` failure | `_setup` wraps the entire flow in `try/catch`; `isAvailable` flag gates UI; `_init` clears `_instance` on failure | `lib/src/services/tray_service.dart:_setup` |
| 4 | `showTestNotification` threw when plugin null | Returns `bool`; UI can disable affordance on `isAvailable == false` | `lib/src/services/notification_service.dart` |
| 5 | Persist-on-every-sync-tick | 750 ms debounce timer in `_persistDebouncer`; flush on dispose | `lib/src/services/notification_service.dart` |
| 7 | Notification tap ignored payload | `_onNotificationTap` decodes `response.payload` and routes via `DeepLinkService` / `navigateToMatrixUri` | `lib/src/services/notification_service.dart` |
| 8 | Encrypted event body leak | `"(encrypted message)"` placeholder when `event.type == EventTypes.Encrypted` and `m.ciphertext` present | `lib/src/services/notification_service.dart:_processEvent` |
| 9 | Tray ignored muted rooms + lost mention counts | `NotificationService.mutedRoomsSnapshot`; `Room.highlightCount` surfaces in tooltip; `Room.notificationCount` is the fallback | `lib/src/services/notification_service.dart`, `lib/src/services/tray_service.dart:_refreshBadge` |
| 10 | Temp-file leak in `_setup` | `_iconFile` tracked, deleted in `destroyTray` and on `_setup` failure | `lib/src/services/tray_service.dart` |
| 12 | `processUri` no dedup | 500 ms `_isDuplicate` window via `_lastUri` / `_lastAt` | `lib/src/services/deep_link_service.dart` |
| 15 | Stale `TrayService.Client` on account switch | `TrayService` listens to `AccountManager.activeClient` via `_onActiveAccountChanged`; re-binds sync listener on switch | `lib/src/services/tray_service.dart:_onActiveAccountChanged` |
| 16 | Unbounded `_notifiedEventIds` cache | Bounded FIFO with `_notifiedIdsCacheLimit = 256` + `_seenOrder` | `lib/src/services/notification_service.dart` |
| 17 | Linux / macOS plugin missing in registration | `InitializationSettings` covers all platforms natively | `lib/src/services/notification_service.dart:_initPlugin` |
| 19 | Four `SharedPreferences` keys for one service | `loadMutedRooms` / `_loadLastEventIds` / `_loadGroupNotifiedCounts` all migrate legacy formats | `lib/src/services/notification_service.dart` |
| 22 | `dispose` not symmetric to `init` | In-memory state cleared on dispose; `dispose` cancels subscriptions + timers + resets flags | `lib/src/services/notification_service.dart:dispose` |
| 25 | No test coverage for desktop services | `test/unit/notification_service_test.dart` added (mocktail-based); tray/lifecycle paths are covered indirectly through boot tests | `test/unit/` |
| 26 | Method channel `TypeError` on non-string args | `if (call.arguments is String)` guard with warning log | `lib/src/services/deep_link_service.dart:_handleMethodCall` |
| 30 | `boot.dart` silent short-circuit | `log.w` when active account exists but `sdk.isLogged()` is false | `lib/src/boot.dart` |

---

## 2. Chat timeline, encryption, settings, login, search (audit 6–8, 9 partial, 11, 13, 14, 18; WORK_NEEDED FIXED)

| Area | Resolution | Where |
|------|------------|-------|
| Reply sending dropped markdown | `chat_box.dart:_send` builds relation payload once (body + formatted_body + reply + thread relations) | `lib/src/chat/chat_box.dart` |
| Clear input before send-result known | Draft captured before `controller.clear()`; restored on throw | `lib/src/chat/chat_box.dart:_send` |
| `?threadRoot=` ignored | `room_page.dart` forwards `threadRootEventId` | `lib/src/screens/room_page.dart` |
| `_UndecryptableBanner` count frozen | `ValueNotifier<int>` updated every visible-items build; static late reference replaces ancestor lookup | `lib/src/chat/timeline_view.dart` |
| SSSS prompt falls to spinner | Dedicated icon, copy, `canceledReason`, Cancel button | `lib/src/screens/encryption/bootstrap_screen.dart` |
| Recovery key disclosure (best-effort) | Done state shows reminder + ack/later buttons | `lib/src/screens/encryption/bootstrap_screen.dart` |
| Three network calls per sync | Coalesced into a single in-flight `Future`; 750 ms debounce | `lib/src/encryption/encryption_service.dart` |
| `Bootstrap` finish ignored | `onBootstrapFinished()` resets refresh and triggers full refresh | `lib/src/encryption/encryption_service.dart` |
| Placeholder backup numbers | Surfaces `{exists, cached, algorithm}` | `lib/src/encryption/encryption_service.dart:_refreshBackupState` |
| `isUserVerifiedById` comment drift | Reads `mk.verified` | `lib/src/encryption/encryption_service.dart` |
| Post-login setup raced first refresh | `_check()` awaits `enc.init()` + one sync + 900 ms delay | `lib/src/widgets/encryption/post_login_setup_checker.dart` |
| In-room search tap didn't jump | `onJumpToEvent` → panel-close + `_timelineKey.jumpToEvent(id)` | `lib/src/chat/in_room_search_panel.dart` |
| HTML `_processBoldItalic` greedy-forward scan | Per-character state machine | `lib/src/helpers/markdown_to_html.dart` |
| `href` attribute XSS | `_escapeAttribute` + `_isSafeHref`; pinned by `test/unit/markdown_round_trip_test.dart` | `lib/src/helpers/markdown_to_html.dart` |
| Comma / pipe separator split | `_readCommaSet`, `_readCommaList`, `_readSpaceGroups` use `jsonDecode` with legacy fallback | `lib/src/settings/settings_service.dart` |
| Matrix URI trailing punctuation | Trailing lookbehind + bare-ID branch only accepts `@…:…` / `#…:…` | `lib/src/helpers/matrix_uri_parser.dart` |
| `_buildAvatar` throws on whitespace | `_initialsForDisplayname` splits, filters, uses `characters.firstOrNull`; falls back to `untitledRoom` | `lib/src/widgets/rooms_pane.dart` |
| SSO redirect URL unvalidated | `isPlausibleHomeserverUrl` + confirmation dialog; pinned by `test/unit/login_security_test.dart` | `lib/src/screens/login_page.dart` |
| SSO callback hangs on error | Every error branch completes the future with an exception and returns 4xx HTML | `lib/src/services/sso_server.dart` |
| Plaintext password leakage via login error | `_safeErrorMessage` maps `TimeoutException` to static copy; log redaction covers `password=…`, `"password":"…"`, `password: …` | `lib/src/screens/login_page.dart` |
| `DatabaseService` swallowed wipe failures | Re-throws as `StateError` | `lib/src/services/database_service.dart` |
| `SplashScreen.updateStatus` never wired | `_boot` forwards every status callback | `lib/main.dart` |
| `AccountManager.switchToAccount` race | New pair built and persisted first, old pair disposed on microtask | `lib/src/helpers/account_manager.dart` |
| `_HtmlParseCache` keyed on `hashCode` | Keys are `formattedBody` only (font size is a render-time scale on cached spans); LRU + byte budget | `lib/src/chat/events/formatted_text_widget.dart` |
| `RoomsPane._buildAvatar` re-creates `FutureBuilder` | `cachedThumbnail` with bounded FIFO; `userID` keying | `lib/src/widgets/avatar_from_uri.dart` |
| `_StringColor._colorCache` unbounded | Bounded at 512; oldest evicted | `lib/src/helpers/string_color.dart` |
| SSSS placeholder backup algorithm | Surfaces real `algorithm` string | `lib/src/encryption/encryption_service.dart` |

---

## 3. Performance and memory (August 2026 follow-up — 38 tickets)

### 3.1 P0 — critical

| Ticket | Resolution | Where |
|--------|------------|-------|
| P0-01 `Image.memory` decoded at full resolution | `cacheWidth: (size.width * dpr).ceil()` on image / sticker / video thumb / full-screen viewer | `image_message_type.dart`, `sticker_message_type.dart`, `video_message_type.dart`, `image_viewer_screen.dart` |
| P0-02 Per-message `context.watch<EncryptionService>` triggered full timeline rebuild on every sync | Memoized `isDeviceVerifiedById` / `isUserVerifiedById` cache fields in EncryptionService; per-message widget switched to `context.read` for verification | `lib/src/encryption/encryption_service.dart`, `lib/src/chat/chat_event.dart` |
| P0-03 `_HtmlParseCache` unbounded + LRU broken | True LRU + 4 MB byte budget + LRU-order refresh; `baseFontSize` removed from cache key (spans cached at canonical 16 px and scaled at render time) | `lib/src/chat/events/formatted_text_widget.dart` |
| P0-04 `AvatarFromUri` thumbnail cache unbounded + `identityHashCode` leak risk | True LRU capped at 512; `userID`-based key with `anon:` fallback; `clearCacheFor` + `clearAll`; wired into `AccountManager` logout | `lib/src/widgets/avatar_from_uri.dart` |
| P0-05 Per-pane `client.onSync` listeners produced 3–5 `setState` per tick | New `SyncPulse` ChangeNotifier with 350 ms debounce + first-tick immediate; `compact_sidebar`, `navigation_pane`, `spaces_pane`, `rooms_pane` all refactored to consume it | `lib/src/helpers/sync_pulse.dart`, `lib/src/app.dart` |

### 3.2 P1 — high

| Ticket | Resolution | Where |
|--------|------------|-------|
| P1-01 `TimelineItem` rebuilt on every parent build | Removed unused `previousEvent`; single `onAction` callback with `TimelineItemAction` enum; `ValueKey(event.eventId)` for stable diffing | `lib/src/chat/timeline_item.dart`, `lib/src/chat/timeline_view.dart` |
| P1-02 Video / audio 60 Hz `setState` | `AnimatedBuilder(animation: controller)` for video; `ValueListenable` per-stream for audio | `lib/src/chat/events/matrix_events/Message/video/video_message_type.dart`, `audio_message_type.dart` |
| P1-03 `_HoverActionsWrapper` / `_ImageHoverRegion` did `setState` on hover | `ValueNotifier<bool>` + `ValueListenableBuilder` overlay; message body never rebuilds | `lib/src/chat/timeline_item.dart`, `image_message_type.dart` |
| P1-04 Each image/sticker/audio/file widget held its own `Future<MatrixFile>` | New `RoomMediaCache` singleton (64 MB byte-budget LRU) shared by all media widgets; per-event dedup | `lib/src/helpers/room_media_cache.dart`, all four media widgets |
| P1-05 `_markReadSent` Set grew unbounded | FIFO cap at 64; drops oldest quarter on overflow | `lib/src/chat/chat_timeline.dart` |
| P1-06 `ThreadViewPage` did O(N) `aggregatedEvents` per build while watching full `SettingsController` | `context.select<SettingsController, double>` for font size; reply count pre-computed in `_findRootEvent` | `lib/src/screens/thread_view.dart` |
| P1-07 `_paginateUntilMarker` could stall 8 minutes | Cap reduced to 6 iterations; 4 s per-iteration timeout; 8 s global timeout via `.timeout` | `lib/src/chat/chat_timeline.dart` |
| P1-08 `DraftService` allocated per ChatBox mount; timer leaked across rooms | Singleton-per-account `instanceFor` with reference counting; `release` in `dispose` cancels pending timer | `lib/src/services/draft_service.dart`, `lib/src/chat/chat_box.dart` |
| P1-09 `_SidebarRoomInfo` rebuilt on every state event regardless of visible change | Change-detection in `_refreshFromRoom`; `setState` only when at least one user-visible field actually differs | `lib/src/layouts/dashboard_layout.dart` |

### 3.3 P2 — medium

| Ticket | Resolution | Where |
|--------|------------|-------|
| P2-01 `_ClientThumbnailCache` keyed by `identityHashCode` | `userID`-based key with `anon:` fallback; `disposeRoom` on leave; `clear` on logout | `lib/src/widgets/rooms_pane.dart` |
| P2-02 `NavigationPane` scanned `client.rooms.where(isSpace)` on every parent build | Cached `_cachedSpaceIds` refreshed only on sync pulse tick | `lib/src/widgets/navigation_pane.dart` |
| P2-03 `DashboardLayout` `setState` on every shell decision flip rebuilt the entire tree | New `LayoutShellController` ValueListenable; only the shell subtree re-renders | `lib/src/layouts/layout_shell_controller.dart`, `lib/src/layouts/dashboard_layout.dart` |
| P2-04 `PinnedEventsCache` evicted by entry count (512) only | Byte-budget eviction (64 MB); LRU by access; per-event size estimate | `lib/src/helpers/pinned_events_cache.dart` |
| P2-05 `NotificationService` re-processed every room on every sync tick even when nothing changed | `_processRoomsIfChanged` short-circuits on no-op ticks; group summary now uses caller-supplied room id (no scan) | `lib/src/services/notification_service.dart` |
| P2-07 Permission checks recomputed on every hover-actions render | Deferred (low ROI for the action visibility) | — |
| P2-09 Every widget subscribed to `client.onRoomState` independently | New `RoomStateBus` (per-room `ValueListenable<int>` tick); `_SidebarRoomInfo` migrated to it | `lib/src/helpers/room_state_bus.dart` |
| P2-11 `EncryptionService.dispose` cleanup | Verified — subscription + debounce timer + in-memory state cleared (`onLogout` clears `_cachedUnverified`, `_myDevices`, etc.) | `lib/src/encryption/encryption_service.dart` |
| P2-14 `SpacePreferences` fired `notifyListeners` on every drag-reorder step | Coalesced via microtask; `dispose` guard added | `lib/src/settings/space_preferences.dart` |
| P2-17 `_ReplyPreview` re-issued `getEventById` on every parent build | Memoized `_pendingFetch` future; cleared in `didUpdateWidget` when reply target changes | `lib/src/chat/chat_event.dart` |
| P2-18 `_inviteUser` `TextEditingController` leaked | `dispose()` after dialog closes, text captured before dispose | `lib/src/screens/user_profile.dart` |
| P2-19 `RoomsPane` used heavy `ListTile` per row | New lightweight `_RoomRow` widget; displayname memoized per row | `lib/src/widgets/rooms_pane.dart` |

### 3.4 P3/P4 — minor and tests

| Ticket | Resolution | Where |
|--------|------------|-------|
| P3-02 Cache `isDeviceVerifiedById` | Addressed by P0-02 | — |
| P3-03 Voice / location dialog resource disposal | Verified correct | — |
| P4-01 Performance regression test + memory smoke test | `test/unit/room_media_cache_test.dart` covering LRU eviction, in-flight dedup, and `SyncPulse` coalescing | `test/unit/` |

---

## 4. Cross-cutting improvements

| Area | Improvement | Where |
|------|-------------|-------|
| Provider wiring | `Provider<RoomStateBus>` and `ChangeNotifierProvider<SyncPulse>` injected by `MoonrelayApp`; re-bound on `AccountManager` account switch | `lib/src/app.dart` |
| Shell decision | Extracted to `LayoutShellController` — single source of truth for compact vs wide | `lib/src/layouts/layout_shell_controller.dart` |
| Media cache | `RoomMediaCache` deduplicates downloads across the app; per-event TTL; LRU by bytes | `lib/src/helpers/room_media_cache.dart` |
| State-event fan-out | `RoomStateBus` centralises one O(N) filter into a shared fan-out | `lib/src/helpers/room_state_bus.dart` |
| Draft persistence | `DraftService` is a reference-counted singleton; no timer leaks on room switch | `lib/src/services/draft_service.dart` |
| Settings coalescing | `SpacePreferences` microtask-coalesced notifies | `lib/src/settings/space_preferences.dart` |
| Encryption caching | Per-`(userId, deviceId)` and per-`userId` memoized lookups; invalidated by sync | `lib/src/encryption/encryption_service.dart` |
| Reply preview | Memoized fetch future with proper invalidation on reply-target change | `lib/src/chat/chat_event.dart` |
| Sidebar info | Only rebuilds when a user-visible field actually changed | `lib/src/layouts/dashboard_layout.dart` |
| HTML cache | True LRU + byte budget; font-size changes no longer invalidate the cache | `lib/src/chat/events/formatted_text_widget.dart` |

---

## 5. Test additions

| File | Coverage |
|------|----------|
| `test/unit/notification_service_test.dart` | Muted-room persistence + migration; last-event-id persistence; group-count persistence; show/skip logic for DM + group; sender skip; body-empty skip; current-room skip; `_showNotification` no-op when plugin null; first-time-room baseline; group summary copy (single vs multi) |
| `test/unit/draft_service_test.dart` | load/save/clear round-trip; empty drafts removed; cross-account isolation; debounced scheduleSave persists |
| `test/unit/room_media_cache_test.dart` | Byte-budget eviction drops oldest entries; concurrent `getOrDownload` calls share one in-flight future; `SyncPulse` coalesces a burst of pokes into one broadcast |
| `test/unit/pinned_events_cache_test.dart` | Byte-budget eviction; per-event size estimate; LRU by access |
| `test/unit/markdown_round_trip_test.dart` | XSS hardening (`href` attribute escape + safe-URL allow-list) |
| `test/unit/login_security_test.dart` | SSO redirect URL plausibility; password log redaction; `_safeErrorMessage` does not leak `MatrixHttpException.toString` |
| `test/unit/sso_callback_server_test.dart` | SSO callback happy path; wrong-`state` rejection; timeout |
| `test/unit/database_service_test.dart` | wipe-on-version-bump with the `StateError` path |
| `test/unit/space_rooms_tree_test.dart`, `account_manager_test.dart`, `app_version_test.dart`, `chat_timeline_test.dart`, `auto_update_service_test.dart`, `date_time_extension_test.dart`, `display_type_test.dart`, `html_parser_test.dart`, `localization_smoke_test.dart`, `log_redaction_test.dart`, `matrix_uri_parser_test.dart`, `navigation_state_test.dart`, `responsive_test.dart`, `room_preview_screen_test.dart`, `search_provider_test.dart`, `search_provider_users_test.dart`, `settings_controller_test.dart`, `settings_extended_test.dart`, `settings_service_test.dart`, `space_hierarchy_test.dart`, `space_pinning_test.dart`, `string_color_test.dart` | Pre-existing coverage preserved and still passing |
| `test/widget/message_action_runner_test.dart`, `login_page_test.dart`, `delivery_indicator_test.dart`, `encryption_badge_test.dart` | Pre-existing widget coverage preserved and still passing |

---

## 6. Open backlog (tracked in `WORK_NEEDED.md`)

These items remain open and live in `WORK_NEEDED.md` § 1 and § 2:

| Item | Source | Status |
|------|--------|--------|
| Login → hub skeleton (splash holds until first room cached) | WORK_NEEDED § 1.1 | Open |
| Future-aware surface comments (`TimelineView` count notifier; `jumpToEvent`) | WORK_NEEDED § 1.2 | Open |
| HTML allow-list consolidation; color palette cleanup; `MoonrelayScope` widget; scattered `_buildXxx` extraction; `EncryptionService.markDirty()` for `_cachedUnverified` + verified caches | WORK_NEEDED § 1.3 | Open |
| Recovery-key save dialog (post-bootstrap) | WORK_NEEDED § 2.1 | Open |
| Reply expand / collapse (thread-mode view of replies) | WORK_NEEDED § 2.2 | Open |
| Sticker sender label differentiation | WORK_NEEDED § 2.2 | Open |
| Push notifications (OS-level push bridge) | WORK_NEEDED § 2.2 | Open |
| Right-sidebar expansion (search / member mgmt / settings / avatar upload as sidebar tabs vs routes) | WORK_NEEDED § 2.3 | Open |
| Future work (custom events v3, application fundamentals v2) | WORK_NEEDED § 4 | Open |
| Wishlist (server SDK, client SDK fork) | WORK_NEEDED § 5 | Long-term |
| P2-07 Permission checks recomputed on every hover-actions render | Aug-2026 follow-up § 3.3 | Deferred (low ROI) |

---

*This file is the closed-work companion to `WORK_NEEDED.md` (open
work). New work should be tracked in `WORK_NEEDED.md`.*
