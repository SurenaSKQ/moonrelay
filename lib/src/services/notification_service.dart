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

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

/// Manages desktop notifications for Matrix events.
///
/// Listens to the Matrix sync stream and shows OS-level desktop
/// notifications for new messages in non-muted rooms when the
/// global notification toggle is enabled.
///
/// Per-room mute preferences are persisted via SharedPreferences.
class NotificationService {
  static const String _mutedRoomsKey = 'notification_muted_rooms';
  static const String _lastEventIdsKey = 'notification_last_event_ids';

  final Client _client;
  final SettingsController _settings;
  final CurrentRoom _currentRoom;
  final Logger _log;
  FlutterLocalNotificationsPlugin? _plugin;
  StreamSubscription? _syncSubscription;
  final Set<String> _notifiedEventIds = {};
  Set<String> _mutedRooms = {};
  final Map<String, String> _lastNotifiedEventIds = {};
  final Map<String, int> _groupNotifiedCounts = {};
  bool _loadedMuted = false;

  /// Fixed notification ID for group chat summaries so each new summary
  /// replaces the previous one rather than stacking.
  static const int _groupSummaryNotificationId = 0x47727570; // 'Group' crc-ish

  NotificationService._(
    this._client,
    this._settings,
    this._currentRoom,
    this._log,
  );

  /// Create and initialise the notification service.
  static Future<NotificationService> init({
    required Client client,
    required SettingsController settings,
    required CurrentRoom currentRoom,
    required Logger log,
  }) async {
    final service = NotificationService._(client, settings, currentRoom, log);
    await service._initPlugin();
    await service.loadMutedRooms();
    await service._loadLastEventIds();
    await service._loadGroupNotifiedCounts();
    service._startListening();
    log.i('Notification service initialised');
    return service;
  }

  Future<void> _initPlugin() async {
    try {
      _plugin = FlutterLocalNotificationsPlugin();

      // Register the platform-specific implementation manually — FFI
      // plugins don't go through GeneratedPluginRegistrant and the
      // default FlutterLocalNotificationsPlatform.instance stays unset.
      if (defaultTargetPlatform == TargetPlatform.windows) {
        FlutterLocalNotificationsPlatform.instance =
            FlutterLocalNotificationsWindows();
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'Moonrelay',
        appUserModelId: 'Moonrelay',
        guid: '4a8b9c7d-3e2f-1a5b-8d6c-9f0e7a2b3c4d',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
        macOS: iosSettings,
        windows: windowsSettings,
      );

      await _plugin!.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
    } catch (e) {
      _log.w('Notification plugin init failed', error: e);
    }
  }

  /// Called when the user clicks a notification.
  void _onNotificationTap(NotificationResponse response) {
    try {
      windowManager.show();
      windowManager.focus();
    } catch (_) {}
  }

  void _startListening() {
    _syncSubscription = _client.onSync.stream.listen(
      (_) => _processRooms(),
      onError: (e) => _log.w('Sync stream error in notification service', error: e),
    );
  }

  void _processRooms() {
    if (!_settings.notificationsEnabled) return;

    bool changed = false;
    bool groupChanged = false;

    // Group summary accumulators.
    int totalGroupUnread = 0;
    int groupRoomCount = 0;
    String? singleGroupName;

    for (final room in _client.rooms) {
      if (room.membership != Membership.join) continue;
      if (_mutedRooms.contains(room.id)) continue;

      if (room.isDirectChat) {
        // ── Direct message: per-message notification ──
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
        // ── Group chat: accumulate for summary notification ──
        final currentCount = room.notificationCount;
        final lastCount = _groupNotifiedCounts[room.id];

        if (currentCount == lastCount) continue;

        _groupNotifiedCounts[room.id] = currentCount;
        groupChanged = true;

        // First time seeing this room — record the baseline count
        // without notifying so we don't spam for pre-existing messages.
        if (lastCount == null) continue;

        final delta = currentCount - lastCount;
        if (delta <= 0) continue; // count decreased (user read messages)

        final roomName = room.getLocalizedDisplayname();
        totalGroupUnread += delta;
        groupRoomCount++;
        singleGroupName = roomName; // last room with new messages wins for single-room case
      }
    }

    if (changed) {
      _persistLastEventIds();
    }
    if (groupChanged) {
      _persistGroupNotifiedCounts();
    }

    if (groupRoomCount > 0) {
      _sendGroupSummary(
        roomCount: groupRoomCount,
        totalUnread: totalGroupUnread,
        singleGroupName: groupRoomCount == 1 ? singleGroupName : null,
      );
    }
  }

  void _processEvent(Room room, Event event) {
    if (_notifiedEventIds.contains(event.eventId)) return;
    _notifiedEventIds.add(event.eventId);

    if (event.senderId == _client.userID) return;
    if (event.type != EventTypes.Message) return;

    // Skip if the user is viewing this room
    if (_currentRoom.room?.id == room.id) return;

    final body = event.content.tryGet('body') as String? ?? '';
    if (body.isEmpty) return;

    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final roomName = room.getLocalizedDisplayname();

    _showNotification(
      event.eventId,
      roomName,
      '$senderName: $body',
    );
  }

  /// Send a summary notification for group chat unread messages.
  ///
  /// For a single group: body shows the room name and count.
  /// For multiple groups: body shows the total unread and number of chats.
  void _sendGroupSummary({
    required int roomCount,
    required int totalUnread,
    String? singleGroupName,
  }) {
    final String title;
    final String body;

    if (singleGroupName != null) {
      title = singleGroupName;
      body = 'You have $totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'} in $singleGroupName';
    } else {
      title = 'Moonrelay';
      body = 'You have $totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'} in $roomCount ${roomCount == 1 ? 'chat' : 'chats'}';
    }

    _showNotification(_groupSummaryNotificationId.toString(), title, body);
  }

  Future<void> _showNotification(String eventId, String title, String body) async {
    if (_plugin == null) {
      _log.w('_showNotification: _plugin is null');
      return;
    }
    try {
      _log.d('_showNotification: calling plugin.show(id=${eventId.hashCode})');
      await _plugin!.show(
        id: eventId.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'moonrelay_channel',
            'Moonrelay',
            channelDescription: 'Matrix message notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(
            defaultActionName: 'Open',
          ),
          macOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );
      _log.d('_showNotification: plugin.show completed');
    } catch (e) {
      _log.w('_showNotification: plugin.show threw', error: e);
    }
  }

  /// Show a test notification (for debugging notification delivery).
  Future<void> showTestNotification() async {
    _log.d('showTestNotification: starting');
    if (_plugin == null) {
      throw StateError('Notification plugin not initialised');
    }
    await _plugin!.show(
      id: 'test'.hashCode,
      title: 'Moonrelay',
      body: 'This is a test notification from Moonrelay.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'moonrelay_channel',
          'Moonrelay',
          channelDescription: 'Matrix message notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(
          defaultActionName: 'Open',
        ),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
    _log.d('showTestNotification: completed without error');
  }

  // ── Persisted group notified counts ────

  Future<void> _loadGroupNotifiedCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('notification_group_counts');
      if (raw == null) return;
      for (final entry in raw) {
        final decoded = _decodePipeMap(entry);
        if (decoded == null) continue;
        for (final kv in decoded.entries) {
          final count = int.tryParse(kv.value);
          if (count != null) _groupNotifiedCounts[kv.key] = count;
        }
      }
      _log.d('Loaded ${_groupNotifiedCounts.length} group notified counts');
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
          'notification_group_counts', [jsonEncode(encoded)]);
    } catch (e) {
      _log.w('Failed to persist group notified counts', error: e);
    }
  }

  // ── Persisted last-notified event IDs ──

  Future<void> _loadLastEventIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_lastEventIdsKey);
      if (raw == null) return;
      for (final entry in raw) {
        final decoded = _decodePipeMap(entry);
        if (decoded == null) continue;
        _lastNotifiedEventIds.addAll(decoded);
      }
      _log.d('Loaded ${_lastNotifiedEventIds.length} last-notified event IDs');
    } catch (e) {
      _log.w('Failed to load last-notified event IDs', error: e);
    }
  }

  Future<void> _persistLastEventIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _lastEventIdsKey, [jsonEncode(_lastNotifiedEventIds)]);
    } catch (e) {
      _log.w('Failed to persist last-notified event IDs', error: e);
    }
  }

  /// Decode a `Map<String, String>` that was stored as a single JSON entry
  /// in a StringList.  Room and event IDs may legally contain `|`, so we
  /// no longer split on the first `|`.
  Map<String, String>? _decodePipeMap(String entry) {
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
    return null;
  }

  // ── Per-room mute preferences ───────────

  Future<void> loadMutedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Current format (StringList) ────────────────────────
      final raw = prefs.getStringList(_mutedRoomsKey);
      if (raw != null) {
        _mutedRooms = raw.where((id) => id.isNotEmpty).toSet();
      } else {
        // ── Migration from old comma-separated format ────────
        final oldRaw = prefs.getString(_mutedRoomsKey);
        if (oldRaw != null) {
          _mutedRooms =
              oldRaw.split(',').where((id) => id.isNotEmpty).toSet();
          await prefs.setStringList(_mutedRoomsKey, _mutedRooms.toList());
          await prefs.remove('${_mutedRoomsKey}_legacy');
        }
      }

      _loadedMuted = true;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_mutedRoomsKey, _mutedRooms.toList());
    } catch (e) {
      _log.w('Failed to save muted rooms', error: e);
    }
  }

  /// Dispose of the sync subscription.
  void dispose() {
    _syncSubscription?.cancel();
  }
}
