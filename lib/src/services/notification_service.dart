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

  final Client _client;
  final SettingsController _settings;
  final CurrentRoom _currentRoom;
  final Logger _log;
  FlutterLocalNotificationsPlugin? _plugin;
  StreamSubscription? _syncSubscription;
  final Set<String> _notifiedEventIds = {};
  Set<String> _mutedRooms = {};
  bool _loadedMuted = false;

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
    service._startListening();
    log.i('Notification service initialised');
    return service;
  }

  Future<void> _initPlugin() async {
    try {
      _plugin = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'Moonrelay',
        appUserModelId: 'Moonrelay',
        guid: '{4a8b9c7d-3e2f-1a5b-8d6c-9f0e7a2b3c4d}',
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

    for (final room in _client.rooms) {
      if (room.membership != Membership.join) continue;
      if (_mutedRooms.contains(room.id)) continue;

      // Only process if there's a new last event
      final event = room.lastEvent;
      if (event == null) continue;

      _processEvent(room, event);
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

  Future<void> _showNotification(String eventId, String title, String body) async {
    if (_plugin == null) return;
    try {
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
    } catch (e) {
      _log.w('Failed to show notification', error: e);
    }
  }

  // ── Per-room mute preferences ───────────

  Future<void> loadMutedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Migration from old comma-separated format ──────────
      final oldRaw = prefs.getString(_mutedRoomsKey);
      if (oldRaw != null) {
        _mutedRooms = oldRaw.split(',').where((id) => id.isNotEmpty).toSet();
        // Migrate to StringList format.
        await prefs.setStringList(_mutedRoomsKey, _mutedRooms.toList());
        await prefs.remove('${_mutedRoomsKey}_legacy');
      } else {
        final raw = prefs.getStringList(_mutedRoomsKey);
        if (raw != null) {
          _mutedRooms = raw.where((id) => id.isNotEmpty).toSet();
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
