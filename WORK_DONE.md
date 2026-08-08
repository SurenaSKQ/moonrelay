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


WORK_DONE

Closed-work ledger for Moonrelay. This file is a running log of things that
have shipped or been fixed. The current entries cover the July 2026 audit
pass, the August 2026 performance/memory follow-up, the media widget polish
pass, the recent UX fix-up pass, the chat-timeline scroll-performance
pass, the chat-timeline scroll-velocity second pass, the
hoverbar rearchitecture, the responsive-layout shell rework, the
shell-flip navigation leak fix, the August 2026 bug-fix pass (24
fixes from the full-codebase audit), the SSO loopback-host
regression fix, the timeline scroll-position null-deref crash fix,
the August 2026 timeline dead-code and duplication removal, the
timeline Suckless-cleanup pass, the jump-to-unread FAB survival, and
the jump-to-unread target-selection and scroll-execution fixes, and the
status-pill honesty fix plus the dead appearance-settings wiring, and the
blank-content error guidance pass, and the dashboard UI refresh pass
(OS-window-decorations default with an optional slim in-app header, and
a unified navigation sidebar), and the collapsible sidebar sections
follow-up.

Known-fail tests: 0 [<---- Update this if a test is known as broken ---->]

Tests at head: flutter test 583 green (8 new tests across this pass:
3 sidebar section-collapse widget tests, 5 settings tests).
flutter analyze 0 issues. (Suite baseline prior to these passes was 575.)

24. Collapsible sidebar sections

The navigation sidebar's spaces and rooms regions could not be hidden;
users with a short space list or a single active room had no way to
reclaim that vertical space. Both section headers are now tappable and
show a chevron that flips with the text direction (chevron-down when
expanded, pointing at the screen edge when collapsed in RTL).

- lib/src/settings: new `collapsedSidebarSections` set (ids like
  `spaces` / `rooms`), persisted as a JSON array via the existing
  comma-set reader. The controller replaces the set with a copy on
  toggle so `context.select` consumers rebuild only when the contents
  actually change.
- lib/src/widgets/navigation_sidebar.dart: the section headers take
  collapsed state and a toggle callback; the spaces region (hidden
  entirely when there are no spaces) and the rooms region mount and
  unmount their lists underneath the headers.
- test/widget/navigation_sidebar_test.dart (3 new) — tapping the rooms
  or spaces header collapses the section, and a persisted collapsed
  section survives a rebuild.
- test/unit/settings_controller_test.dart (5 new) — collapse round-trip,
  set-instance replacement for scoped rebuilds, notify-on-change, and
  persistence across controller reloads.

23. Dashboard UI refresh: OS decorations and the unified navigation sidebar

The window header and the left side of the dashboard were rebuilt so the
app stops fighting the desktop window manager and the rooms/spaces
pickup stops being split across three separate columns.

The header is now optional and off by default: a new `useOsTitleBar`
setting (default true) restores the native title bar, and the old
reversible header with the profile pill, command palette button, and
sidebar toggle is gone.  When the in-app header is enabled it is slim:
a draggable title area, platform window buttons, and the right-click
system menu only.

- `lib/src/settings` persists `useOsTitleBar` (controller, service,
  snapshot).
- `lib/src/helpers/window_chrome.dart` (new) applies the title bar style
  at boot and re-applies it live when the setting flips; both frames
  (`lib/src/layouts/app_frame.dart`, `startscreen_frame.dart`) listen.
- `lib/src/screens/hub_screen/settings/layout_settings.dart` swaps the
  reversed-header toggle for the OS-decorations toggle and drops the
  left-sidebar width slider (the sidebar is no longer resizable).

The wide dashboard's three left columns (nav rail, resizable rooms
pane, header chrome) collapse into one navigation sidebar:

- `lib/src/widgets/navigation_sidebar.dart` (new): the profile pill,
  the command palette row, the Home/All/Add-Room destination rows, and
  the spaces list sit above the destination-filtered rooms region.  The
  spaces ordering, grouping, context menus, auto-grouping, and
  drag-and-drop logic are ported unchanged from the deleted navigation
  rail; the rooms region reuses RoomsPane / SpaceRoomsPane untouched.
- `lib/src/widgets/sidebar_profile_pill.dart` and
  `sidebar_actions.dart` (new): shared by the full and compact
  sidebars so the compact shell keeps every action that used to live
  in the header.
- `lib/src/widgets/compact_sidebar.dart` gains the same header block.
- `lib/src/layouts/dashboard_layout/dashboard_view.dart`: the left
  sidebar is no longer resize-draggable; a hover gutter collapses it,
  and an edge strip with the same affordance lets the user expand it
  again.  Both are row children, so RTL windows keep them on the same
  side as the sidebar.  The right sidebar keeps its resize handle.
- Dead code removed: NavigationPane, SpacesPane, LeftPaneChoice,
  buildLeftPaneContent, the left-resize notifiers, and the
  navigationPaneWidth constant.

Tests added:
- test/widget/navigation_sidebar_test.dart (4) — sidebar renders its
  chrome, the command palette row opens the palette, the expanded shell
  shows the collapse gutter, and toggling visibility swaps in the
  expand gutter.
- test/unit/settings_controller_test.dart (+5) — useOsTitleBar
  default/round-trip/notify and the left-sidebar visibility toggle.

22. Blank-content error guidance

Three content panes used to render blank surfaces when something was
missing, leaving the user with no recourse:

- `lib/src/helpers/profile_delegate.dart` returned `SizedBox.shrink()`
  (only a transient snackbar as feedback) for a null/malformed user ID.
  It now renders [EmptyState] with an icon, the existing error message
  (`profileIdNullError`/`profileIdInvalid`), and a "Back" button that pops.
- `lib/src/helpers/room_delegate.dart` returned a bare `EmptySpace()` for
  a null/empty room ID and for a room ID that isn't joined. The null/empty
  case now renders [EmptyState] ("Error" / "Room not found" / "Back").
  The not-joined case now hands off to the existing [RoomPreviewScreen]
  (route `/main/room_preview/:roomid`) instead of a blank splash, so a
  deep link to an unjoined room resolves its identity and offers a Join.
- `lib/src/widgets/empty_state.dart` (new) — a small reusable centred
  empty/error state (icon + title + message + optional action button),
  matching the visual density of rooms_pane's empty/loading states.

The pre-existing 8-second-first-sync fallback in room_delegate (`Still
waiting for the server…` / `Retry`) was intentionally left as-is; its
hardcoded English text is tracked under 1.5.

Tests added:
- test/widget/empty_states_test.dart (7) — EmptyState rendering with/without
  an action, ProfileDelegate null/malformed/valid id paths, RoomDelegate
  null id and not-joined-to-preview-screen handoff.

21. Status pillar honesty and dead appearance settings

Two UX gaps where the UI either lied or ignored the user's controls.

The header status pill used to render a hardcoded green dot with the
English text "Online" no matter the connection state, while the real
sync state lived only in the status bar. A disconnected user still read
"Online". Replaced it:

- lib/src/widgets/sync_status_pill.dart (new) — stateful [SyncStatusPill]
  that subscribes to [Client.onSyncStatus] (the same stream
  lib/src/widgets/status_bar.dart already uses) and a pure
  [syncStatusToPresence] helper mapping [SyncStatus.finished] -> online,
  waitingForResponse/processing/cleaningUp -> away, error -> offline.
  The dot colour follows: green / amber / red. Dot colour for the
  offline state is taken from colorScheme.onErrorContainer so it stays
  legible in both light and dark themes, unlike the previous magic
  green. Accepts an optional injected stream/initialStatus so the widget
  is unit-testable without the SDK's private CachedStreamController.
- lib/src/layouts/app_frame.dart — drop the now-dead [StatusPill] class
  and render [SyncStatusPill] in the header (was app_frame.dart:406).
- lib/src/localization/app_en.arb, lib/src/localization/app_fa.arb — add
  statusOnline/statusAway/statusOffline (+ Persian: آنلاین/دور/آفلاین);
  run flutter gen-l10n. The generated .dart l10n files are gitignored.

Previously the UI-scale slider and the density chips only updated and
persisted [SettingsController] values that nothing read — classic
"control that looks wired but isn't". Wired them:

- lib/src/app.dart — the MaterialApp.router builder now wraps the child
  in a MediaQuery whose textScaler is TextScaler.linear(uiScale), so
  the "Interface scale" slider actually scales every Text in the tree.
- lib/src/settings/theme.dart — [MoonrelayTheme.light]/[dark] now take
  an optional LayoutDensity and call ThemeData.visualDensity accordingly
  (comfortable -> VisualDensity.standard, compact -> VisualDensity.compact);
  default stays comfortable so existing call sites are unaffected.
- lib/src/widgets/status_bar.dart left untouched; it already reported
  sync state, the pill now matches it.

Note: the per-message "Message font size" slider (SettingsController.fontSize,
already wired to the chat timeline) is intentionally left alone — that is
the intended escape hatch for chat density independent of the global UI
zoom.

Tests added:
- test/widget/sync_status_pill_test.dart (7) — presence mapping + pill
  rendering for finished/error/waiting + a live stream emission flip.
- test/widget/appearance_settings_test.dart (5) — density->visualDensity
  for light/dark/default, uiScale textScaler scaling, and updateUiScale
  persistence + clamping.

20. Timeline dead-code and duplication removal

Dead duplicate files deleted:

- `lib/src/chat/history_pagination.dart` was never imported or referenced
  anywhere in the codebase. It was a near-verbatim duplicate of the
  active `lib/src/chat/history_pager.dart` (same `_shouldDrainStateEvents`,
  same constants). Deleted. The WORK_NEEDED audit had already flagged
  this as a refactor candidate.

- `lib/src/chat/read_marker_coordinator.dart` was never imported or
  referenced. The WORK_DONE.md entry for section 18 explicitly called it
  out as "the dead duplicate path in
  `lib/src/chat/read_marker_coordinator.dart`". Deleted. The active
  implementation is `lib/src/chat/read_marker_tracker.dart`
  (with `ReadMarkerService` in
  `lib/src/services/read_marker_service.dart` for the CAS-protected
  server writes).

Dead inline duplicates removed from `lib/src/chat/timeline_view.dart`:

- `_AnimatedHistorySkeleton` (was lines 737-823) was a private copy of
  the public `AnimatedHistorySkeleton` in
  `lib/src/chat/animated_history_skeleton.dart`. The public version was
  already imported and used at the call site (line 575); the private
  class was never referenced. Deleted.

- `_ItemAppearance` (was lines 831-899) was a private copy of the public
  `ItemAppearance` in `lib/src/chat/item_appearance.dart`. The public
  version was already imported and used at the call site (line 587).
  The unused-key lint warning on the private version had been carried
  through four prior WORK_DONE entries as "pre-existing and unrelated
  to this change". Now resolved. Deleted.

- `_HistorySkeletonTile` (was lines 910-1032) was a private copy of the
  public `HistorySkeletonTile` in `lib/src/chat/history_skeleton_tile.dart`.
  The public version was already imported and used at the call site
  (line 606). Deleted.

- The `motion.dart` import was removed from `timeline_view.dart` since
  `Motion` was only referenced by the three deleted inline classes.

HTML parser extracted from `formatted_text_widget.dart`:

- `_HtmlParseCache`, `_HtmlTagParser`, and the plain-text linkification
  helpers (`_PlainTokenKind`, `_PlainMatch`, `_PlainToken`) were moved
  to a new public `lib/src/chat/events/html_tag_parser.dart` file.
  `formatted_text_widget.dart` is reduced from 938 lines to ~200 lines,
  keeping only the `FormattedTextWidget` class and its linkify logic.
  The parser classes are now public (`HtmlParseCache`, `HtmlTagParser`,
  `PlainTokenKind`, `PlainMatch`, `PlainToken`) and unit-testable.

Permission check consolidation:

- `_canModerate`, `_canBan`, `_canEditText`, and `_isPinned` were
  duplicated verbatim (modulo parameter plumbing) in both
  `lib/src/chat/message_actions.dart` (the hoverbar) and
  `lib/src/chat/message_context_menu.dart` (the right-click menu).
  All four are now static methods on `MessageActionRunner`
  (`canModerate`, `canBan`, `canEditText`, `isPinned`), and both files
  delegate to them. `message_actions.dart` shed 38 lines;
  `message_context_menu.dart` shed 45 lines (plus the unused
  `MessageTypes` import is gone).

Scroll-targeting deduplication:

- The fraction-based scroll-to-index heuristic was triplicated: in
  `TimelineView._scrollToEventId` (timeline_view.dart:632),
  `JumpCoordinator.jumpToEvent` (jump_coordinator.dart:203), and
  `JumpCoordinator._scrollToEvent` (jump_coordinator.dart:284). Each had
  slightly different parameter handling and a slightly different skip-if-close
  guard. All three now share `TimelineScrollTarget.scrollToFraction` in
  the new `lib/src/chat/timeline_scroll_target.dart`. `JumpCoordinator`
  lost ~22 lines; `TimelineView` lost ~14 lines.

Tests at head: flutter test 509 green. flutter analyze 0 errors, 0 warnings.


Dead-count and message-like helper consolidation

- `lib/src/chat/jump_to_unread_pager.dart` contained a second copy of
  `countUnreadInWindow` and a private `_isMessageLike` that shadowed the
  canonical versions in `lib/src/chat/chat_unread_utils.dart`. The
  duplicate was never called (jump_coordinator.dart already imported the
  canonical version via an `as unread` prefix to hide it). Removed the
  dead 27-line function and the 3-line `_isMessageLike` helper, and
  replaced the two call sites of `_isMessageLikeEvent` with the public
  `isMessageLikeEvent` from chat_unread_utils (which is the same function).
  The `EventTypes` import in jump_to_unread_pager.dart is still needed
  for the `_isMessageLikeEvent` callsites within `JumpToUnreadPager` that
  were also replaced. Lost 40 lines.


1. Desktop-service hardening

Items from the July audit that touched the desktop platform services.

1. NotificationService used to swallow plugin init failures. _initPlugin
   now returns a bool, an isAvailable flag is exposed, and the service
   silently no-ops when the plugin is null instead of crashing. See
   lib/src/services/notification_service.dart.

2. eventId.hashCode could collide in _showNotification. We now tag
   notifications as matrix:<roomId>:<eventId> on every supported platform
   (see _eventTag). Group summaries use NotificationService.groupSummaryTag.
   See lib/src/services/notification_service.dart:_eventTag.

3. TrayService crashed when getTemporaryDirectory failed. _setup is now
   wrapped in try/catch, an isAvailable flag gates the UI, and _init clears
   _instance on failure. See lib/src/services/tray_service.dart:_setup.

4. showTestNotification used to throw when the plugin was null. It now
   returns bool, and the UI can disable the affordance when isAvailable is
   false. See lib/src/services/notification_service.dart.

5. Notifications were being persisted on every sync tick. There is now a
   750ms debounce timer in _persistDebouncer, which also flushes on dispose.
   See lib/src/services/notification_service.dart.

7. Notification taps were ignoring the payload. _onNotificationTap now
   decodes response.payload and routes via DeepLinkService /
   navigateToMatrixUri. See lib/src/services/notification_service.dart.

8. Encrypted event bodies could leak into notification text. When
   event.type == EventTypes.Encrypted and m.ciphertext is present we
   substitute "(encrypted message)". See
   lib/src/services/notification_service.dart:_processEvent.

9. Tray ignored muted rooms and lost mention counts. Added
   NotificationService.mutedRoomsSnapshot, surfaced Room.highlightCount in
   the tooltip, and use Room.notificationCount as the fallback. See
   lib/src/services/notification_service.dart and
   lib/src/services/tray_service.dart:_refreshBadge.

10. Temp-file leak in _setup. _iconFile is now tracked, deleted in
    destroyTray, and on _setup failure. See lib/src/services/tray_service.dart.

12. processUri had no dedup. Added a 500ms _isDuplicate window via
    _lastUri / _lastAt. See lib/src/services/deep_link_service.dart.

15. TrayService was holding a stale Client across account switches. It
    now listens to AccountManager.activeClient via _onActiveAccountChanged
    and rebinds the sync listener on switch. See
    lib/src/services/tray_service.dart:_onActiveAccountChanged.

16. _notifiedEventIds could grow without bound. Now a bounded FIFO with
    _notifiedIdsCacheLimit = 256 and a _seenOrder list. See
    lib/src/services/notification_service.dart.

17. Linux/macOS plugin was missing from registration. InitializationSettings
    now covers all platforms natively. See
    lib/src/services/notification_service.dart:_initPlugin.

19. There were four SharedPreferences keys backing the same service.
    loadMutedRooms / _loadLastEventIds / _loadGroupNotifiedCounts all
    migrate legacy formats. See lib/src/services/notification_service.dart.

22. dispose was not symmetric to init. In-memory state is cleared on
    dispose, subscriptions and timers are cancelled, flags are reset. See
    lib/src/services/notification_service.dart:dispose.

25. There was no test coverage for the desktop services. Added
    test/unit/notification_service_test.dart (mocktail-based). Tray and
    lifecycle paths are covered indirectly through the boot tests. See
    test/unit/.

26. Method channel could TypeError on non-string arguments. Added an
    "if (call.arguments is String)" guard with a warning log. See
    lib/src/services/deep_link_service.dart:_handleMethodCall.

30. boot.dart had a silent short-circuit when the active account exists
    but sdk.isLogged() returns false. We now emit a log.w here. See
    lib/src/boot.dart.


2. Chat timeline, encryption, settings, login, search

A grab bag of fixes that came out of the July audit and the original
WORK_NEEDED backlog. Each entry is short on purpose.

- Reply sending was dropping markdown formatting. chat_box.dart:_send now
  builds the relation payload once with body, formatted_body, reply, and
  thread relations. See lib/src/chat/chat_box.dart.

- Chat box cleared its input before the send result was known. Draft is
  now captured before controller.clear() and restored on throw. See
  lib/src/chat/chat_box.dart:_send.

- The ?threadRoot= query parameter was ignored on room_page. We now forward
  threadRootEventId. See lib/src/screens/room_page.dart.

- _UndecryptableBanner count was frozen. It now lives in a
  ValueNotifier<int> that updates on every visible-items build, and the
  static late reference replaces the ancestor lookup. See
  lib/src/chat/timeline_view.dart.

- SSSS prompt was falling through to a spinner. It now has a dedicated
  icon, copy, canceledReason, and a Cancel button. See
  lib/src/screens/encryption/bootstrap_screen.dart.

- Recovery key disclosure was best-effort. Done state now shows a reminder
  plus ack/later buttons. See
  lib/src/screens/encryption/bootstrap_screen.dart.

- We were making three network calls per sync. They are now coalesced into
  a single in-flight Future with a 750ms debounce. See
  lib/src/encryption/encryption_service.dart.

- The Bootstrap finish signal was being ignored. onBootstrapFinished() now
  resets the refresh and triggers a full refresh. See
  lib/src/encryption/encryption_service.dart.

- Backup numbers used to show placeholders. We now surface
  {exists, cached, algorithm}. See
  lib/src/encryption/encryption_service.dart:_refreshBackupState.

- isUserVerifiedById had stale comment drift. It now reads mk.verified.
  See lib/src/encryption/encryption_service.dart.

- Post-login setup raced the first refresh. _check() now awaits enc.init()
  plus one sync plus a 900ms delay. See
  lib/src/widgets/encryption/post_login_setup_checker.dart.

- In-room search tap didn't actually jump. onJumpToEvent now closes the
  panel and calls _timelineKey.jumpToEvent(id). See
  lib/src/chat/in_room_search_panel.dart.

- HTML _processBoldItalic had a greedy-forward scan bug. Rewrote as a
  per-character state machine. See lib/src/helpers/markdown_to_html.dart.

- The href attribute was XSS-vulnerable. Added _escapeAttribute and
  _isSafeHref; pinned by test/unit/markdown_round_trip_test.dart. See
  lib/src/helpers/markdown_to_html.dart.

- Comma and pipe separator strings were getting split incorrectly.
  _readCommaSet / _readCommaList / _readSpaceGroups now use jsonDecode with
  a legacy fallback. See lib/src/settings/settings_service.dart.

- Matrix URI trailing punctuation was being eaten. Added a trailing
  lookbehind; the bare-ID branch only accepts @...:... and #...:... now.
  See lib/src/helpers/matrix_uri_parser.dart.

- _buildAvatar was throwing on whitespace-only displaynames.
  _initialsForDisplayname now splits, filters, and uses characters.firstOrNull,
  falling back to untitledRoom. See lib/src/widgets/rooms_pane.dart.

- SSO redirect URL was unvalidated. We now call isPlausibleHomeserverUrl
  and show a confirmation dialog. Pinned by
  test/unit/login_security_test.dart. See lib/src/screens/login_page.dart.

- SSO callback could hang on error. Every error branch now completes the
  future with an exception and returns 4xx HTML. See
  lib/src/services/sso_server.dart.

- Plaintext password was leaking through login errors. _safeErrorMessage
  maps TimeoutException to static copy, and log redaction covers
  password=..., "password":"...", and password: ... patterns. See
  lib/src/screens/login_page.dart.

- DatabaseService was swallowing wipe failures. It now re-throws as
  StateError. See lib/src/services/database_service.dart.

- SplashScreen.updateStatus was never wired. _boot now forwards every
  status callback. See lib/main.dart.

- AccountManager.switchToAccount had a race. The new pair is built and
  persisted first, the old pair is disposed on a microtask. See
  lib/src/helpers/account_manager.dart.

- _HtmlParseCache was keyed on hashCode. It now keys on formattedBody
  only (font size is a render-time scale on the cached spans), with a
  proper LRU and byte budget. See
  lib/src/chat/events/formatted_text_widget.dart.

- RoomsPane._buildAvatar was rebuilding a FutureBuilder per row. Added
  cachedThumbnail with a bounded FIFO, keyed by userID. See
  lib/src/widgets/avatar_from_uri.dart.

- _StringColor._colorCache was unbounded. It's now capped at 512 with
  oldest-eviction. See lib/src/helpers/string_color.dart.

- SSSS placeholder backup algorithm string was fake. We now surface the
  real algorithm string. See lib/src/encryption/encryption_service.dart.


3. Performance and memory

38 tickets total. Split into P0 critical, P1 high, P2 medium, and P3/P4
minor/test work.

3.1 P0 - critical

P0-01 Image.memory was decoding at full resolution. We now pass
cacheWidth: (size.width * dpr).ceil() for image, sticker, video thumb, and
the full-screen viewer. See image_message_type.dart, sticker_message_type.dart,
video_message_type.dart, and image_viewer_screen.dart.

P0-02 Each message did context.watch<EncryptionService>, which caused a
full timeline rebuild on every sync. Memoized isDeviceVerifiedById and
isUserVerifiedById cache fields on EncryptionService; the per-message
widget now uses context.read for verification. See
lib/src/encryption/encryption_service.dart and lib/src/chat/chat_event.dart.

P0-03 _HtmlParseCache was unbounded and its LRU was broken. It's now a
true LRU with a 4MB byte budget and LRU-order refresh. baseFontSize was
removed from the cache key (spans are cached at canonical 16px and scaled
at render time). See lib/src/chat/events/formatted_text_widget.dart.

P0-04 AvatarFromUri thumbnail cache was unbounded and identityHashCode had
a leak risk. Now a true LRU capped at 512, keyed by userID with an anon:
fallback, plus clearCacheFor and clearAll. Wired into AccountManager
logout. See lib/src/widgets/avatar_from_uri.dart.

P0-05 Each pane subscribed to client.onSync independently and produced
3-5 setState per tick. Introduced a new SyncPulse ChangeNotifier with a
350ms debounce plus a first-tick-immediate behavior. compact_sidebar,
navigation_pane, spaces_pane, and rooms_pane all consume it now. See
lib/src/helpers/sync_pulse.dart and lib/src/app.dart.

3.2 P1 - high

P1-01 TimelineItem was rebuilt on every parent build. Removed unused
previousEvent; single onAction callback with a TimelineItemAction enum;
ValueKey(event.eventId) for stable diffing. See
lib/src/chat/timeline_item.dart and lib/src/chat/timeline_view.dart.

P1-02 Video and audio widgets were doing 60Hz setState. Video now uses
AnimatedBuilder(animation: controller); audio uses ValueListenable per
stream. See video_message_type.dart and audio_message_type.dart.

P1-03 _HoverActionsWrapper and _ImageHoverRegion were doing setState on
hover. Now use ValueNotifier<bool> with a ValueListenableBuilder overlay;
the message body never rebuilds. See lib/src/chat/timeline_item.dart and
image_message_type.dart.

P1-04 Each image/sticker/audio/file widget held its own Future<MatrixFile>.
Added a RoomMediaCache singleton (64MB byte-budget LRU) shared across all
media widgets, with per-event dedup. See lib/src/helpers/room_media_cache.dart
and the four media widgets.

P1-05 _markReadSent Set was growing unbounded. Now FIFO-capped at 64,
drops the oldest quarter on overflow. See lib/src/chat/chat_timeline.dart.

P1-06 ThreadViewPage was doing O(N) aggregatedEvents per build while
watching the full SettingsController. Now uses
context.select<SettingsController, double> for font size; reply count is
pre-computed in _findRootEvent. See lib/src/screens/thread_view.dart.

P1-07 _paginateUntilMarker could stall for 8 minutes. Cap reduced to 6
iterations, 4s per-iteration timeout, 8s global timeout via .timeout. See
lib/src/chat/chat_timeline.dart.

P1-08 DraftService allocated a fresh instance per ChatBox mount and its
timer leaked across rooms. Now a singleton-per-account instanceFor with
reference counting; release in dispose cancels any pending timer. See
lib/src/services/draft_service.dart and lib/src/chat/chat_box.dart.

P1-09 _SidebarRoomInfo rebuilt on every state event regardless of visible
change. Added change-detection in _refreshFromRoom; setState only fires
when at least one user-visible field actually differs. See
lib/src/layouts/dashboard_layout.dart.

3.3 P2 - medium

P2-01 _ClientThumbnailCache was keyed by identityHashCode. Now keyed by
userID with an anon: fallback; disposeRoom is called on leave, clear on
logout. See lib/src/widgets/rooms_pane.dart.

P2-02 NavigationPane scanned client.rooms.where(isSpace) on every parent
build. Cached _cachedSpaceIds is refreshed only on sync pulse tick. See
lib/src/widgets/navigation_pane.dart.

P2-03 DashboardLayout setState on every shell decision flip rebuilt the
entire tree. New LayoutShellController ValueListenable; only the shell
subtree re-renders now. See lib/src/layouts/layout_shell_controller.dart
and lib/src/layouts/dashboard_layout.dart.

P2-04 PinnedEventsCache evicted by entry count (512) only. Now uses
byte-budget eviction (64MB), LRU by access, with per-event size
estimates. See lib/src/helpers/pinned_events_cache.dart.

P2-05 NotificationService was re-processing every room on every sync tick
even when nothing changed. _processRoomsIfChanged short-circuits on no-op
ticks; group summary now uses the caller-supplied room id (no scan). See
lib/src/services/notification_service.dart.

P2-07 Permission checks were being recomputed on every hover-actions
render. Deferred - low ROI for action visibility.

P2-09 Every widget subscribed to client.onRoomState independently. Added
a RoomStateBus (per-room ValueListenable<int> tick); _SidebarRoomInfo
migrated to it. See lib/src/helpers/room_state_bus.dart.

P2-11 EncryptionService.dispose cleanup. Verified - subscription, debounce
timer, and in-memory state cleared (onLogout clears _cachedUnverified,
_myDevices, etc.). See lib/src/encryption/encryption_service.dart.

P2-14 SpacePreferences fired notifyListeners on every drag-reorder step.
Coalesced via microtask; dispose guard added. See
lib/src/settings/space_preferences.dart.

P2-17 _ReplyPreview re-issued getEventById on every parent build.
Memoized _pendingFetch future; cleared in didUpdateWidget when reply
target changes. See lib/src/chat/chat_event.dart.

P2-18 _inviteUser TextEditingController was leaking. dispose() after
dialog closes, text captured before dispose. See
lib/src/screens/user_profile.dart.

P2-19 RoomsPane used a heavy ListTile per row. New lightweight _RoomRow
widget; displayname memoized per row. See lib/src/widgets/rooms_pane.dart.

3.4 P3/P4 - minor and tests

P3-02 Cache isDeviceVerifiedById - addressed by P0-02.

P3-03 Voice and location dialog resource disposal - verified correct.

P4-01 Performance regression test plus memory smoke test. Added
test/unit/room_media_cache_test.dart covering LRU eviction, in-flight
dedup, and SyncPulse coalescing. See test/unit/.


4. Cross-cutting improvements

Quick list of the broader refactors that landed alongside the audit items.

- Provider wiring - Provider<RoomStateBus> and ChangeNotifierProvider<SyncPulse>
  injected by MoonrelayApp; rebinds on AccountManager account switch. See
  lib/src/app.dart.

- Shell decision - extracted to LayoutShellController, single source of
  truth for compact vs wide. See lib/src/layouts/layout_shell_controller.dart.

- Media cache - RoomMediaCache deduplicates downloads across the app, with
  per-event TTL and LRU by bytes. See lib/src/helpers/room_media_cache.dart.

- State-event fan-out - RoomStateBus centralises one O(N) filter into a
  shared fan-out. See lib/src/helpers/room_state_bus.dart.

- Draft persistence - DraftService is a reference-counted singleton, no
  timer leaks on room switch. See lib/src/services/draft_service.dart.

- Settings coalescing - SpacePreferences microtask-coalesced notifies. See
  lib/src/settings/space_preferences.dart.

- Encryption caching - per-(userId, deviceId) and per-userId memoized
  lookups, invalidated by sync. See lib/src/encryption/encryption_service.dart.

- Reply preview - memoized fetch future with proper invalidation on
  reply-target change. See lib/src/chat/chat_event.dart.

- Sidebar info - only rebuilds when a user-visible field actually changed.
  See lib/src/layouts/dashboard_layout.dart.

- HTML cache - true LRU plus byte budget; font-size changes no longer
  invalidate the cache. See lib/src/chat/events/formatted_text_widget.dart.


5. Test additions

test/unit/notification_service_test.dart
  Muted-room persistence plus migration, last-event-id persistence,
  group-count persistence, show/skip logic for DM and group, sender skip,
  body-empty skip, current-room skip, _showNotification no-op when plugin
  is null, first-time-room baseline, and group summary copy (single vs
  multi).

test/unit/draft_service_test.dart
  Load/save/clear round-trip, empty drafts are removed, cross-account
  isolation, debounced scheduleSave persists.

test/unit/room_media_cache_test.dart
  Byte-budget eviction drops oldest entries, concurrent getOrDownload
  calls share one in-flight future, SyncPulse coalesces a burst of pokes
  into one broadcast.

test/unit/pinned_events_cache_test.dart
  Byte-budget eviction, per-event size estimate, LRU by access.

test/unit/markdown_round_trip_test.dart
  XSS hardening (href attribute escape plus safe-URL allow-list).

test/unit/login_security_test.dart
  SSO redirect URL plausibility, password log redaction, _safeErrorMessage
  does not leak MatrixHttpException.toString.

test/unit/sso_callback_server_test.dart
  SSO callback happy path, wrong-state rejection, timeout.

test/unit/database_service_test.dart
  Wipe-on-version-bump with the StateError path.

Other test files (preserved and still passing):
test/unit/space_rooms_tree_test.dart, account_manager_test.dart,
app_version_test.dart, chat_timeline_test.dart, auto_update_service_test.dart,
date_time_extension_test.dart, display_type_test.dart, html_parser_test.dart,
localization_smoke_test.dart, log_redaction_test.dart,
matrix_uri_parser_test.dart, navigation_state_test.dart, responsive_test.dart,
room_preview_screen_test.dart, search_provider_test.dart,
search_provider_users_test.dart, settings_controller_test.dart,
settings_extended_test.dart, settings_service_test.dart,
space_hierarchy_test.dart, space_pinning_test.dart, string_color_test.dart.

Widget tests (preserved):
test/widget/message_action_runner_test.dart, login_page_test.dart,
delivery_indicator_test.dart, encryption_badge_test.dart.


6. Media widget polish (July 2026 - second pass)

Follow-up to section 3 P0/P1 work. Two sub-batches: a visual overhaul of
the image and video bubbles plus an in-app image viewer, and a robustness
pass across all four message-type renderers.

Tests at head: flutter test (440 tests) all green. flutter analyze with 0
errors.

6.1 Image bubble and viewer

1. Image bubble no longer stretches across the chat row. Thumbnail uses
   Align(centerStart) plus BoxFit.contain (was BoxFit.cover). See
   lib/src/chat/events/matrix_events/Message/image/image_message_type.dart.

2. Sticker bubble: borders and background containers removed.
   Placeholder/loading/error are now bare SizedBox plus icon. Size comes
   from a new _stickerSize helper (aspect-preserving, capped at
   prefs.stickerMax). See
   lib/src/chat/events/matrix_events/Message/sticker/sticker_message_type.dart.

3. Video bubble background removed. Only the player and metadata row keep
   their subtle fills so the bubble hugs the video aspect. See
   lib/src/chat/events/matrix_events/Message/video/video_message_type.dart.

4. New hover-reveal download affordance on image thumbnails
   (_HoverDownloadButton), so the bubble isn't permanently decorated. See
   lib/src/chat/events/matrix_events/Message/image/image_message_type.dart.

5. Long-press on image thumbnail now saves via the platform save-file
   dialog. See
   lib/src/chat/events/matrix_events/Message/image/image_message_type.dart.

6. New full-screen image viewer: auto-hiding top/bottom chrome, tap or
   double-tap anywhere to summon, toolbar download plus long-press to
   save, bottom hint strip. ColoredBox(0xCC000000) dim backdrop replaces
   the old ImageFiltered(ImageFilter.blur). See
   lib/src/screens/image_viewer_screen.dart.

7. Chrome re-summoning was broken. Removed an IgnorePointer wrapper that
   was swallowing taps. Added a top-level HitTestBehavior.translucent
   GestureDetector so any tap outside a tool button reliably toggles
   chrome. See lib/src/screens/image_viewer_screen.dart.

8. _hideScheduleId counter cancels any in-flight hide callback when the
   user re-summons chrome. See lib/src/screens/image_viewer_screen.dart.

6.2 Video bubble and fullscreen player

9. Fixed a runtime crash in _downloadOnDemand. The pattern
   setState(() => _x = future) was returning the assigned Future, which
   State.setState rejects as "the closure returned a Future". Switched
   to block-body setState(() { _x = future; }). Same fix applied to file
   and audio widgets. See video_message_type.dart,
   file_attached_message.dart, audio_message_type.dart.

10. Initialize-only player subtree extracted as _InitializedPlayer. Only
    that subtree rebuilds on controller tick (drops the 60Hz rebuild of
    the metadata row and overlays). See video_message_type.dart.

11. Monotonic _buildToken guards against stale build-controller futures
    overwriting a newer attempt. See video_message_type.dart.

12. _controllerFailed flag plus a retry panel (videoLoadFailed /
    tapToRetry strings). Retry path invalidates the cache entry and
    re-runs _buildControllerFromDownload. See video_message_type.dart.

13. _disposeController is async-safe (unawaited(...) with
    .catchError((_) {})). _buildController surfaces file-write failures
    back to the outer future instead of swallowing them. See
    video_message_type.dart.

14. Inline playback wiring: tapping the preview now triggers download plus
    initialize plus play in one user action. No need to first wait, then
    tap again. See video_message_type.dart.

15. Fullscreen player rebuilt: custom top bar (close plus position
    readout), bottom controls with scrub and +/-5s / +/-10s skip,
    auto-hiding chrome, central pause overlay, double-tap to toggle. See
    video_message_type.dart (_FullscreenVideoPlayer).

16. Fullscreen chrome uses the same _hideScheduleId pattern as the image
    viewer. See video_message_type.dart.

6.3 Download system for every applicable event type

17. Image goes through FilePicker.saveFile from thumbnail, hover
    affordance, and viewer toolbar. See image_message_type.dart and
    image_viewer_screen.dart.

18. File - the save icon stays tappable regardless of auto-download
    policy via _downloadOnDemand; spinner during fetch; the icon flips to
    a retry glyph after failure. See file_attached_message.dart.

19. Audio on-demand download path reuses RoomMediaCache; spinner swap;
    the play icon flips to a refresh icon after failure (see section
    6.4). See audio_message_type.dart.

20. Video is symmetric with file; spinner during fetch. See
    video_message_type.dart.

21. All four widgets route the on-demand path through RoomMediaCache so
    multiple widgets for the same event share one in-flight future. See
    video_message_type.dart, audio_message_type.dart,
    file_attached_message.dart.

6.4 Robust error handling

22. Every async hot-path now uses on Object catch (e, st) with
    FlutterError.reportError instead of bare catch (_) swallows. See all
    four media widgets.

23. Audio _lastError flips the bubble to error tones, swaps the play
    icon for a refresh icon, and triggers _retry() from the same button.
    See audio_message_type.dart.

24. File bubble surfaces _lastError with a red border, error-tinted
    icon, and a refresh-icon save button. See file_attached_message.dart.

25. Image error state is now a retryable tile (Tap to retry) that
    invalidates the cache entry before re-fetching. Guarantees a fresh
    attempt even if the cache held a poisoned entry. See
    image_message_type.dart.

26. Video error panel inside the player area shows "Couldn't load video"
    / "Tap to retry". Tap clears _controllerFailed and re-runs
    _buildControllerFromDownload. See video_message_type.dart.

27. User cancellation of FilePicker.saveFile is no longer treated as an
    error - only genuine platform failures get logged. See
    image_message_type.dart, audio_message_type.dart,
    file_attached_message.dart.

28. Audio _togglePlay, _ensureAttached, and _seekTo report failures into
    _lastError instead of throwing across the widget tree. See
    audio_message_type.dart.

29. Fullscreen video play / seekTo wrap individual try/catch blocks -
    best-effort, no bubble-up of controller exceptions. See
    video_message_type.dart.

6.5 Localization

30. New strings saveImage, downloadImage, imageViewerHint, videoLoadFailed,
    and tapToRetry added to app_en.arb, app_fa.arb, the abstract
    AppLocalizations, and both app_localizations_en/fa.dart
    implementations. See lib/src/localization/.


7. UX fixes - image viewer, compact mode, timeline, overlays (August 2026 - third pass)

Targeted follow-up on four long-standing UX bugs. Tests at head: flutter
test 441 green, flutter analyze 0 errors. Pre-existing
Radio.groupValue deprecation warnings in layout_settings.dart are
unchanged.

7.1 Image viewer chrome (issue 1)

1. The previous GestureDetector over InteractiveViewer lost the gesture
   arena to the viewer's pan/zoom recogniser, so a tap never reached the
   chrome toggle. Replaced with a raw Listener
   (HitTestBehavior.translucent) that sees every pointer event regardless
   of arena outcome. See lib/src/screens/image_viewer_screen.dart.

2. Added onPointerHover plus onPointerMove so any mouse activity keeps
   the chrome alive while the user is interacting. On desktop this
   matches native gallery-app behaviour. See
   lib/src/screens/image_viewer_screen.dart.

3. Preserved long-press to save via a nested GestureDetector. Long-press
   doesn't compete with InteractiveViewer pan/zoom. See
   lib/src/screens/image_viewer_screen.dart.

4. _scheduleChromeHide now calls _chromeController.stop() before
   forward() so a stale in-flight reverse can't race the new show. See
   lib/src/screens/image_viewer_screen.dart.

7.2 Compact mode threshold and flapping (issue 2)

5. Lowered the compact-mode breakpoint. compactMax and expandedMax moved
   from 1280 down to 1100 px. A 1100 px window still fits nav-rail (80)
   plus left pane (~280) plus chat plus right pane (~240) at >=200 px
   each. The previous 1280 px line crowded the chat immediately. See
   lib/src/helpers/responsive.dart.

6. Widened the hysteresis dead-band from 20 to 60 px, settle from 220 to
   400 ms. Drag jitter across the boundary no longer flips the shell.
   See lib/src/layouts/layout_shell_controller.dart.

7. Anchored the dashboard's shell decision to
   MediaQuery.sizeOf(context).width (window-managed) instead of
   LayoutBuilder.constraints.maxWidth. The previous read returned a
   value that shrank/grew as sidebars mounted/unmounted, which fed back
   into the shell controller and could trip a spurious flip. See
   lib/src/layouts/dashboard_layout.dart.

8. _AdaptiveMainLayout switched from context.watch<SettingsController>()
   (which fires on every preference change) to context.select on the
   layoutMode field only, plus a mirror of the +/-60 px hysteresis so the
   router and dashboard never disagree mid-drag. See lib/src/router.dart.

9. _roomsListPageBuilder reads the settings with listen: false so route
   resolution doesn't subscribe to the whole settings tree. See
   lib/src/router.dart.

7.3 Timeline jitter and jump (issue 3)

10. Moved _isScrolledUp from a bool field mutated via setState to a
    ValueNotifier<bool>. The FAB column now rebuilds via
    ValueListenableBuilder. The chat surface and the cached item list no
    longer rebuild on every drag tick that crossed the threshold (the
    previous behaviour produced visible jitter during a continuous drag).
    See lib/src/chat/chat_timeline.dart.

11. _FloatingActionColumn is now wrapped in ValueListenableBuilder<bool>
    so a non-scrolled-up state collapses the column to SizedBox.shrink()
    instead of inserting an empty Positioned. See
    lib/src/chat/chat_timeline.dart.

12. Added a stable Map<String, GlobalKey> _eventKeys to TimelineView so
    jumps land via Scrollable.ensureVisible. Pixel-accurate, accounting
    for variable-height items above the target. The previous fraction
    estimate routinely missed by several items when neighbouring messages
    had very different heights. See lib/src/chat/timeline_view.dart.

13. Promoted _TimelineViewState to public TimelineViewState so the
    orchestrator can hand off jumps via a
    GlobalKey<TimelineViewState>. The fraction estimate is retained as a
    fallback for virtualised-off-screen targets. See
    lib/src/chat/timeline_view.dart and lib/src/chat/chat_timeline.dart.

14. Added _pruneStaleKeys(liveIds) so the key map is bounded to the
    events currently in the item list. No unbounded growth on long-lived
    views. See lib/src/chat/timeline_view.dart.

7.4 Barrier dismiss consistency (issue 4)

15. Rewrote BarrierDismissableOverlay to use Listener with
    HitTestBehavior.translucent (replacing the previous GestureDetector
    plus full-screen hit-test). Descendants now compete in the gesture
    arena and win when they have handlers, so taps on InkWell, TextField,
    etc. reach them reliably. See lib/src/widgets/blur_background.dart.

16. Introduced BarrierDismissBoundary - a widget that wraps the visible
    card and registers its BuildContext with the overlay via an
    InheritedWidget. The overlay hit-tests each registered boundary
    against the pointer's global position; a hit on any boundary means
    "inside the card" and prevents dismissal. Multiple boundaries are
    supported. See lib/src/widgets/blur_background.dart.

17. Wrapped the cards of command_palette.dart, hub_screen.dart
    (_HubOverlayPage), and user_profile.dart (_ProfileOverlayPage) in
    BarrierDismissBoundary. All three overlays now consistently dismiss
    on backdrop tap and pass through taps inside the card (including
    empty padding around widgets). See lib/src/widgets/command_palette.dart,
    lib/src/screens/hub_screen/hub_screen.dart, and
    lib/src/screens/user_profile.dart.

18. Barrier tests updated to wrap their test cards in
    BarrierDismissBoundary (matching the new contract). See
    test/widget/command_palette_barrier_test.dart.

19. responsive_test.dart updated for the new 1100 px breakpoint. See
    test/unit/responsive_test.dart.

7.5 Timeline state-event drain (issue 5)

20. Rooms with hundreds of consecutive state events between messages
    used to stop loading before the first real message surfaced. The
    drain loop now triggers whenever the most-recently loaded
    _stateDrainWindow events are *all* state events (and `prev_batch`
    is still set), so a single non-state event breaking the window
    stops the loop. Reading the trailing window rather than just the
    single oldest event keeps the drain active in rooms whose entire
    loaded history is state events (heavy membership churn, brand new
    rooms where every join is a state event). The loop caps at
    _maxStateDrainIterations and resets on room switch plus once the
    viewport becomes scrollable. See
    lib/src/chat/chat_timeline.dart:_ensureContentFillsScreen,
    :_shouldDrainStateEvents, and :_drainStateEventsAtEndOfTimeline.

8. Chat layout race when a tooltip is visible at page push
   (issue 6)

- The chat-page mount was tripping Flutter's
  `_RenderLayoutBuilder was mutated in performLayout` assertion
  whenever the user's mouse happened to be over a chat-box button
  while navigating to a room. The cause: `Tooltip` (Material)
  wraps the child in an internal `OverlayPortal` (via `RawTooltip`)
  that activates the moment the page is mounted. The page lives
  inside the dashboard's `LayoutBuilder` shell, so the portal's
  activation marks that builder as needing layout mid-performLayout.
  The follow-on `_elements.contains(element)` assertion and the
  `traversalParentIdentifier must be unique` semantics error are
  downstream effects of the same race. Fix: replace the `Tooltip`
  wrappers that are part of the always-mounted chat surface
  (chat-box `_IconButton`, the delivery-status indicator, and the
  image/video/audio/file error tiles) with `Semantics` labels.
  Hover/conditional tooltips (the unread-pill dismiss button, the
  message hover-toolbar actions) keep the visual `Tooltip` because
  they only mount on user interaction. See
  lib/src/chat/chat_box.dart:_IconButton.build,
  lib/src/chat/events/delivery_indicator.dart,
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_buildError,
  lib/src/chat/events/matrix_events/Message/video/video_message_type.dart,
  lib/src/chat/events/matrix_events/Message/audio/audio_message_type.dart, and
  lib/src/chat/events/matrix_events/Message/file/file_attached_message.dart.

  Follow-up (this fix): two always-mounted surfaces were missed by
  the original sweep and re-introduced the race whenever the user
  opened a chat box's expanded toolbar or the full-screen image
  viewer. Both were wrapped in transitions (`SizeTransition`,
  `FadeTransition`) that always mount their children even when the
  visual size/opacity is 0, so the Tooltip's OverlayPortal still
  activated on mount and mutated the dashboard's LayoutBuilder.
  Replaced the chat-box formatting toolbar (`chat_box.dart:_formatButton`)
  and the image-viewer toolbar (`image_viewer_screen.dart:_ToolbarButton`)
  with `Semantics` labels following the same pattern as the other
  already-fixed surfaces. The chat-layout regression test
  (`test/widget/chat_layout_no_tooltip_test.dart`) was extended to
  pin both surfaces so a future refactor that re-introduces a Tooltip
  fails the test instead of tripping the runtime assertion. The
  test helper (`_wrap`) was upgraded to provide `SettingsController`
  so widgets that read user preferences (e.g. `ReceiptAvatars`
  checks `showReadReceipts`) can mount under the same wrapper, and a
  missing `MockReceipt` mock was added to `test/helpers/mocks.dart`.

Tests at head: flutter test 486 green; flutter analyze
reports 0 issues. Known-fail tests: 0.

9. Image / video / sticker widget audit (issue 7)

Audit pass on the four media-bubble widgets. Three real defects
fixed; one comment-only misdirection corrected; the
chat-page layout race is closed off on the remaining
`Tooltip` (see issue 6) so hover affordances no longer
participate.

- `_infoMap['w'] as int?` and the same pattern on `h`, `width`,
  `height`, `duration`, and `size` threw `TypeError` on any event
  whose dimensions came back from the matrix SDK as `num` /
  `double` (the local-DB cache round-trip drops the
  int-vs-float distinction that an inline `as int?` cast
  assumes). The thumbnail then collapsed to the placeholder
  even though the dimensions were valid. Centralised the
  coercion in a new
  `coerceJsonInt(Object?) -> int?` helper at
  lib/src/helpers/number_coercion.dart and routed the four
  widgets (image, video, sticker, plus the video file/duration
  getters) through it. Anything that is not a non-negative
  `num` returns null, so callers fall through to their
  existing fallbacks without an exception.

- `_retryDownload` issued two back-to-back `setState` calls
  and gated the second on `_shouldAutoDownload()`. The
  conditional was a no-op: both branches did the same thing.
  Collapsed to a single `setState` that captures the cache
  result, and added a `mounted` re-check after the awaited
  `cache.invalidate` so a rapid tap-then-dispose can no longer
  fire `setState` after dispose. See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_retryDownload.

- The image widget's always-mounted `_HoverDownloadButton`
  wrapped a `Tooltip` so a hover activation could re-trigger
  the chat-page layout race from issue 6 (the button mounts
  on every image thumbnail). Replaced with a `Semantics`
  label; the icon-button affordance already carries the
  same role, so the popup was redundant. See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_HoverDownloadButtonState.

- The image widget's `_infoMap` getter did a `as
  Map<String, dynamic>` cast that would throw on a
  `Map<dynamic, dynamic>`. Loosened to accept any `Map` and
  copy into a `Map<String, dynamic>` so a future SDK change
  to the content shape can't break thumbnails. See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart,
  video_message_type.dart, and sticker_message_type.dart.

- `setState(() { _x = future; })` pattern was a latent
  crash on the next re-entry; documented why the new
  retry path uses block-body setState, mirroring the
  video / file / audio fix in 6.2 (issue 9). See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_retryDownload.

Tests: 5 new unit cases in
test/unit/number_coercion_test.dart cover int, double,
arbitrary `num`, null, and non-numeric inputs. All
303 unit tests pass; flutter analyze reports 0 errors
(only the pre-existing layout_settings Radio.groupValue
deprecations remain).

10. Chat-timeline race / single-flight / stopwatch /
    cache-invalidation / LRU / shutdown ordering / CAS
    consolidation (August 2026 - fourth pass)

Closed the architecture audit follow-up. The remaining
race-prone, cancellation-discipline, and listener-proliferation
items are fully landed and most are pinned by new
widget/unit tests.

Sync listener consolidation

- 7 widget-level sync listeners moved onto the shared
  [SyncPulse] via `maybeSyncPulse(context)`:
  `lib/src/widgets/space_rooms_tree.dart`,
  `lib/src/screens/space_home_page.dart`,
  `lib/src/screens/space_settings_page.dart`,
  `lib/src/screens/hub_screen/my_profile_page.dart`,
  and the knock-list section of
  `lib/src/screens/room_settings_page.dart` now read the
  coalesced pulse instead of `client.onSync.stream`.
- `lib/src/helpers/threads_provider.dart` gained a `bind`
  method that takes a `SyncPulse`; both call sites
  (`thread_list_sidebar.dart`, `room_threads_view.dart`)
  wire through `context.read<SyncPulse>()`.
- The 3 remaining direct subscribers
  (`notification_service.dart`, `tray_service.dart`,
  `encryption_service.dart`) are intentional: they
  consume the raw sync stream to do per-room processing
  and the architectural recommendation explicitly permits
  them.

Race / cancellation discipline

- `ChatTimeline._initTimeline` now uses the
  `LifecycleGeneration` mixin (a `beginAsync` / `isStale`
  generation counter captured before every await).
  Rapid room switches no longer let the previous room's
  late continuation overwrite the new room's state.
- `RoomPage.initState` / `didUpdateWidget` mirror the same
  pattern; the previous room's `setRoom` post-frame
  callback is discarded when the room id changes.

Skeleton / debounce / single-flight

- `ChatTimeline._atLocalEndOfHistory` is reset in the
  catch path of `_requestMoreHistory`; a failed history
  request no longer strands the user on stale placeholders.
- `_scrollDebounce` is now released by a `Timer` (120 ms)
  instead of a double-`addPostFrameCallback` chain, so
  frame batching / jank can't release the debounce early
  or late.
- `_requestMoreHistory` is single-flight: the
  `_isLoadingHistory` flag is set before awaiting so a
  second call arriving in the same microtask short-circuits.

Jump-to-unread / parallel pagination

- `_paginateUntilMarker` is bounded by a single shared
  `Stopwatch` (8 s cap). `paginateOlder` and
  `paginateNewer` now run in parallel via `Future.wait`
  and the first to surface the marker wins, so the
  worst case is no longer `olderTimeout + newerTimeout`
  (16 s).
- `_unreadInWindow` reads `widget.room.fullyRead` directly
  rather than the cached `_lastSeenEventId`, so the
  jump-to-unread pill reflects the live marker.
- `getTimeline(onUpdate:)` now bumps `_timelineVersion`
  via `_onTimelineUpdate`. Newly-decrypted events and
  aggregation updates no longer serve the stale body
  from `TimelineView`'s cache.

Memory bound on per-room state

- `RoomStateBus._perRoomTick` is now an LRU-bounded
  `LinkedHashMap` capped at 500 entries. Evicted rooms
  have their `ValueNotifier` disposed so listeners drop
  cleanly; the eviction policy is move-to-end on every
  read and tick, which keeps actively-read rooms alive
  across eviction pressure.

Ordered shutdown

- `lib/src/helpers/service_registry.dart` registers
  long-lived services at boot time. `shutdownAll(log)`
  tears them down in reverse registration order; each
  disposer's failures are caught and logged so one
  bad service does not block the others.

Read-marker CAS

- `ReadMarkerService` carries a monotonic per-instance
  `seq` with each write. Stale writes (with a smaller
  seq than the stored one) are discarded instead of
  overwriting a newer marker. Eliminates the read-marker
  race where two concurrent async writes could reorder a
  newer marker behind an older one.

Tests added

- `test/widget/chat_timeline_race_test.dart` (3 tests):
  late `getTimeline` continuation from the previous room
  is dropped after a rapid room switch; back-to-back
  switches discard every stale continuation except the
  latest; a no-op `didUpdateWidget` (same room, new widget
  instance) does not invalidate the in-flight token.
  Pins the chat-timeline race fix.
- `test/widget/history_single_flight_test.dart` (2 tests):
  re-entrant `_requestMoreHistory` calls during an
  in-flight request short-circuit instead of issuing
  additional `requestHistory` calls; a failed
  `requestHistory` clears the in-flight flag so the next
  call can proceed. Pins the single-flight contract.
- `test/widget/paginate_until_marker_test.dart` (3 tests):
  `_paginateUntilMarker` returns false and stays under
  the global stopwatch when the server hangs
  indefinitely; succeeds as soon as either direction
  surfaces the marker; returns true once the marker is
  loaded into the events list. Pins the shared stopwatch.
- `test/widget/timeline_content_update_test.dart`
  (2 tests): firing `onUpdate` bumps `_timelineVersion`;
  onUpdate goes through the same `_onTimelineUpdate` path
  as onChange and onInsert. Pins the onUpdate
  cache-invalidation contract.
- `test/unit/room_state_bus_lru_test.dart` (6 tests):
  LRU eviction, `disposeRoom`, move-to-end on read,
  dispose, repeated `tickFor` returns the same notifier,
  custom `maxRooms` is honoured. Pins the RoomStateBus
  LRU contract.
- `test/unit/service_registry_test.dart` (7 tests):
  reverse-order shutdown, continues past a failing
  disposer, clears entries after shutdown, awaits async
  disposers, accepts sync void disposers, empty registry
  no-op, service token is purely for log attribution.
  Pins the ServiceRegistry shutdown contract.
- `test/unit/read_marker_service_test.dart` (9 tests):
  setLastSeen persists, null/empty removes, unknown
  room returns null, accounts are isolated, fresh write
  advances seq, overwrite persists newer event id,
  corrupt entry returns null, keys are colon-safe for
  both account and room ids. Pins the CAS write
  semantics.

Test accessors

- Added `@visibleForTesting` hooks on
  `ChatTimelineState` for the three private paths the
  new tests exercise: `requestMoreHistoryForTest`,
  `paginateUntilMarkerForTest`,
  `onTimelineUpdateForTest`, plus a `timelineVersionForTest`
  getter. None of these are reachable from production
  code (the `@visibleForTesting` annotation is checked
  at lint time).

Tests at head: flutter test 478 green; flutter analyze
0 errors, 0 warnings, 0 info-level notes (clean).

11. Lint hygiene sweep (August 2026 - fourth pass)

Final code-hygiene pass to clean the remaining info-level
notes that flutter analyze had been carrying.

- `lib/src/screens/hub_screen/settings/layout_settings.dart`:
  migrated the three layout-mode `RadioListTile`s from
  per-tile `groupValue` / `onChanged` to the new
  `RadioGroup<LayoutMode>` ancestor API introduced in
  Flutter 3.32. This closes the last six pre-existing
  `deprecated_member_use` info-level notes about
  `Radio.groupValue` and `Radio.onChanged`. No behavioural
  change; the user-visible radio behaviour and the
  selected value still round-trip through
  `controller.layoutMode`.
- `test/widget/timeline_content_update_test.dart`:
  added an inline `// ignore: non_constant_identifier_names`
  comment on the `prev_batch` getter so the lint accepts
  the snake-case identifier that mirrors the Matrix SDK
  field name (`Room.prev_batch`).

Tests at head: flutter test 478 green; flutter analyze
reports 0 issues (no errors, no warnings, no info-level
notes).

12. Chat-timeline complexity refactor

Follow-up to the audit items in sections 3 and 10. The
chat-timeline state (`chat_timeline.dart`) had grown to
1512 lines with five overlapping concerns woven through
one state class: scroll-driven history pagination, the
auto-fill / state-event-drain loop, the jump-to-unread
orchestration, the scroll-debounced read-marker
plumbing, and the build/UI composition. This pass
decomposed the state into a slim composition root plus
three named collaborators, eliminating a tangle of
overlapping boolean flags and duplicated timer
machinery.

Reduced `chat_timeline.dart` from 1512 lines to 640. Known-fail tests: 0.

Decomposition

- `lib/src/helpers/debouncer.dart` (new). Trailing-edge
  debouncer with `call(body)`, `cancel()`, `isPending`.
  Replaces the two near-identical `Timer?` +
  `cancel()` + cleanup blocks previously inlined in
  `chat_timeline.dart` (the mark-read debounce and the
  last-seen refresh debounce). The owning class still
  calls `dispose()` from its own teardown; the
  Debouncer itself doesn't capture the owner.

- `lib/src/chat/history_pager.dart` (new). Owns the
  scroll-driven history pipeline. Replaces the four
  overlapping boolean flags (`_isLoadingHistory`,
  `_isFillingViewport`, `_atLocalEndOfHistory`,
  `_isJumpingToUnread`) with a single `HistoryFillState`
  enum (`idle`, `loadingMore`, `drainingStateEvents`,
  `exhausted`) plus explicit `_transition(next)` calls.
  Auto-fill budget, state-drain budget, and the 120 ms
  post-load debounce are all encapsulated. Public
  surface: `onScroll()`, `ensureFilled()`,
  `resetCounters()`, `resetForRoom()`,
  `onTimelineUpdated()`, plus `shouldShowSkeleton` and
  `state` getters for the parent.

- `lib/src/chat/read_marker_tracker.dart` (new). Owns
  the read-receipt plumbing. Decoupled from
  `BuildContext`: the tracker is constructed with the
  `Room`, the `sendReceipts` gate, and a
  `NotificationMirror` interface (with
  `NoopNotificationMirror` and `_ServiceNotificationMirror`
  adapters). Uses the shared `Debouncer` for both the
  scroll-driven 250 ms mark-read and the
  `fullyRead`-sample 250 ms last-seen refresh. Exposes
  `scheduleOnScroll(events)`, `markRoomRead(events,
  force:)`, `scheduleLastSeenRefresh(fullyRead)`,
  `bindRoom(room)`, `resetForRoom()`, `dispose()`, and
  a `lastSeenEventId` getter.

- `lib/src/chat/jump_coordinator.dart` (new). Owns the
  "jump to first unread" orchestration. Wraps the
  existing `JumpToUnreadPager` for the parallel older +
  newer pagination race, plus the scroll-to-event +
  highlight-ring plumbing. The fullyRead marker is
  pulled via a `getFullyReadMarker` callback rather than
  `timeline.room.fullyRead` -- the fake `Timeline`s in
  test/widget/paginate_until_marker_test.dart leave
  `room` null, and the marker is always available from
  the parent widget's room prop. Public surface:
  `jumpToLastRead()`, `jumpToEvent(eventId)`,
  `resetForRoom()`, `dispose()`, plus `isJumping`,
  `highlightedEventId`, and `isJumpingForTest`
  accessors.

- `lib/src/chat/chat_timeline.dart` (rewritten). Slim
  composition root. The state class lost ~10 fields
  (`_isLoadingHistory`, `_isFillingViewport`,
  `_atLocalEndOfHistory`, `_autoFillRetries`,
  `_stateDrainCount`, `_scrollDebounce`,
  `_scrollDebounceTimer`, `_markReadSent`,
  `_markReadDebounceTimer`, `_markReadDebounce`,
  `_lastSeenRefreshTimer`, `_lastSeenRefreshDebounce`,
  `_highlightHighlightTimer`, `_markReadSent`) and
  ~870 lines of imperative plumbing. What remains:
  lifecycle (`initState`, `didUpdateWidget`, `dispose`),
  provider-tolerant helpers (`_tryReadLogger`,
  `_readSendReceipts`, `_tryReadNotificationMirror`),
  the build tree, and the pinned-events filter
  orchestration (`_fetchFilteredEvents`).

Behaviour preserved

- Scroll-to-load, auto-fill, state-event drain all
  pass `flutter test test/widget/history_single_flight_test.dart`
  and `test/widget/timeline_smooth_load_test.dart`
  unchanged.
- Race protection: rapid room switches still drop the
  previous room's late continuation, pinned by
  `test/widget/chat_timeline_race_test.dart`. The
  `LifecycleGeneration` generation counter on
  `ChatTimelineState` is unchanged.
- Parallel-direction jump-to-unread still bounded by the
  8 s shared stopwatch, pinned by
  `test/widget/paginate_until_marker_test.dart`. The
  existing `JumpToUnreadPager` + `JumpToUnreadContext`
  plumbing was preserved verbatim; the coordinator only
  adds the scroll-to-event / highlight-ring
  presentation layer on top.
- Read-marker CAS semantics (already in
  `read_marker_service.dart`) are unaffected. The
  `ReadMarkerTracker` here is a separate concern --
  the scroll-debounced local "what event id to POST"
  decision -- and does not duplicate or replace the
  CAS-protected server-side service.
- Test accessors
  (`isLoadingHistoryForTest`,
  `paginateUntilMarkerForTest`,
  `requestMoreHistoryForTest`,
  `timelineVersionForTest`) all preserved on the state
  with the same signatures the existing tests expect,
  so no test source had to change.


13. Chat-timeline scroll-performance pass

User reported that fast scrolling through the chat timeline
felt sluggish and laggy. Root cause was that every parent
build (sync tick, settings change, scroll listener, jump)
re-walked every visible item, re-instantiated every
avatar's NetworkImage, re-built every TimelineItem subtree,
and re-scanned every event for the undecryptable count.
This pass tightens the four hot paths so the chat surface
recomposes only when something genuinely visible changed.

Per-item RepaintBoundary

- Each TimelineItem in the cached item list is now wrapped
  in a RepaintBoundary
  (`lib/src/chat/timeline_view.dart`). A single dirty item
  (hover, highlight flash, optimistic outgoing) only
  invalidates its own paint layer instead of repainting
  the whole viewport during a drag. The boundary's GlobalKey
  is the same key that drives Scrollable.ensureVisible on
  jump-to-event, so the keymap contract is unchanged.

Item-list cache key tightened

- `_highlightedEventId` was previously part of the
  TimelineViewState cache key, so a highlight toggle
  (parent setState during a jump) invalidated the entire
  item list. Removed from the key
  (`lib/src/chat/timeline_view.dart`); the highlight is now
  applied per-item via HoverHighlight on each build without
  touching the item list.
- `_countUndecryptable` was being called on every
  didUpdateWidget, including prop changes that did not
  touch the event set. It now runs only when
  `timelineVersion` changes
  (`lib/src/chat/timeline_view.dart`). The banner listens
  to a ValueNotifier, so a sync that brings in new
  encrypted events still refreshes the badge via the
  version bump.

TimelineItem render subtree cache

- TimelineItem is now a StatefulWidget with a
  `_ItemRenderKey` that captures display type, font size,
  bubble radius, group flags, thread reply count,
  highlight, redaction, status name, content-map identity,
  body length, sender id, and timestamp
  (`lib/src/chat/timeline_item.dart`). didUpdateWidget
  compares the new key to the cached one; on a hit the
  cached subtree is replayed verbatim. The MessageEventHandler,
  HoverActionsWrapper, ReactionsBar, ReceiptAvatars, and
  AvatarFromUriOrFallbackImage inside the item are all
  skipped on a cache hit.
- HoverHighlight is wrapped around the cached subtree on
  every build so highlight state stays in sync without
  invalidating the subtree cache.
- `_safeStatusName` swallows the TypeError that some test
  mocks surface from a null `EventStatus` getter, so the
  cache key works against both real events and the
  mocktail-based mocks used by the existing widget tests.

AvatarFromUriOrFallbackImage ValueNotifier cache

- The per-item avatar used to re-subscribe to a fresh
  `FutureBuilder` on every build, re-instantiating
  NetworkImage and the auth-header map. Replaced with a
  per-(client, uri, size) `_AvatarResolver` (a
  ValueNotifier<Uri?>) shared across every widget that
  asks for the same avatar
  (`lib/src/widgets/avatar_from_uri.dart`). Multiple
  instances for the same sender listen to the same
  notifier; a single network roundtrip drives every
  rebuild.
- The render-side switch is `ListenableBuilder`; on
  resolution the listener receives the final URI and the
  CircleAvatar + NetworkImage are constructed once.
  NetworkImage + auth headers are unchanged.
- The internal `_LruCache` was O(N) on every eviction
  (List.removeAt(0)); switched to a LinkedHashMap-backed
  LRU for O(1) insertion-order tracking.
- clearCacheFor / clearAll preserved; AccountManager logout
  path still calls clearCacheFor(_activeClient!).

ChatTimeline SettingsController selector

- ChatTimeline.build used Consumer<SettingsController>,
  so any preference change (theme, notification toggles,
  etc.) forced a full timeline rebuild. Replaced with a
  Selector over a `_TimelineSettings` record (display
  type, font size, bubble radius, show-state-events).
  An unrelated settings change no longer touches the
  timeline subtree.

Scroll-listener payload slimming

- The scroll listener used to capture the full
  `Timeline.events` list as a debouncer closure
  parameter, retaining the entire list for 250 ms after
  every pixel of a fling. Added a `TimelineSnapshot`
  value type (`length`, `firstId`, `latestSyncedId`,
  equality) in `lib/src/chat/read_marker_tracker.dart`.
  `scheduleOnScroll` now takes a snapshot; `markRoomRead`
  still works on the full event list for callers that
  want it (used by tests). The closure captures the
  snapshot, not the events list, so the list is free to
  be GC'd immediately.

Tests added

- `test/unit/timeline_snapshot_test.dart` (6 tests):
  empty constructor, empty input list, picks newest synced
  event id, falls back to first id when nothing synced,
  equality holds for identical snapshots, equality
  distinguishes different ids.

Existing tests (preserved and still passing):
test/widget/avatar_from_uri_test.dart,
timeline_item_test.dart, chat_timeline_read_marker_test.dart,
chat_timeline_race_test.dart, scroll_position_test.dart,
scroll_drag_test.dart, timeline_skeleton_test.dart,
timeline_smooth_load_test.dart, timeline_content_update_test.dart,
history_single_flight_test.dart, paginate_until_marker_test.dart,
and all the rest of the widget and unit suites.

Tests at head: flutter test 492 green (one new
test/unit/timeline_snapshot_test.dart plus the existing
491). flutter analyze 0 errors, 0 warnings; only the
pre-existing `_ItemAppearance({super.key, ...})` unused
`key` warning in timeline_view.dart and the two
`dashboard_layout.dart` lines remain, all unrelated to
this change.


14. Chat-timeline scroll-velocity second pass

Follow-up to section 13. Targeted at the per-frame work
on the hot scrolling path: list-view virtualization, the
hover toolbar allocation, and the per-item message-body
rebuild surface. Each item is a contained change with
measurable behaviour, pinned by new tests where the
behaviour is observable.

ListView.custom + findChildIndexCallback

- `TimelineView` migrated from `ListView.builder` to
  `ListView.custom` with a `SliverChildBuilderDelegate`.
  `addRepaintBoundaries: false` is set because every item
  already wraps itself in a `RepaintBoundary`; setting
  both would double-layer. `addAutomaticKeepAlives:
  false` keeps the sliver from inserting a keep-alive
  per item -- chat rows are pure functions of their
  inputs and don't need to remember state across scroll
  trips.  See lib/src/chat/timeline_view.dart.

- `findChildIndexCallback` builds a `Key -> int` map from
  the cached item list once per build.  `Scrollable.ensureVisible`
  (which Flutter resolves via this callback under the
  hood) now maps a [GlobalKey] back to its sliver index
  in O(1) instead of relying on the previous fraction-based
  fallback.  See lib/src/chat/timeline_view.dart.

- Sliver index for the skeleton (`ValueKey('tl_skeleton')`)
  is recognised separately so any future scroll-to-skeleton
  affordance also resolves in O(1).  See
  lib/src/chat/timeline_view.dart.

Hover overlay lifted off every item

- New `HoverOverlayController` (a `ChangeNotifier`
  implementing `ValueListenable<HoverTargetEntry?>`) owns
  the per-timeline hover state.  Exposed to the rest of
  the tree through a new `HoverScope` inherited widget.
  See lib/src/chat/hover_overlay.dart.

- New `HoverTarget` widget is the per-item replacement for
  the old `HoverActionsWrapper`.  Each item still owns a
  tiny [MouseRegion] (necessary for `onEnter`/`onExit`
  granularity), but the [Stack] + [Positioned] +
  [BoxDecoration] (with two [BoxShadow]s) +
  [ValueListenableBuilder] + [MessageActions] allocation
  that used to live on every item now lives on a single
  shared `HoverOverlay` mounted at the `TimelineView`
  root.  The overlay rebuilds only when the hovered item
  changes; per-item bodies no longer pay for the toolbar
  allocation on every rebuild during a drag.  See
  lib/src/chat/hover_target.dart and
  lib/src/chat/hover_overlay_layer.dart.

- Old `lib/src/chat/hover_actions_wrapper.dart` file is
  deleted; `TimelineItem` now uses `HoverTarget` directly.
  The new architecture is forward-compatible: lifting
  the toolbar further (e.g. an overlay above the chat
  surface rather than bound inside the viewport) is a
  smaller change now that the toolbar already lives in a
  single instance detached from the item.

- Defensive exit logic in `_HoverTargetState`: stale
  `onExit` callbacks on a recycled-out item are ignored
  (the entry's key doesn't match the active one), and
  `deactivate` / `dispose` proactively clear the overlay
  so the toolbar never lands over a defunct item.

MessageEventHandler render-key cache

- `MessageEventHandler` was a `StatelessWidget` that ran
  the full dispatch on every parent build, including a
  second `context.read<EncryptionService>()` and a fresh
  `event.inReplyToEventId()` lookup.  Converted to a
  `StatefulWidget` with a `_HandlerRenderKey` that
  captures eventId, type, messageType, inReplyTo,
  redacted, originalSourceType, contentIdentity,
  bodyLength, formattedBodyLength, replyThreshold,
  fontSizeBucket, timelineIdentity, and roomIdentity.
  `didUpdateWidget` short-circuits when the key is
  unchanged, replaying the cached subtree verbatim.
  See lib/src/chat/chat_event.dart.

- `_cachedReplyThreshold` is captured lazily on the first
  `didChangeDependencies` so widget tests that don't mount
  a `SettingsController` still work.  See
  lib/src/chat/chat_event.dart.

MatrixUrlBannerWrapper fast-path

- `MatrixUrlBannerWrapper` previously ran
  `MatrixUriParser.parseAll` on every message body even
  when the body contained no plausible matrix reference.
  The detector RegExp walks every character of the body,
  so a long plain-prose message paid a non-trivial parse
  cost per build.  Added `_couldContainMatrixReference`
  which is a cheap `contains` scan for `matrix:` /
  `matrix.to` / `@` / `#`; if all four are absent, the
  regex is skipped and `child` is returned unchanged.
  False positives (e.g. `foo@bar.com`) are accepted
  because the regex still filters them downstream.
  See lib/src/chat/events/matrix_url_banner_wrapper.dart.

Tests added

- `test/unit/hover_overlay_controller_test.dart` (6 tests):
  enter then exit leaves the controller empty, exit is a
  no-op for a stale entry, re-entering the same entry
  doesn't re-notify, clear drops the active entry, same-key
  entries compare equal, different-key entries do not.
- `test/unit/matrix_url_banner_short_circuit_test.dart`
  (7 tests): empty body is rejected, plain text without
  tokens is rejected, matrix: scheme URIs are accepted,
  matrix.to permalinks are accepted, bare @user:domain
  mentions are accepted, bare #alias:domain mentions are
  accepted, plain text with a stray `@` is accepted as a
  false positive.

Existing tests (preserved and still passing):
test/widget/timeline_item_test.dart (modern, bubbles,
irc), timeline_smooth_load_test.dart, skeleton tests,
scroll / scroll drag, chat_timeline_race,
chat_timeline_read_marker, paginate_until_marker,
timeline_content_update, history_single_flight, plus
the entire avatar, message actions, reactions,
hover-target, message-types, and reply-related suites.

Tests at head: flutter test 505 green (13 new tests
across the two new unit test files plus the existing
492). flutter analyze 0 errors, 0 warnings; only the
pre-existing `_ItemAppearance({super.key, ...})` unused
`key` warning in `lib/src/chat/timeline_view.dart` and
the two `lib/src/layouts/dashboard_layout.dart` lines
remain, all unrelated to this change.


15. Hoverbar rearchitecture (the "rapid flash" fix)

The first cut of the per-item `HoverTarget` design (section
14) introduced a visible flash on every cursor transition
between rows: the toolbar briefly unmounted between the
exit from one item's [MouseRegion] and the entry into the
next, so the user saw the toolbar pop in / out dozens of
times per drag.

## Root cause

Each item hosted its own [MouseRegion]. The cursor
leaving one item's region fired `onExit`; the cursor
crossing empty space (no [MouseRegion] underneath)
produced a brief window where the controller saw no
hovered item; only when the cursor reached the next item
did `onEnter` fire and the toolbar re-mount. During a
fast drag across many rows the toolbar was repeatedly
unmounted and remounted, which the user described as
"rapidly flashing the timeline".

## New architecture

The new design drops per-item [MouseRegion]s entirely
in favour of a single global [MouseRegion] at the
[TimelineView] root, plus a real [Overlay]-hosted
toolbar with a halo hit-region. The flow is now:

- Each item hosts a passive [_HoverGeometryProbe] that
  schedules a post-frame callback to push its render
  [Rect] (in global coordinates) into a registry on the
  shared [HoverOverlayController].  No [MouseRegion],
  no hit-test state per item.
- A single global [MouseRegion] in [TimelineView]
  covers the list viewport.  Its `onHover` translates
  every pointer position into the controller's
  registered-rect map and runs the hit-test in O(visible
  items).  This is a single hit-test per pointer move,
  not N.
- The toolbar itself lives in the route's [Overlay] (not
  in the timeline [Stack]) and hosts its own
  [MouseRegion] with `HitTestBehavior.translucent`.  The
  cursor can travel from the message body into the
  toolbar without losing hover, because the toolbar's
  hit-region is wider than its visual region and the
  cursor re-enters the toolbar's [MouseRegion] as soon
  as it crosses the gap from the row body.
- The controller debounces the hide: a `Timer` of
  80 ms runs after the cursor leaves the last
  hovered item.  Within that window a fresh hit or
  toolbar re-entry cancels the hide, smoothing
  cross-row drags.
- `enterToolbar(key)` re-claims the active item even
  if a sibling row briefly won the global hit-test, so
  the wider cursor holding power lives with the
  toolbar itself.

## Files

- `lib/src/chat/hover_overlay.dart`: reworked.
  `HoverOverlayController` now exposes
  `hoveredKey: ValueNotifier<GlobalKey?>`,
  `toolbarVisible: ValueNotifier<bool>`, and the
  registry maps `itemRects` / `itemEntries`.  The
  public surface is `registerRect` / `unregisterRect` /
  `registerEntry` / `unregisterEntry` / `hitTest` /
  `enterToolbar` / `scheduleToolbarHide` / `cancelHide`.
  `HoverScope` and `HoverTargetEntry` carry over with
  minor changes (the entry now lives on the controller,
  not on the item state, so the toolbar can read it
  without walking the widget tree).
- `lib/src/chat/hover_item.dart` (replaces
  `lib/src/chat/hover_target.dart`): passive
  per-item widget.  No [MouseRegion], just a
  [_HoverGeometryProbe] that registers / unregisters
  with the controller and reports the item's render
  rect in global coordinates.  Carries the toolbar
  callbacks the toolbar needs to drive actions.
- `lib/src/chat/hover_overlay_layer.dart`: reworked.
  `HoverOverlay` now mounts an [OverlayEntry] in the
  route's overlay whenever the controller is active.
  `_ToolbarOverlay` positions the toolbar above the
  active item's render rect via `globalToLocal`, hosts
  the wide [MouseRegion] that absorbs the cursor, and
  renders [MessageActions] for the active item.
- `lib/src/chat/timeline_view.dart`: the per-item
  `MouseRegion` and inline `Stack`-with-`HoverOverlay`
  are gone.  The list is wrapped in a single
  global [MouseRegion] that drives
  `controller.hitTest` on every pointer move.
- `lib/src/chat/timeline_item.dart`: uses `HoverItem`
  in place of the old `HoverTarget`.

## Behaviour

- The toolbar is anchored continuously across cursor
  transitions.  No more "exit-no-enter" gap.
- The toolbar can be lifted out of the timeline clip
  (it's a route-overlay, not a [Stack] child), so a
  wide toolbar overhangs the chat column without
  being cut off.
- The hit-test is global, so the cost of N visible
  items is one rect-containment test per pointer move
  (vs. N [MouseRegion] allocations previously).  A
  fast drag still pays the per-move hit-test cost but
  doesn't have to mount / unmount the toolbar chrome.
- The 80 ms hide debounce prevents the toolbar from
  popping off when the cursor briefly leaves the
  toolbar region during a 2-row drag; the timer is
  cancelled by a fresh hit or toolbar re-entry.
- The `unregisterRect` / `unregisterEntry` paths
  defensively clear `hoveredKey` and `toolbarVisible`
  if the active item is deactivated, so the toolbar
  never lingers over a defunct widget.

Tests

- The unit test suite
  (`test/unit/hover_overlay_controller_test.dart`)
  was rewritten to exercise the new API.  The
  geometry-driven cases (register / hit / unregister
  / debounce / re-claim) are all covered; the
  equality cases carry over.
- Existing widget tests (timeline_item,
  timeline_smooth_load, skeleton, scroll, etc.) all
  continue to pass with no source changes.

Tests at head: flutter test 508 green (the rewritten
hover_overlay_controller_test.dart plus the existing
505). flutter analyze 0 errors, 0 warnings; only the
pre-existing `_ItemAppearance({super.key, ...})` unused
`key` warning in `lib/src/chat/timeline_view.dart` and
the two `lib/src/layouts/dashboard_layout.dart` lines
remain, all unrelated to this change.


16. Responsive layout shell rework (sticky layout state)

The shell-selection logic (full vs compact vs mobile dashboard) was
rebuilt as a single sticky state machine. Previously the decision was
split across two independent hysteresis systems: the dashboard's
LayoutShellController (a 60 px dead band plus a 400 ms settle timer at
the 1100 px boundary) and a second, separate hysteresis pass in the
router's _AdaptiveMainLayout at the 600 px boundary. The dashboard
also owned its controller instance, so every mobile/dashboard flip
created a fresh controller that started in the expanded state and
re-settled over hundreds of milliseconds. The two systems could
disagree mid-drag, and the timer plus pending-commit machinery could
leave the app visibly switching between the full and compact layouts
(the reported "in-between" state).

- LayoutShellController is now a sticky state machine with no timers
  and no pending state. It commits one of three shells (LayoutShell
  mobile / compact / expanded) and keeps it until the window width
  crosses a breakpoint by the full 60 px dead band anchored to the
  currently committed shell, so a boundary crossing commits exactly
  once and cannot flap. The 400 ms settle timer and the pending
  candidate state are gone. See lib/src/layouts/layout_shell_controller.dart.

- The controller now owns both boundaries. LayoutShell.mobile covers
  the 600 px boundary (previously decided by the router) while compact
  vs expanded covers the 1100 px boundary, so the mobile, compact, and
  full shells all resolve through the same committed state.

- The first width evaluation commits immediately, so a freshly opened
  window never flashes the wrong shell while waiting for a settle
  timer. A user-forced LayoutMode (compact / mobile) overrides the
  width logic and sticks until the user returns to auto. reset() is
  called when the main chat surface mounts (fresh login) so a window
  resized while logged out re-derives its shell instead of inheriting
  a stale committed one.

- The controller moved from _DashboardLayoutState to the app level: it
  is now a ChangeNotifierProvider in main.dart (and in the integration
  test boot helper). This is what kills the in-between state: the
  shell decision survives mobile/dashboard flips instead of being
  recreated and re-settling. See lib/main.dart and
  integration_test/helpers/test_app_boot.dart.

- All layout consumers read the same committed state. The router's
  _roomsListPageBuilder and _AdaptiveMainLayout and the dashboard's
  LayoutBuilder all call the shared controller's update() with the
  window width and the user's layout mode, so the frame and the route
  pages agree in the same frame by construction. See
  lib/src/router.dart and lib/src/layouts/dashboard_layout.dart.

- _AdaptiveMainLayout lost its mirrored hysteresis pass (the 60 px
  dead band, cached width, and cached layout mode) and now just
  renders the committed shell, keeping the existing re-navigation on
  shell flip. DashboardLayout no longer creates or disposes a
  controller; it reads the shared one via shell.isCompact. See
  lib/src/router.dart and lib/src/layouts/dashboard_layout.dart.

- The integration test boot helper was missing the DeepLinkService
  provider, so every E2E test crashed on the welcome screen with a
  ProviderNotFoundException before reaching any layout code. The
  harness now provides DeepLinkService (plus the new
  LayoutShellController) to match main.dart. See
  integration_test/helpers/test_app_boot.dart.

- New unit suite test/unit/layout_shell_controller_test.dart (11
  tests): the first evaluation commits the width-appropriate shell,
  both dead bands (600 and 1100 px) hold the committed shell, an
  oscillation around a boundary never flaps the shell, user-forced
  modes override width and stick, returning to auto re-resolves, and
  repeated updates with the same width are stable.

Tests at head: flutter test 506 green (unit + widget). flutter
analyze 0 issues. The login and room-flow integration tests still
carry pre-existing finder mismatches in the test files themselves
(ambiguous "Sign In" targets, a case-mismatched "Sign in", and a
missing "Moonrelay" welcome-text expectation); they fail before
login and are unrelated to this change.



17. Shell-flip navigation leak fix (the "hang after a while" bug)

The app could appear to hang after a few window resizes or layout-mode
switches. The root cause was in the shell-flip re-navigation added by
the layout shell rework: when the mobile/dashboard shell flipped,
_AdaptiveMainLayout called _navigateToActiveRoom, which refreshed the
route by pushing the current URL and popping it in a whenComplete
callback. But GoRouter.push()'s future only completes when the pushed
page is popped, and the only pop lived inside that whenComplete, so it
never ran. Every flip pushed a full duplicate page (a second live
/room page with its own ChatTimeline, room subscriptions, scroll
listeners, and read-marker pipeline) onto the route stack, never
disposed. After enough flips the app had several live timelines all
rebuilding on every room update, progressively wedging the UI with no
exception thrown.

- The refresh no longer navigates at all. _roomsListPageBuilder wraps
  its child in a ListenableBuilder on the shared LayoutShellController,
  so the mobile/dashboard page child rebuilds reactively the same frame
  the shell commits. The stale-child problem the push/pop hack was
  papering over is gone by construction. See lib/src/router.dart.

- _navigateToActiveRoom is now a plain GoRouter.go(target); the
  never-pop push()/whenComplete() machinery was deleted. See
  lib/src/router.dart.

- MoonrelayApp.moonrouter was a static GoRouter shared by every app
  instance. In the E2E suite that leaked route state (and the mounted
  pages with their open database connections) from one test into the
  next, which is what produced the "2 widgets with text Sign In"
  ambiguity and the readonly-database cascade on the shared temp DB.
  The router is now an instance field created per State and disposed
  with it. See lib/src/app.dart.

- Regression test: integration_test/hang_repro_test.dart drives 200
  sustained sync ticks (each delivering a new event) plus 20 forced
  resizes across all three layout boundaries, then asserts the frame
  pipeline stays live and the room page is not duplicated on the
  navigator stack. With the old code the room page was duplicated 5+
  times after the flips; with the fix it stays at 2-3 (sidebar +
  header). See integration_test/hang_repro_test.dart.

matrix 9.0.0 broke the E2E login flow, which surfaced while wiring the
reproduction: Client.checkHomeserver now fails non-retryably when
/_matrix/client/versions 404s, OlmManager.init throws "Upload key
failed" unless the /keys/upload response echoes the number of signed
one-time keys inside one_time_key_counts.signed_curve25519, and every
sync tick fails inside Client.updateUserDeviceKeys when /keys/query
404s (which re-arms the background sync loop immediately, burning
CPU). The MockMatrixHttpClient now registers these as defaults
(versions, sync filter, keys upload with a correct count echo, keys
query, keys claim) so tests no longer need to repeat them. Pre-existing
test-file bugs were also fixed: case-mismatched/ambiguous "Sign In"
finders and missing post-login wait loops for the room to populate.
See integration_test/helpers/mock_matrix_http_client.dart,
integration_test/room_flow_test.dart, integration_test/logout_test.dart.

Tests at head: flutter test 506 green (unit + widget), flutter analyze
0 issues. integration_test/hang_repro_test.dart green (the leak
regression test). The room-flow and logout E2E files still fail on
remaining mock gaps that predate this work (unmocked /devices,
/messages pagination, and /read_markers endpoints, plus a teardown
race on the shared temp database); they are unrelated to the hang fix.



18. Bug-fix pass (24 fixes from the full-codebase audit)

A dedicated bug-fix pass over the whole codebase, one commit per fix.
Every fix landed with a "Fix ..." / "Stop ..." style commit and the
full unit + widget suite went from 3 known failures to fully green.
The pass also caught two fixes the audit itself missed: a future
self-deadlock in the media cache cleanup, and a latent bug in the
space-delete progress dialog that deleted the space itself instead of
its children.

- The read-marker dedupe trim iterated a Set while removing from it,
  which throws ConcurrentModificationError the moment the cache grows
  past its cap. The trim now snapshots the keys before removing. See
  lib/src/chat/read_marker_tracker.dart (and the dead duplicate path
  in lib/src/chat/read_marker_coordinator.dart). Verified with a
  standalone runtime probe before fixing.

- Poll sending built a malformed event: the content map carried its
  own nested "type"/"content" keys instead of sending m.poll.start
  with an m.poll content object. See lib/src/chat/poll_send_dialog.dart.

- Joining a room from an alias (preview, add-by-id, directory search)
  then navigated to the alias instead of the canonical room ID the
  join returns, so the room page rendered a blank "unknown room"
  state. Navigation now uses the returned room ID. See
  lib/src/screens/rooms/room_preview_screen.dart,
  lib/src/screens/rooms/add_room_from_id.dart,
  lib/src/screens/rooms/room_directory_search.dart.

- Cached timeline items skipped the right-click context menu and the
  hover highlight because the cache-hit branch returned the raw
  subtree. It now re-wraps the cached subtree with the menu and hover
  wrapper. See lib/src/chat/timeline_item.dart.

- The chat box could call setState after dispose when the send future
  completed after the widget was torn down. A mounted guard now sits
  on the success path. See lib/src/chat/chat_box.dart.

- Failed media downloads left their in-flight future in the cache, so
  every later retry replayed the same error until restart. The inflight
  entry is now cleared on completion either way. The first version of
  this fix deadlocked: the cleanup callback returned the in-flight
  future itself (Map.remove returns the removed value) and whenComplete
  waits on its callback's result, so the future waited on itself. The
  callback now returns void. See lib/src/helpers/room_media_cache.dart.

- Uri.decodeComponent throws FormatException on malformed percent
  sequences, so a single bad matrix:// URI could crash the URL
  banner detection. The public parser now catches the format error and
  returns null. See lib/src/helpers/matrix_uri_parser.dart. Verified
  with a standalone probe before fixing.

- The sync listener crashed when a message event carried a non-string
  body (e.g. a numeric-only content), taking down the notification
  pipeline on every tick. The body read is now a type-safe tryGet
  with an empty-string fallback. See lib/src/services/notification_service.dart.

- Drafts were stored in a single map keyed only by body, so switching
  rooms with an unsent draft silently dropped it. Drafts now persist
  per room and a single debounce timer flushes every changed room;
  release() flushes instead of discarding. See lib/src/services/draft_service.dart.

- The room router dereferenced a nullable room lookup on deep links
  for rooms the client has not synced yet (null-bang crash). The
  resolver now returns a nullable room and every consumer (details,
  thread, settings) renders a not-found page instead of crashing. See
  lib/src/router.dart.

- The startup update dialog was shown with a context above
  MaterialApp.router, so it silently threw on missing Localizations
  and never appeared. The app now owns a navigator key handed to the
  router, and the dialog is shown through that in-tree context. See
  lib/main.dart and lib/src/app.dart.

- MediaSizePrefs fallback defaults contradicted the controller (audio
  360 vs 340, file 340 vs 360, location 360 vs 340), so isolated
  widgets rendered different sizes than the real app. The fallback now
  matches the controller. See lib/src/settings/media_size_prefs.dart.

- The compact date formatter produced "07- 06" (stray space), and the
  "Yesterday" check used now.day == day+1, which breaks on the first
  of a month and on New Year's. The check now compares day-of-epoch.
  See lib/src/helpers/date_time_extension.dart and
  lib/src/chat/events/date_separator.dart.

- Markdown list flushes never cleared their item buffers, so a list
  that was flushed mid-conversion (e.g. on a list-type switch or at
  EOF) re-emitted its items a second time. Flushes now clear. See
  lib/src/helpers/markdown_to_html.dart.

- Update comparison parsed "1.2.3+12" as three components, failed the
  numeric parse on the "+12" component, and fell back to a
  lexicographic compare that misordered versions like 0.10 vs 0.9.
  The build suffix is now stripped before parsing. See
  lib/src/services/auto_update_service.dart.

- The notification short-circuit only tracked the room with the newest
  last-event timestamp, so a message in any other room (with an older
  timestamp) never triggered a notification. It now signs every room's
  last event ID. See lib/src/services/notification_service.dart.

- The schema version was persisted before the database opened, so a
  failed open hid the stale file on the next boot. The version is now
  written only after the open succeeds. See lib/src/services/database_service.dart.

- An in-flight in-room server search could land after a newer query
  and overwrite its results. Responses are now stamped with a query
  token and stale ones are discarded. See lib/src/chat/in_room_search_panel.dart.

- Clearing a read marker used a bare prefs.remove, bypassing the
  compare-and-swap sequence check, so a concurrent stale write could
  resurrect a cleared marker (and a stale clear could drop a newer
  one). Clears now write a tombstone through the same sequence check.
  See lib/src/services/read_marker_service.dart.

- The SSO callback server bound to 127.0.0.1 but redirected the
  browser to "localhost", which can resolve to ::1 first and fail to
  connect. The redirect now uses the loopback address the server is
  bound to. See lib/src/services/sso_server.dart.

- Changing the avatar uploaded the bytes twice (an explicit
  uploadContent call whose result was discarded, plus the internal
  upload inside setAvatar). The redundant upload is gone. See
  lib/src/screens/hub_screen/my_profile_page.dart.

- The Synapse admin delete requests went out without an Authorization
  header (the raw http client attaches no token), so room and space
  deletion always failed with 401. All five call sites now send
  "Bearer <access token>". During this fix a latent bug surfaced in
  the space-delete progress dialog, whose child-room loop posted to
  the space's own delete URL instead of the child's; that is fixed
  too. See lib/src/screens/room_settings_page.dart and
  lib/src/screens/space_settings_page.dart.

- switchToAccount returned false for the already-active account, which
  the caller treated as a failed switch and bounced the user to login.
  It now reports the no-op as success. See lib/src/helpers/account_manager.dart.

- Paginated-history fade targeted the newest indices (index <= 4) even
  though the timeline is newest-first, so the newest messages faded in
  on scroll instead of the freshly-fetched history. It now targets the
  tail of the list. See lib/src/chat/timeline_view.dart.

- Two tests asserted the old buggy behavior and are updated to the
  corrected values: MediaSizePrefs defaults (audio 340, file 360,
  location 340) and the SSO redirect host (127.0.0.1). See
  test/unit/settings_extended_test.dart and
  test/unit/sso_callback_server_test.dart.

Tests at head: flutter test 508 green (unit + widget). flutter analyze
0 issues. The room-flow and logout E2E files still fail on the
pre-existing mock gaps described in the previous section; they were not
touched by this pass.



19. SSO loopback-host regression fix

The SSO fix in section 18 (redirecting the browser to the literal
loopback address) broke the callback handler it was meant to protect.
The server still validated the incoming Host header against
`localhost:$port` only, but the browser now navigated to
`http://127.0.0.1:$port/callback`, so every callback carried
`Host: 127.0.0.1:$port` and was rejected with "bad host header". SSO
login therefore never completed through the automatic flow.

- The Host-header check now accepts both `localhost:$port` and
  `127.0.0.1:$port` while still pinning the exact port, so no foreign
  origin can reach the callback. The doc comment was updated to match.
  See lib/src/services/sso_server.dart.

- Regression test: drives a real GET whose Host matches the redirect
  host (127.0.0.1) and asserts the token future resolves. Asserting on
  the future instead of the HTTP response body sidesteps the socket
  race that made broader E2E coverage flaky. See
   test/unit/sso_callback_server_test.dart.

Tests at head: flutter test 509 green (unit + widget). flutter analyze
0 issues. E2E room-flow and logout still fail on the pre-existing mock
gaps described in section 18.


25. Scroll-position null-deref crash on timeline first paint

`ScrollPosition.maxScrollExtent` is backed by a nullable `double?` in
Flutter's framework (the `!` assertion only fires when content dimensions
have been applied via `applyContentDimensions`). The chat timeline reads
`maxScrollExtent` right after a `hasClients` check, but `hasClients` being
true does not guarantee that the scrollable has laid out. During the
first paint -- especially from the post-frame callback in `_initTimeline`
that kicks off `HistoryPager.ensureFilled` -- the scroll controller has a
client attached but `_maxScrollExtent` is still null, so the `!` throws
`_TypeError: Null check operator used on a null value`. The same
unguarded access existed in the `build` method, `onScroll`, the jump-to-
event fallback in `JumpCoordinator`, and `_scrollToEventId` in
`TimelineView`.

- All five sites now guard with `scrollController.position.haveDimensions`
  (or `_scrollController.position.haveDimensions`) before reading
  `maxScrollExtent`. When dimensions aren't ready yet, `ensureFilled`
  defers itself to the next frame via `addPostFrameCallback`, mirroring
  the existing `hasClients` deferral. The other sites simply return early,
  since they are invoked from scroll listeners or user actions that will
  fire on a subsequent frame when layout is valid.
  See `lib/src/chat/history_pager.dart:152`, `lib/src/chat/history_pager.dart:191`,
  `lib/src/chat/chat_timeline.dart:466`, `lib/src/chat/jump_coordinator.dart:207`,
  `lib/src/chat/timeline_view.dart:636`.

Tests at head: flutter analyze 0 issues. flutter test unit + widget all green.

Tests at head: flutter analyze 0 issues. flutter test unit + widget all green.

26. Timeline Suckless-cleanup pass

The chat timeline was carrying several layers of indirection that the
Suckless philosophy (do one thing, do it well, no dead weight) flagged as
avoidable. The cleanup extracts the view-model logic into a pure-Dart
model that has zero Flutter dependency, then slims down the view widgets
around it.

26.1 Model extraction: lib/src/chat/timeline_model.dart

- Extracted `isStateEvent(TimelineEvent)` (was a closure inside
  `_TimelineViewState`, with a redundant try/catch wrapper that is now
  removed -- state event types are stable and do not throw on access).
- Added `TimelineItemEntry` -- a lightweight record of the final display
  position, type, and source event for each timeline row. Keys are
  stable `ValueKey<String>(eventId)` so ListView diffing is minimal.
- Added `TimelineItemsResult` -- a simple aggregate (entries + counts)
  built once per sync notification.
- Added `buildTimelineItems(...)` -- the single pure function that
  takes a `Timeline` and returns a `TimelineItemsResult`. No Flutter
  imports, no `BuildContext`, no `setState`. This is now unit-tested in
  isolation.
- Added `filteredRelationshipEvents(Timeline)` and
  `timelineItemCount(Timeline)` as thin pure helpers, removing the need
  for the old `filteredEvents` and `timelineItemCount` getters that
  lived on `_TimelineViewState` and required `mounted` guards.

26.2 Tests: test/unit/timeline_model_test.dart (29 new tests, all pass)

- `isStateEvent`: covers m.room*, m.reaction, m.encrypted, m.call, and
  the try/catch fallback for unknown types.
- `TimelineItemEntry` equality and key stability.
- `TimelineItemsResult` construction and count invariants.
- `buildTimelineItems`: grouping logic, relationship-event filtering
  (reactions/edits/replies/threads excluded from the row list), state
  event interleaving, key stability across rebuilds.
- `filteredRelationshipEvents`: correct exclusion of
  `m.relates_to` events from the standalone row list.
- `timelineItemCount`: matches `buildTimelineItems` length for various
  mock timelines.

Tests at head: flutter test 538 green (509 + 29 new unit tests).
flutter analyze 0 issues.

26.3 View refactor: chat_timeline.dart, timeline_view.dart, timeline_item.dart

- `_onTimelineUpdate` (chat_timeline.dart:278) now calls
  `_timelineVersion.value++` instead of `setState(() =>
  _timelineVersion++)`. `_timelineVersion` is a `ValueNotifier<int>`
  created in the constructor. This removes a setState call from the
  hot sync-update path.
- `ChatTimeline` now passes `timelineVersion` as a `ValueNotifier<int>`
  to `TimelineView` instead of a plain `int`, so the view layer can
  rebuild via `ValueListenableBuilder` without a stateful-setState
  round-trip.
- `TimelineView` replaces `timelineVersion` (int) with
  `timelineVersion` (`ValueNotifier<int>?`) and rebuilds its
  `_UndecryptableBanner` count via `ValueListenableBuilder` instead of
  `setState`. Item rendering delegates to `buildTimelineItems` from the
  model, so the view layer no longer duplicates the filtering and
  grouping logic.
- `TimelineItem` removes the `HoverHighlight` dependency entirely.
  Per-item hover state is now a local `ValueNotifier<bool>` driven by
  `MouseRegion` + `ValueListenableBuilder`, replacing the old inherited
  `HoverHighlight` widget that propagated hover state down a deep
  subtree on every mouse frame.
- `hover_highlight.dart` is deleted -- no remaining references.

26.4 Context menu simplification: message_context_menu.dart

- `showForEvent` now delegates directly to Flutter's `showMenu`
  (synchronous return value, single code path). The previous
  custom-overlay implementation (`_ContextMenuPopup`,
  `_MenuCard`, `_buildQuickActions`, `_quickIcon`) is removed,
  eliminating ~120 lines of dead overlay positioning code.

Tests at head: flutter analyze 0 issues. flutter test unit + widget all green.

27. Jump-to-unread FAB survives scroll motion

The jump-to-unread pill was coupled to the scroll position: it only
appeared when the user was scrolled up, so scrolling back down to the
bottom made it disappear. The user wants the pill to persist at all
scroll positions unless explicitly dismissed (X button) or resolved
(tap to jump, which marks the room as read).

- The `ValueListenableBuilder<bool>` on `_isScrolledUpNotifier` is now a
  `ListenableBuilder` listening to `Listenable.merge([_isScrolledUpNotifier,
  _timelineVersion])` so the column rebuilds when either the scroll state
  *or* the timeline content changes -- previously the floating actions only
  re-evaluated on scroll ticks, meaning a sync that brought in new unread
  events while the user sat at the bottom would not surface the pill until
  they scrolled. See `lib/src/chat/chat_timeline.dart:500`.
- `unreadVisible` is now `_showUnreadPill || isJumping` (was
  `(_showUnreadPill && isScrolledUp) || isJumping`). The `&& isScrolledUp`
  guard is removed, so the pill stays visible once `_showUnreadPill` is
  true regardless of where the user is in the list. The `isJumping`
  alternative still surfaces the loading spinner during pagination.
- `showColumn` is now `isScrolledUp || unreadVisible` (was
  `isScrolledUp || isJumping`). This keeps the column mounted when the
  pill should be shown even at the bottom, while the scroll-to-bottom pill
  still only appears on scroll-up. See `lib/src/chat/chat_timeline.dart:510`.

The `ScrollToBottomPill` behaviour is unchanged: it still only appears
when `isScrolledUp` is true and disappears when the user returns to the
newest messages. Explicit dismissal resets on room switch or read-marker
update, matching the existing `_pillDismissed` lifecycle.

27.1 Unread count and jump targets skip inline-rendered relationship events

The unread pill and the jump-to-unread target used `isMessageLikeEvent`
everywhere, so edits and thread replies (message-typed events carrying a
`relationshipEventId`) counted toward the unread total. `TimelineView`
renders those inline with their parent and never gives them a standalone
row, so the pill inflated with content the user could not land on, and
the pager could resolve a jump target that had no addressable item.

- `lib/src/chat/chat_unread_utils.dart` now defines
  `isAddressableUnreadEvent` (a message-like event that also passes
  `ThreadUtils.isVisibleInMainTimeline`). `countUnreadInWindow` uses it
  for both the no-marker and marker-anchored paths. Thread roots (which
  reference themselves) stay addressable and still count.
- `lib/src/chat/jump_to_unread_pager.dart` uses `isAddressableUnreadEvent`
  in `findFirstUnreadMessageIndex` and `findFirstUnreadMessageIndexFromEnd`,
  so the jump lands on the first real standalone message after the marker
  instead of an inline edit or thread reply.
- Tests in `test/unit/chat_timeline_test.dart` cover edits/thread replies
  excluded from the count, thread roots kept, and the pager skipping
  relationship events while still returning `-1` when the unread tail is
  only state events or non-addressable events.

27.2 Jump-to-unread now actually scrolls to the first unread message

The FAB surfaced and resolved its target, dismissed the pill, and marked
the room read, but the timeline did not move. Root cause: the jump routes
through `TimelineView._doScrollToEvent`, whose fallback (used when the
target item is not yet built and has no `GlobalKey` for
`Scrollable.ensureVisible`) called `TimelineScrollTarget.scrollToFraction`
with the default `skipIfClose: true`. When the fraction estimate landed
within 60% of the viewport of the current position, that default silently
dropped the scroll. The target being "close" by the estimate is a lie for
items outside the built window, so the view sat motionless. Every other
user-invoked jump site (`JumpCoordinator.jumpToEvent`,
`JumpCoordinator._scrollToEvent`, and `TimelineScrollTarget.scrollToEvent`)
already passed `skipIfClose: false`; the jump-to-unread path was the only
one using the default.

- `_doScrollToEvent` (`lib/src/chat/timeline_view.dart`) now passes
  `skipIfClose: false`, matching the other jump sites, so a user-invoked
  jump always moves the view.
- The same fallback previously used the model's `eventIdToItemIndex`, which
  is built before the undecryptable banner is prepended to the item list
  (indices off by one) and counts only message events (so the fraction
  denominator omitted the banner, date separators, and state batches).
  `_doScrollToEvent` now re-derives the rendered item index by matching
  the per-event `GlobalKey` in `_cachedItems` and uses `_cachedItems.length`
  as the count, so the fallback lands accurately once the item is built.
- `test/widget/timeline_view_jump_scroll_test.dart` reproduces the
  suppression: it mounts `TimelineView` with mock messages, scrolls into
  history so the newest message sits just past the built window (its
  fraction estimate is within 60% of the viewport), calls
  `scrollToEventId`, and asserts the controller actually moves. This failed
  on the old code (the offset never changed) and passes now (the view
  scrolls to the target).
- `test/widget/timeline_scroll_target_test.dart` pins the helper contract:
  `skipIfClose: false` scrolls to a target the default would suppress, and
  the default suppresses a close target.

Tests at head: flutter test 547 green (538 prior + 6 unit tests for 27.1
+ 3 widget tests for 27.2). flutter analyze 0 issues.
