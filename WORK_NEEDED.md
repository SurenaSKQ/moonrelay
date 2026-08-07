Part of Moonrelay, a matrix protocol client.
Copyright (C) 2025 Surena Karimpour Ghannadi
AGPLv3

WORK_NEEDED

Open work ledger for Moonrelay. Each item is anchored to a file:line or
file path.

Tests at head: flutter test 538 green (unit + widget). flutter analyze 0 issues.

The categories used below are:
- correctness (things that are broken or unreliable)
- performance (CPU, memory, rebuilds)
- refactor (code shape, dead code, consolidation)
- feature (user-facing capability)
- quality (tests, logging, polish)
- security


1. Open bugs and refactors

1.1 Skeleton loading - login to hub navigation still flashes empty

Login to hub navigation: the redirect chain briefly flashes an empty hub
before the first sync. Splash (lib/src/splash_screen.dart) shows a
spinner but should stay visible until the hub has at least one room
cached.

The accounts-page skeleton (lib/src/screens/hub_screen/accounts_page.dart,
the _buildLoading(theme) placeholder while a Future<Profile> is in
flight) is already in place and does not need further work.

1.2 Future-aware surface comments

(See also 26.3 in WORK_DONE.md: _UndecryptableBanner now reads its count via ValueListenableBuilder instead of a setState callback; the comment at lib/src/chat/timeline_view.dart:135 documents the notifier's lifecycle.)

In-room search jump accuracy: ChatTimeline.jumpToEvent
(lib/src/chat/chat_timeline.dart:1134) now uses Scrollable.ensureVisible
The fallback path (when the key is not in the current viewport, e.g.
during rapid pagination) still estimates from a fraction; the existing
comment noting that users may need to scroll up/down after a fallback
jump is still in place at lib/src/chat/jump_coordinator.dart:211.

1.3 Refactor candidates

- HTML tag allow-list: MarkdownToHtml and HtmlTagParser each implement
  their own tag allow-list. Extract a single SanitizedHtml helper.
  (HtmlTagParser was extracted to html_tag_parser.dart in the cleanup
  pass, but the shared allow-list is still outstanding.)

- Color palette: MoonrelayColorPalette mixes raw swatches with
  StringColor wrappers. Either pull in or delete the unused side.

- Provider wiring: boot.dart injects clientFactory/onClientReady;
  app.dart re-wraps in Provider.value. Consolidate into a single
  MoonrelayScope widget.

- Scattered widgets: 60+ _buildXxx private classes. Move them into
  lib/src/widgets/ for reuse.

- Encryption cache invalidation: SHIPPED. EncryptionService._onSync now
  clears _cachedUnverified alongside the per-user/device verification
  caches (lib/src/encryption/encryption_service.dart), so the unverified
  device count in the encryption overview no longer goes stale after a
  sync. The own-device list refresh is also throttled to once per 30s
  from the sync path (still immediate at init, after bootstrap, and
  after device deletion) so the per-sync HTTP/notify churn no longer
  stacks on the SDK's device-keys bookkeeping.

1.4 SDK device-keys churn (open, upstream)

The UI freezes during sync ticks on homeservers that constantly churn
device lists. The matrix SDK runs Client.updateUserDeviceKeys() after
every sync tick; when a user's device key list is marked outdated (the
server's device_lists.changed), the SDK re-queries /keys/query and
re-writes EVERY cached device key of the affected users to the database
in one transaction on the main isolate. Measured with
tool/device_keys_bench.dart: 24,000 device keys cost ~720ms per sync
(~560ms of it in the DB transaction alone, the rest in key parsing and
JSON encoding on the main isolate). On the user's homeserver the log
shows 24k-48k device keys rewritten on almost every sync.

The app cannot stop this from the outside; the fix belongs upstream
(batch the device-key writes, skip the re-store when the key hash is
unchanged, or move updateUserDeviceKeys off the sync path). Local
mitigations shipped: throttled own-device refresh and cache-first
devicesForUser (lib/src/encryption/encryption_service.dart). The
"Already seen Device ID has been added again" / "Invalid device"
warnings are server-data artifacts (device ID reuse / malformed keys),
not app misuse.


2. Open features

2.1 Communication surface

Recovery-key save dialog (post-bootstrap). bootstrap_screen.dart shows
a reminder that the SDK encrypts the key but cannot display it. We want
action buttons: "I saved it" and "Later". Strings go in app_en.arb.

The following previously-tracked surface items have shipped:

- Per-room encryption badge in RoomsPane - wired at
  lib/src/widgets/rooms_pane.dart:576 (RoomEncryptionBadge).
- "Rotate megolm session" - wired at
  lib/src/screens/room_details_page.dart:107, backed by
  EncryptionService.rotateMegolmSession
  (lib/src/encryption/encryption_service.dart:148).
- "Export E2EE keys" - wired at
  lib/src/screens/encryption/encryption_overview.dart:375, backed by the
  SSSS export path and confirmed via dialog (encryptionExportKeysConfirm).

2.2 Timeline / chat

- Reply expand / collapse: chat_event.dart renders replies inline; there
  is no affordance for a thread-mode view.
- Sticker sender label: sticker messages are routed through
  StickerMessageType (lib/src/chat/chat_event.dart:222 and 244) and
  rendered with the same sender-name treatment as images. Differentiate
  the label (e.g. "Sent a sticker:") in
  lib/src/chat/timeline_item_sender_name_and_timestamp.dart.
- Push notifications: NotificationService is local-only; OS push bridge
  is not wired.

The following previously-tracked timeline items have shipped:

- Mention vs highlight distinction in room list - _RoomUnreadBadges
  (lib/src/widgets/rooms_pane.dart:457) keys off Room.highlightCount
  first and falls back to Room.notificationCount.
- Off-thread Markdown - MarkdownToHtml.convertAsync
  (lib/src/helpers/markdown_to_html.dart:55) runs the parser on a
  background isolate via compute(); the chat-box send path awaits the
  async variant.

2.3 Right-sidebar expansion

Four views today: roomInfo, members, threads, pinned. Search, member
management, settings, and avatar uploads stay as full-page routes.
Decide whether the sidebar should grow or be replaced with context menus.

2.4 Room management

The following previously-tracked room-management items have shipped:

- Knock-accept confirmation dialog: _approve in
  lib/src/screens/room_settings_page.dart:1666 shows display name plus
  Matrix ID plus a "View profile" link before calling the underlying
  approve API.
- In-room search result highlights: _HighlightedText plus
  _MatchCountChip in lib/src/chat/in_room_search_panel.dart:690
  highlight matching terms in result tiles and surface a match count
  pill next to the sender name.


3. Features shipped (July 2026 audit pass)

3.1 Messaging and chat

- Message edit (m.replace) send plus indicator plus history viewer:
  edit_message_dialog.dart, edit_history_dialog.dart, and the
  _EditedMarker in chat_event.dart.
- Audio in-app player: audio_message_type.dart (scrub slider, save
  button).
- Video inline playback: video_message_type.dart (height-constrained,
  tap-to-play, fullscreen).
- Image/GIF height-constrain: image_message_type.dart (BoxFit.contain
  for panoramics).
- Voice-note recorder: voice_recorder_dialog.dart (mic button in
  composer toolbar).
- Location messages: share_location_dialog.dart,
  location_message_type.dart (open-in-maps).
- Polls (MSC3381): poll_send_dialog.dart, poll_message_type.dart.
- Typing notifications: typing_indicator.dart (animated footer,
  auto-stop after 4s).
- Per-message read receipts: receipt_avatars.dart (up to 5 avatars plus
  "+N").
- Slash commands: /me -> m.emote, /shrug, unknown -> snackbar
  (chat_box.dart:_send).
- Delivery indicator on outgoing messages:
  lib/src/chat/events/delivery_indicator.dart consumed in
  lib/src/chat/timeline_item.dart:251.

3.2 Rooms / users / spaces

- Room version display plus upgrade:
  room_settings_page.dart:_upgradeRoom.
- Knock approve/deny UI with confirmation dialog: _KnockRequestsSection
  in room settings; _approve at
  room_settings_page.dart:1666.
- Room editor tiles: join rule, history visibility, encryption, alias,
  guest access, power levels.
- Own-profile editor: display name, status message, presence (hub
  my_profile_page.dart).
- DM pane dedup: LeftPaneChoice.friends uses
  RoomsPane(roomFilter: isDirectChat).
- Per-room encryption badge in rooms list: encryption_badge.dart
  consumed in rooms_pane.dart:576.
- Highlight-vs-unread badge split: _RoomUnreadBadges in
  rooms_pane.dart:457.
- Rotate megolm session from room details:
  room_details_page.dart:107, encryption_service.dart:148.
- Export E2EE keys from encryption overview:
  encryption_overview.dart:375.

3.3 Platform support

- Permissions wired: record (mic) and geolocator (location) via
  permission_handler.
- Cleanup: friend_chats_pane.dart and own_user_profile.dart deleted.
- Global keyboard shortcuts mounted: Ctrl+K (command palette),
  Ctrl+Shift+K (global search), and ? (cheat-sheet overlay) via
  GlobalShortcutListener (dashboard_layout.dart:260,
  global_shortcut_listener.dart:34).
- Per-room notification preferences sheet (showRoomNotificationSheet)
  reachable from room details (room_details_page.dart:1294) and room
  settings (room_settings_page.dart:29).


4. Future work

Expected timeline: 2027 and beyond (maybe)

- Custom events (events v3): Git events, ~~Map events~~ this exists, realtime
  audio/video chat.
- Application fundamentals v2: background process optimisation, tighter
  system integration.


5. Wishlist

Extremely long-term; listed here to keep the design flexible.

- Server SDK v1 - server-side Matrix SDK.
- Client SDK v1 - alternative chat protocols, like XMPP.


See WORK_DONE.md for the closed-work ledger.


6. Feature catalogue (aka wishlist of what we need)

6.1 VoIP / WebRTC calls
(Need to investigate how matrix-dart sdk and Fluffychat handle any of these)
What we are missing:
- Voice calls (1:1): no m.call invite/hangup/answer anywhere. Entirely missing.
- Video calls (1:1): same gap. No camera track support for calls.
- Group calls: no MSC3401 or native group VoIP.
- Screen sharing: no desktop-capture integration.
- Call history: no m.call event renderer in the timeline.

6.2 Location & maps

- Embedded map display: location_message_type.dart renders lat/lon as
  monospace text + an "Open in Maps" button. There is no map tile
  renderer (OSM / MapLibre / google_maps_flutter). See
  lib/src/chat/events/matrix_events/Message/location/location_message_type.dart.
- Map picker in composer: share_location_dialog.dart reads current GPS
  position only. No interactive map to pick a point or search a POI.
  See lib/src/chat/share_location_dialog.dart.

6.3 Composer & messaging

- Slash commands: only /me and /shrug exist. Missing /join, /leave,
  /nick, /topic, /flip, /tableflip, /html, etc. See
  lib/src/chat/chat_box.dart.
- Emoji auto-complete: no :smile: -> smiley conversion while typing.
- Rich text / WYSIWYG editor: composer inserts Markdown syntax only.
  No live preview or rich-text editing mode.
- Link previews: URL messages render as plain text. No inline preview
  card (Open Graph / oEmbed) for links shared in chat.
- Scheduled / send-later messages: no future-delivery affordance.
- Message effects: no birthday, fireworks, or confetti overlays.
- Message translations: no "Translate" action on messages.
- Message bookmarks: no local bookmark/star collection for messages.
- Voice message playback: received audio from other users shows the
  generic audio player (scrub + play). No dedicated voice-message UI
  with speed control or waveform. See
  lib/src/chat/events/matrix_events/Message/audio/audio_message_type.dart.
- Custom emoji / sticker packs: sticker picker exists but no
  upload/import/management UI for custom sets. See
  lib/src/chat/chat_box_sticker_picker.dart.

6.4 Rooms & spaces

- Invite-to-room dialog: no dedicated invite dialog in the room header.
  Invite is only accessible from the user profile page
  (lib/src/screens/user_profile.dart:830) and room settings
  (lib/src/screens/room_settings_page.dart:1729). Create a standalone
  InviteDialog with user search + multi-select + reason field.
- Space creation wizard: no guided flow for creating spaces with name,
  avatar, purpose, and initial child rooms. See
  lib/src/screens/space_settings_page.dart.
- Space membership management: no UI to browse/manage space members,
  approve/deny space membership requests.
- Space drag-reorder in navigation pane: no drag-to-reorder spaces.
  Persisted locally. See lib/src/widgets/spaces_pane.dart.
- Room tagging / labels: no custom tag system. Rooms are organised by
  space membership only.
- Room directory favourites: no local star/bookmark for public rooms.
- Room upgrade flow: m.room.tombstone creation and guided re-join are
  not wired in the UI. See
  lib/src/screens/room_settings_page.dart.
- Power level matrix editor: per-user power levels are set via
  individual dialogs. No grid view of all users x permission levels.
  See lib/src/screens/room_settings_page.dart.

6.5 Platform & integration

- Matrix widget support: no embedded widget URLs (Etherpad, Jitsi,
  etc.). The SDK can fire widget-open events but there is no renderer.
- Bridge management UI: no UI for viewing or managing Matrix bridges
  (Telegram, WhatsApp, Slack, IRC).
- Drag-and-drop file upload: desktop client has no drag-to-attach on
  the chat area.
- Auto-start on boot: no "Launch at system startup" preference.
- App lock / passcode: no local unlock on app resume.
- Spell check in composer: no OS spell-checker integration.
- Offline / low-connectivity mode: no graceful degradation when the
  network is down. Sends throw errors instead of queueing.
- Export chat history: no export-to-file (JSON / HTML / plain text).
- Accessibility pass: no systematic screen-reader, contrast, or
  keyboard-navigation audit.

6.6 Encryption & security

- Self-verification badge: no per-device trust indicator in the user's
  own device list that explains whether this session is verified.
- Verified identity badge: no verified checkmark next to user display
  names in timeline messages (only available in the sidebar / profile).
- Message-level encryption info: no per-message "encrypted with..."
  info popup showing algorithm, session ID, and sender device.
- Security audit log: no log of verification events, device additions,
  or key backup state changes.

6.7 Internationalization

- Language coverage: only English (app_en.arb) and Persian/Farsi
  (app_fa.arb). No DE, FR, ES, JA, ZH, RU, PT, IT, KO, AR, NL, PL,
  SV, TR, VI, or TH. See lib/src/localization/.

6.8 Testing

- Settings page widget tests: 14 settings UI pages in
  lib/src/screens/hub_screen/settings/ have zero widget test coverage.
  Only unit tests exist for the settings model layer.
- Integration tests for room operations: invite, kick, ban, room
  creation, space creation are not covered by integration_test/.
- Integration test mock gaps: room_flow_test and logout_test still
  404 on unmocked endpoints after login (`/devices`, room
  `/messages` pagination, `/read_markers`), and the second test in a
  file can hit "attempt to write a readonly database" on the shared
  temp DB during teardown of the previous test's client. See
  integration_test/room_flow_test.dart and
  integration_test/helpers/test_app_boot.dart.
- L10n smoke tests: no automated check that every .arb key renders
  without crash in both languages across all screens.
- Performance benchmark suite: no regression benchmarks for timeline
  scroll, startup time, sync processing, or memory pressure.

6.9 Refactor candidates (from audit)

- VoIP wiring surface: pubspec.yaml needs dart_webrtc, flutter_webrtc,
  and a Matrix call transport package before any call feature can ship.
- Location map surface: pubspec.yaml needs a map rendering package
  (map_launcher already exists for "Open in Maps").
- Composer expansion surface: slash-command registry and emoji-complete
  engine would share a common autocomplete widget.
