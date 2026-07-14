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
pass, and the recent UX fix-up pass.

Known-fail tests: 0 [<---- Update this if a test is known as broken ---->]


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
