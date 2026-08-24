// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/services/deep_link_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

/// Manages desktop notifications for Matrix events.
///
/// Listens to the Matrix sync stream and shows OS-level desktop
/// notifications for new messages in non-muted rooms when the
/// global notification toggle is enabled.
///
/// Per-room mute preferences are persisted via SharedPreferences.
///
/// ## Notification IDs
///
/// The plugin's string-tag mode dedupes by tag on every supported
/// platform, so we use a stable per-event string composed of the room
/// id and event id. The previous implementation used
/// `eventId.hashCode` which is 32-bit; two distinct events routinely
/// collided within seconds on a busy room and silently replaced
/// each other. We now generate a deterministic tag as
/// `matrix:<roomId>:<eventId>` and the summary notification is
/// always tagged [groupSummaryTag].
///
/// ## Failure handling
///
/// Platform plugin initialisation can fail (sandboxed Linux,
/// locked-down Windows, missing notification permissions). When it
/// does, [init] completes and [isAvailable] returns `false`. The
/// rest of the service continues to work (muted rooms, debounced
/// persistence, notification switching) but [_showNotification]
/// no-ops silently because we never want a missing platform
/// notification surface to crash the app.
class NotificationService {
  static const String _mutedRoomsKey = 'notification_muted_rooms';
  static const String _lastEventIdsKey = 'notification_last_event_ids';

  /// Reserved tag for the running "X new messages in N chats"
  /// summary notification. The plugin deduplicates by tag on every
  /// supported platform so the same summary shows once at a time.
  static const String groupSummaryTag = 'moonrelay/group-summary';

  /// Maximum number of in-memory event-ids we track to avoid showing
  /// the same notification twice within a single boot. The on-disk
  /// `_lastNotifiedEventIds` map handles persistence across reboots;
  /// this Set is a cheap in-memory short-circuit and is bounded.
  static const int _notifiedIdsCacheLimit = 256;

  /// Default tag format for per-event notifications: combines the
  /// owning room and the Matrix event id so the plugin dedupes by
  /// `(room, event)` and we never collide two distinct events.
  static String _eventTag(String roomId, String eventId) =>
      'matrix:$roomId:$eventId';

  /// Builds the [NotificationDetails] used by every notification.
  /// Pulled out into a single helper because the channel / importance
  /// / priority are identical for direct messages, group summaries,
  /// and the debug test notification.
  ///
  /// On Windows, every notification gets a small action button row so
  /// users can triage new messages without bringing the window to the
  /// foreground first:
  ///
  /// -"Mark as read": silently clear the unread state for the
  ///   owning room without opening the app.
  /// -"Open": same behaviour as tapping the notification body
  ///   bring the window forward and navigate to the room.
  ///
  /// Other platforms fall through to their default tap behaviour
  /// (open the app), which the platform-specific plugin surfaces
  /// support for out of the box.
  static NotificationDetails _buildDetails(String? payload,
      {bool playSound = true}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'moonrelay_channel',
        'Moonrelay',
        channelDescription: 'Matrix message notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
      ),
      iOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(defaultActionName: 'Open'),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(
        actions: const <WindowsAction>[
          WindowsAction(
            content: 'Mark as read',
            arguments: 'action=markRead',
            activationType: WindowsActivationType.foreground,
          ),
          WindowsAction(
            content: 'Open',
            arguments: 'action=open',
            activationType: WindowsActivationType.foreground,
          ),
        ],
      ),
    );
  }

  /// Returns a JSON-encoded payload that tells the listener which
  /// room this notification belongs to and which action the user
  /// pressed (if any).  The listener splits this back into pieces.
  ///
  /// We deliberately embed `action` here (rather than relying on the
  /// plugin's `actionId` from the action button) so platforms that do
  /// not surface button presses (Linux, macOS, mobile) still receive
  /// the room context via the body tap path.
  static String? _encodePayload(String? matrixUri, {String action = 'open'}) {
    if (matrixUri == null || matrixUri.isEmpty) return null;
    return jsonEncode(<String, String>{
      'uri': matrixUri,
      'action': action,
    });
  }

  /// Decodes a payload produced by [_encodePayload].  Returns null on
  /// legacy payloads (a bare Matrix URI string) so older persisted
  /// state is still routable.
  static ({String matrixUri, String action})? _decodePayload(String raw) {
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final uri = decoded['uri'];
          if (uri is String) {
            final rawAction = decoded['action'];
            final action = rawAction is String ? rawAction : 'open';
            return (
              matrixUri: uri,
              action: action,
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  final Client _client;
  final SettingsController _settings;
  final CurrentRoom _currentRoom;
  final DeepLinkService? _deepLinkService;
  final Logger _log;
  FlutterLocalNotificationsPlugin? _plugin;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _persistDebouncer;
  bool _available = false;

  /// Bounded FIFO Set used to short-circuit double-notification
  /// within a single boot (when the SDK emits the same event id
  /// twice during one sync tick). We track insertion order via
  /// [_seenOrder] and evict the oldest entry once
  /// [_notifiedIdsCacheLimit] is reached so memory stays bounded
  /// across long sessions on active accounts.
  final Set<String> _notifiedEventIds = <String>{};
  final List<String> _seenOrder = <String>[];

  /// The active notification id is the deep-link payload, used so the
  /// user can tap a notification and be taken to the right room. We
  /// prefer Matrix uri style (`matrix:r/<id>`); falling back to the
  /// room id when we cannot resolve a Matrix uri.
  final void Function(String matrixUri)? _navigate;

  Set<String> _mutedRooms = {};
  final Map<String, String> _lastNotifiedEventIds = {};
  final Map<String, int> _groupNotifiedCounts = {};
  bool _loadedMuted = false;

  /// Whether the app window is currently focused (has input focus).
  /// Used by the [notifyWhenFocused] toggle to suppress notifications
  /// while the user is actively using the app.
  bool _hasFocus = true;

  /// Whether the app window was previously focused before a notification
  /// check.  Updated on each [_processEvent] call so we don't spam the
  /// window-manager bridge.
  bool _focusChecked = false;

  /// Static, read-only snapshot of the muted-room set; cross-service
  /// consumers (notably the system tray, which uses it to skip muted
  /// rooms when computing its unread badge) read from here.
  ///
  /// Updated on every successful [loadMutedRooms] and [setRoomMuted]
  /// call so it always reflects the live state without callers having
  /// to hold a reference to the singleton. Empty when no service is
  /// initialised.
  static Set<String> _mutedRoomsSnapshot = const <String>{};
  static Set<String> get mutedRoomsSnapshot =>
      Set<String>.unmodifiable(_mutedRoomsSnapshot);

  NotificationService._(
    this._client,
    this._settings,
    this._currentRoom,
    this._deepLinkService,
    this._navigate,
    this._log,
  );

  /// Whether the platform notification plugin initialised successfully.
  /// Surface for the UI to render a "notifications unavailable"
  /// banner or disable notification-related menu items. Never gates
  /// access to muted-rooms / preference state.
  bool get isAvailable => _available;

  /// Create and initialise the notification service. Returns the
  /// service instance which is always usable, even on platforms
  /// where the plugin failed to initialise. Callers that want to
  /// show notification-related UI should gate it on [isAvailable].
  ///
  /// [deepLinkService] is wired through [NotificationResponse.payload]
  /// so that tapping a notification routes the user to the room the
  /// notification was for; pass [onNavigate] instead to override the
  /// default behaviour (e.g. with a router-aware callback in tests).
  static Future<NotificationService> init({
    required Client client,
    required SettingsController settings,
    required CurrentRoom currentRoom,
    required Logger log,
    DeepLinkService? deepLinkService,
    void Function(String matrixUri)? onNavigate,
  }) async {
    final service = NotificationService._(
      client,
      settings,
      currentRoom,
      deepLinkService,
      onNavigate,
      log,
    );
    await service.loadMutedRooms();
    await service._loadLastEventIds();
    await service._loadGroupNotifiedCounts();
    final ok = await service._initPlugin();
    if (ok) {
      service._startListening();
    }
    log.i('Notification service initialised'
        '${ok ? '' : ' (plugin unavailable on this platform)'}');
    return service;
  }

  /// Initialises the platform plugin. Returns `true` on success; on
  /// failure logs the error and returns `false` so the rest of the
  /// service can still come up (muted-room state, persistence, etc).
  Future<bool> _initPlugin() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          macOS: DarwinInitializationSettings(),
          windows: WindowsInitializationSettings(
            appName: 'Moonrelay',
            appUserModelId: 'Moonrelay',
            guid: '4a8b9c7d-3e2f-1a5b-8d6c-9f0e7a2b3c4d',
          ),
        ),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _plugin = plugin;
      _available = true;
      return true;
    } catch (e) {
      _log.w('Notification plugin init failed; falling back to no-op',
          error: e);
      _plugin = null;
      _available = false;
      return false;
    }
  }

  /// Called when the user clicks a notification (body or action button).
  ///
  /// We try to navigate to the room the notification was for via the
  /// deep-link service or the navigation callback registered at init
  /// time.  For "mark as read" the app still comes forward so the user
  /// can see the result, but we suppress navigation so the timeline
  /// keeps the last room the user was viewing.
  void _onNotificationTap(NotificationResponse response) async {
    try {
      windowManager.show();
      windowManager.focus();
    } catch (_) {}

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // The plugin delivers the OS-level action id in `response.actionId`
    // ("action=markRead" / "action=open") for clicks on the action
    // buttons, but on body taps it is `null`.  We also embed the
    // intended action in the payload so platforms without action
    // support still receive a useful routing hint.
    final fromButton = response.actionId;
    String action = 'open';
    final String matrixUri;

    if (fromButton != null && fromButton.isNotEmpty) {
      // Plugin-supported action button path (Windows / Android).
      final params = Uri.tryParse('moonrelay://?$fromButton');
      action = params?.queryParameters['action'] ?? 'open';
    }

    final decoded = _decodePayload(payload);
    if (decoded != null) {
      matrixUri = decoded.matrixUri;
      // A body tap and an explicit "open" button share the same intent
      //  promote the body-tap default to "open".
      if (fromButton == null || fromButton.isEmpty) {
        action = 'open';
      }
    } else {
      // Legacy (pre-action) payloads: treat as open with the raw string
      // as the matrix URI.
      matrixUri = payload;
      action = 'open';
    }

    if (matrixUri.isEmpty) return;

    if (action == 'markRead') {
      await _markUriAsRead(matrixUri);
      // Still open the app; the user expects feedback that their tap
      // was registered.
    }

    final navigator = _navigate;
    if (navigator != null) {
      navigator(matrixUri);
    } else if (_deepLinkService != null) {
      _deepLinkService.processUri(matrixUri);
    }
  }

  /// Marks the room in the given matrix URI as read by sending a
  /// read-receipt up to the most recently known event.  Used by the
  /// "Mark as read" notification action so users can clear the badge
  /// without opening the room in the timeline.
  Future<void> _markUriAsRead(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return;
    final segments = parsed.pathSegments;
    if (segments.length < 2) return;
    // matrix:r/<roomid>  -> segments[0]=='r', segments[1] is room id
    // matrix:roomid/<roomid>/<eventid>
    final roomId =
        segments[0] == 'r' && segments.length >= 2 ? segments[1] : segments[0];
    if (roomId.isEmpty) return;

    try {
      final room = _client.getRoomById(roomId);
      if (room == null) return;
      final lastSynced = room.lastEvent;
      if (lastSynced == null) return;
      await room.setReadMarker(
        lastSynced.eventId,
        mRead: lastSynced.eventId,
      );
      // Mirror the read marker locally so the in-app badge reflects the
      // action immediately, even before the next sync delivers the
      // server-acknowledged state.
      _groupNotifiedCounts[room.id] = room.notificationCount;
      _lastNotifiedEventIds[room.id] = lastSynced.eventId;
      _persistDebouncer?.cancel();
      _persistDebouncer = Timer(
        const Duration(milliseconds: 750),
        () async {
          await _persistLastEventIds();
          await _persistGroupNotifiedCounts();
        },
      );
    } catch (e) {
      _log.w('Failed to mark room as read from notification action', error: e);
    }
  }

  void _startListening() {
    // Subscribe to onSync only; the onEvent stream is deprecated in
    // recent Matrix SDK versions. [_processRoomsIfChanged] short-
    // circuits on no-op ticks (same room, same last-event timestamp)
    // so the per-tick scan is cheap when nothing has actually moved.
    _subscriptions.add(
      _client.onSync.stream.listen((_) => _processRoomsIfChanged()),
    );
  }

  /// Calls [_processRooms] only when something has actually changed
  /// since the last tick.  Cheap O(rooms) signature check over each
  /// room's last event; if the cache is empty the first tick still
  /// runs so we never get stuck.
  ///
  /// The signature covers every room's last event ID, not just the room
  /// with the newest timestamp.  Tracking a single max-timestamp room
  /// would drop notifications for rooms whose new message has an older
  /// timestamp than the current global maximum.
  String? _lastProcessSignature;
  void _processRoomsIfChanged() {
    final all = _client.rooms;
    final buf = StringBuffer();
    var count = 0;
    for (final room in all) {
      final e = room.lastEvent;
      if (e == null) continue;
      buf.write(room.id);
      buf.write('#');
      buf.write(e.eventId);
      buf.write(';');
      count++;
    }
    final signature = '$count:$buf';
    if (signature == _lastProcessSignature) return;
    _lastProcessSignature = signature;
    _processRooms();
  }

  /// Refresh the cached focus state from the window manager.  Called
  /// at most once per notification flush so we don't hammer the platform
  /// bridge on every event.
  Future<void> _updateFocusState() async {
    if (_focusChecked) return;
    _focusChecked = true;
    try {
      _hasFocus = await windowManager.isFocused();
    } catch (_) {
      // Window manager unavailable (e.g. tests); assume focused.
      _hasFocus = true;
    }
  }

  void _processRooms() {
    if (!_settings.notificationsEnabled) return;

    // Refresh focus state once per sync tick so that the
    // notifyWhenFocused check in _processEvent uses a recent value
    // without making an async bridge call for every event.
    unawaited(_updateFocusState());

    bool changed = false;
    bool groupChanged = false;

    // Group summary accumulators.
    int totalGroupUnread = 0;
    int groupRoomCount = 0;
    String? lastGroupName;
    String? lastGroupRoomId;

    for (final room in _client.rooms) {
      if (room.membership != Membership.join) continue;
      if (_mutedRooms.contains(room.id)) continue;

      if (room.isDirectChat) {
        // -- Direct message: per-message notification --
        final event = room.lastEvent;
        if (event == null) continue;

        final lastSeenId = _lastNotifiedEventIds[room.id];
        if (event.eventId == lastSeenId) continue;

        // Persist the new event id immediately so a restart or crash
        // during the notification call won't re-notify for this event.
        _lastNotifiedEventIds[room.id] = event.eventId;
        changed = true;

        // First time seeing this room (fresh install or newly joined).
        // Record the baseline event id without notifying so we don't
        // spam notifications for pre-existing messages.
        if (lastSeenId == null) continue;

        _processEvent(room, event);
      } else {
        // -- Group chat: skip when DMs-only mode is active --
        if (_settings.notifyDmsOnly) continue;

        // -- Group chat: accumulate for summary notification --
        final currentCount = room.notificationCount;
        final lastCount = _groupNotifiedCounts[room.id];

        if (currentCount == lastCount) continue;

        _groupNotifiedCounts[room.id] = currentCount;
        groupChanged = true;

        // First time seeing this room: record the baseline count
        // without notifying so we don't spam for pre-existing messages.
        if (lastCount == null) continue;

        final delta = currentCount - lastCount;
        if (delta <= 0) continue; // count decreased (user read messages)

        totalGroupUnread += delta;
        groupRoomCount++;
        // Last room with new messages wins for the single-room
        // summary copy. Track the room id too so the deep-link
        // payload doesn't have to do a name-based lookup.
        lastGroupName = room.getLocalizedDisplayname();
        lastGroupRoomId = room.id;
      }
    }

    // Debounce all persistence to once-per-burst: a single chat session
    // can shift the *_lastNotifiedEventIds and the group-count maps by
    // many entries per sync, and a half-written prefs blob is just as
    // wrong as a missing one. 750 ms is well under the SDK's default
    // 30 s long-poll and keeps the prefs disk write off the hot path.
    if (changed || groupChanged) {
      _persistDebouncer?.cancel();
      _persistDebouncer = Timer(
        const Duration(milliseconds: 750),
        () async {
          if (changed) await _persistLastEventIds();
          if (groupChanged) await _persistGroupNotifiedCounts();
        },
      );
    }

    if (groupRoomCount > 0) {
      _sendGroupSummary(
        roomCount: groupRoomCount,
        totalUnread: totalGroupUnread,
        singleGroupName: groupRoomCount == 1 ? lastGroupName : null,
        singleGroupRoomId: groupRoomCount == 1 ? lastGroupRoomId : null,
      );
    }
  }

  void _processEvent(Room room, Event event) {
    if (_notifiedEventIds.contains(event.eventId)) return;
    _rememberEventId(event.eventId);

    if (event.senderId == _client.userID) return;

    // Honour "don't notify when focused" toggle: suppress notification
    // when the app window has input focus and the user chose not to be
    // disturbed by foreground alerts.
    if (!_settings.notifyWhenFocused && _hasFocus) return;

    // Encrypted messages should still notify the user; the SDK
    // may not have decrypted the event by the time the notification
    // fires, in which case the body string is empty. We surface a
    // dedicated "(encrypted message)" placeholder so the user is not
    // left guessing whether a notification was suppressed.
    final isEncrypted = event.type == EventTypes.Encrypted ||
        (event.messageType.isEmpty && event.content['m.ciphertext'] != null);
    // Use the generic [Map.tryGet] so a non-string body from a
    // malformed or foreign event returns null instead of throwing a
    // TypeError inside the sync listener (which would abort the rest
    // of the room scan).
    final rawBody = event.content.tryGet<String>('body') ?? '';
    final isUndecryptedPlaceholder = isEncrypted && rawBody.isEmpty;
    final body = isUndecryptedPlaceholder ? 'Encrypted message' : rawBody;
    if (body.isEmpty) return;

    // Skip if the user is viewing this room
    if (_currentRoom.room?.id == room.id) return;

    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final roomName = room.getLocalizedDisplayname();

    _showNotification(
      _eventTag(room.id, event.eventId),
      roomName,
      isUndecryptedPlaceholder
          ? '$senderName sent an encrypted message'
          : '$senderName: $body',
      payload: _encodePayload('matrix:r/${room.id}'),
      playSound: _settings.notificationSoundEnabled,
    );
  }

  /// Send a summary notification for group chat unread messages.
  ///
  /// For a single group: body shows the room name and count.
  /// For multiple groups: body shows the total unread and number of
  /// chats.
  void _sendGroupSummary({
    required int roomCount,
    required int totalUnread,
    String? singleGroupName,
    String? singleGroupRoomId,
  }) {
    final String title;
    final String body;

    if (singleGroupName != null) {
      title = singleGroupName;
      body =
          'You have $totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'} in $singleGroupName';
    } else {
      title = 'Moonrelay';
      body =
          'You have $totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'} in $roomCount ${roomCount == 1 ? 'chat' : 'chats'}';
    }

    // Use the deep-link payload only for the single-room case so
    // tapping it jumps straight to the room; for the multi-room case
    // we leave the payload empty and the listener just brings the
    // window forward.  We have the room id directly from the caller
    // so no scan over all rooms is needed.
    String? payload;
    if (singleGroupRoomId != null) {
      payload = _encodePayload('matrix:r/$singleGroupRoomId');
    }
    _showNotification(
      groupSummaryTag,
      title,
      body,
      payload: payload,
      playSound: _settings.notificationSoundEnabled,
    );
  }

  Future<void> _showNotification(
    String tag,
    String title,
    String body, {
    String? payload,
    bool playSound = true,
  }) async {
    final plugin = _plugin;
    if (plugin == null) {
      // Plugin unavailable (sandbox / no notification daemon / etc).
      // Not an error: the rest of the app keeps working.
      return;
    }
    try {
      await plugin.show(
        id: 0, // ignored when a tag is provided on every supported platform
        title: title,
        body: body,
        notificationDetails: _buildDetails(payload, playSound: playSound),
        payload: payload,
      );
    } catch (e) {
      _log.w('_showNotification: plugin.show threw', error: e);
    }
  }

  /// Show a test notification (for debugging notification delivery).
  ///
  /// Safe to call even when the plugin failed to initialise: returns
  /// `false` instead of throwing so the caller (debug-only menu item)
  /// can disable the affordance when notifications are unavailable.
  Future<bool> showTestNotification() async {
    final plugin = _plugin;
    if (plugin == null) return false;
    await plugin.show(
      id: 0,
      title: 'Moonrelay',
      body: 'This is a test notification from Moonrelay.',
      notificationDetails: _buildDetails(null),
    );
    return true;
  }

  /// Records [eventId] in the bounded in-memory cache, evicting the
  /// oldest entry once the cache overflows.
  void _rememberEventId(String eventId) {
    if (_notifiedEventIds.add(eventId)) {
      _seenOrder.add(eventId);
    }
    while (_seenOrder.length > _notifiedIdsCacheLimit) {
      final oldest = _seenOrder.removeAt(0);
      _notifiedEventIds.remove(oldest);
    }
  }

  // -- Persisted group notified counts ----

  Future<void> _loadGroupNotifiedCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('notification_group_counts');
      if (raw == null) return;
      for (final entry in raw) {
        final decoded = _decodeJsonMap(entry);
        if (decoded == null) continue;
        for (final kv in decoded.entries) {
          final count = int.tryParse(kv.value);
          if (count != null) _groupNotifiedCounts[kv.key] = count;
        }
      }
    } catch (e) {
      _log.w('Failed to load group notified counts', error: e);
    }
  }

  Future<void> _persistGroupNotifiedCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = <String, String>{
        for (final entry in _groupNotifiedCounts.entries)
          entry.key: entry.value.toString(),
      };
      await prefs.setStringList(
        'notification_group_counts',
        [jsonEncode(encoded)],
      );
    } catch (e) {
      _log.w('Failed to persist group notified counts', error: e);
    }
  }

  // -- Persisted last-notified event IDs --

  Future<void> _loadLastEventIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_lastEventIdsKey);
      if (raw == null) return;
      for (final entry in raw) {
        final decoded = _decodeJsonMap(entry);
        if (decoded == null) continue;
        _lastNotifiedEventIds.addAll(decoded);
      }
    } catch (e) {
      _log.w('Failed to load last-notified event IDs', error: e);
    }
  }

  Future<void> _persistLastEventIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _lastEventIdsKey,
        [jsonEncode(_lastNotifiedEventIds)],
      );
    } catch (e) {
      _log.w('Failed to persist last-notified event IDs', error: e);
    }
  }

  /// Decode a `Map<String, String>` previously stored as a single
  /// JSON entry in a `List<String>`. Older Moonrelay versions
  /// stored entries as `roomId|eventId`; those rows are skipped
  /// silently and we silently migrate forward.
  Map<String, String>? _decodeJsonMap(String entry) {
    if (entry.startsWith('{')) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map) {
          return {
            for (final kv in decoded.entries)
              if (kv.key is String && kv.value is String)
                kv.key as String: kv.value as String,
          };
        }
      } catch (_) {}
    }
    return null;
  }

  // -- Per-room mute preferences -----------

  Future<void> loadMutedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // -- Current format (StringList) ------------------------
      // getStringList uses `as List<String>?` internally and throws
      // TypeError when the stored value is a legacy comma-separated
      // String rather than a List<String>. Catch that gracefully so
      // the migration path below can handle it.
      List<String>? raw;
      try {
        raw = prefs.getStringList(_mutedRoomsKey);
      } catch (_) {}
      if (raw != null) {
        _mutedRooms = raw.where((id) => id.isNotEmpty).toSet();
      } else {
        // -- Migration from old comma-separated format --------
        final oldRaw = prefs.getString(_mutedRoomsKey);
        if (oldRaw != null) {
          _mutedRooms = oldRaw.split(',').where((id) => id.isNotEmpty).toSet();
          await prefs.setStringList(_mutedRoomsKey, _mutedRooms.toList());
          await prefs.remove('${_mutedRoomsKey}_legacy');
        }
      }

      _loadedMuted = true;
      _mutedRoomsSnapshot = Set<String>.unmodifiable(_mutedRooms);
    } catch (e) {
      _log.w('Failed to load muted rooms', error: e);
    }
  }

  /// Returns `true` if [roomId] is muted.
  Future<bool> isRoomMuted(String roomId) async {
    if (!_loadedMuted) await loadMutedRooms();
    return _mutedRooms.contains(roomId);
  }

  /// Mute or unmute [roomId].
  Future<void> setRoomMuted(String roomId, bool muted) async {
    if (muted) {
      _mutedRooms.add(roomId);
    } else {
      _mutedRooms.remove(roomId);
    }
    _mutedRoomsSnapshot = Set<String>.unmodifiable(_mutedRooms);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_mutedRoomsKey, _mutedRooms.toList());
    } catch (e) {
      _log.w('Failed to save muted rooms', error: e);
    }
  }

  /// Cancels the sync subscription and any pending persistence work.
  /// Safe to call multiple times.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _persistDebouncer?.cancel();
    _persistDebouncer = null;
    // Reset the in-memory caches so a re-`init` after `dispose`
    // doesn't observe stale state. Persisted state survives in
    // SharedPreferences by design.
    _notifiedEventIds.clear();
    _seenOrder.clear();
    _lastNotifiedEventIds.clear();
    _groupNotifiedCounts.clear();
    _mutedRooms = <String>{};
    _mutedRoomsSnapshot = const <String>{};
    _loadedMuted = false;
    _plugin = null;
    _available = false;
  }

  // -- Public helpers used by the timeline for "catch up" affordances --

  /// Returns the most recently notified event id for [roomId] or an
  /// empty string when no notification has ever fired for the room.
  /// Used by the timeline to compute the unread gap and offer a
  /// "Jump to first unread" affordance when the room is opened.
  String lastNotifiedEventIdFor(String roomId) =>
      _lastNotifiedEventIds[roomId] ?? '';

  /// Returns the last persisted group-unread count for [roomId] or
  /// `null` when no baseline has been recorded yet.
  int? lastNotifiedGroupCountFor(String roomId) => _groupNotifiedCounts[roomId];

  /// Mirrors the timeline's "I just marked this room read" event into
  /// the local notification bookkeeping so the next sync tick doesn't
  /// emit a stale "you have N new messages" notification for a room
  /// the user has just caught up on.
  ///
  /// This is the timeline-side counterpart to [_markUriAsRead]: both
  /// paths funnel through the same debounced persistence so the prefs
  /// blob stays consistent regardless of which surface the user used to
  /// clear the badge.
  void onRoomReadByTimeline(String roomId, String eventId) {
    final room = _client.getRoomById(roomId);
    if (room == null) return;
    _lastNotifiedEventIds[roomId] = eventId;
    _groupNotifiedCounts[roomId] = room.notificationCount;
    _persistDebouncer?.cancel();
    _persistDebouncer = Timer(
      const Duration(milliseconds: 750),
      () async {
        await _persistLastEventIds();
        await _persistGroupNotifiedCounts();
      },
    );
  }
}

