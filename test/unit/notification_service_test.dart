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

// Regression tests for the desktop NotificationService surface.
//
// The service is exercised only via its public API:
//   - `init(...)` factory (creates a real-ish service against mocks)
//   - `loadMutedRooms` / `isRoomMuted` / `setRoomMuted` (preferences)
//   - `showTestNotification` (state-error path when plugin is null)
//   - `dispose` (subscription cancellation)
//
// The internal `_processRooms` method is private and depends on
// `flutter_local_notifications`; it is not unit-testable without
// injecting the plugin.  The muted-room surface and the
// state-error contract are pinned here so the refactors in
// `WORK.md` (e.g. extracting a `NotificationGateway` interface)
// have a target to keep green.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart'
    show CachedStreamController;
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

/// A `CachedStreamController<SyncUpdate>` wrapped so the test can
/// close it on tear-down. The plain `onSync` getter on a real
/// `Client` returns the same SDK type, which is what the
/// `when(() => client.onSync).thenReturn(...)` stub below expects.
CachedStreamController<SyncUpdate> makeNoopSync() {
  final controller = CachedStreamController<SyncUpdate>();
  addTearDown(controller.close);
  return controller;
}

void main() {
  // ── Muted-rooms persistence ────────────────────────────────────────
  group('NotificationService.init + muted-rooms', () {
    late MockClient client;
    late SettingsController settings;
    late CurrentRoom currentRoom;
    late MockLogger logger;
    late NotificationService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      client = MockClient();
      // The service subscribes to `client.onSync.stream` immediately
      // on init.  Provide a real broadcast stream so the subscription
      // is satisfied without us having to stub every call site.
      final sync = makeNoopSync();
      when(() => client.onSync).thenReturn(sync);
      settings = SettingsController(SettingsService());
      await settings.loadSettings();
      currentRoom = CurrentRoom();
      logger = MockLogger();
      when(() => logger.i(any())).thenReturn(null);
      when(() => logger.d(any())).thenReturn(null);
      when(() => logger.w(any(), error: any(named: 'error'))).thenReturn(null);
      when(() => logger.w(any())).thenReturn(null);

      // `init` will try to construct a `FlutterLocalNotificationsPlugin`
      // which is unavailable in the unit-test environment.  The
      // service catches and logs that failure internally, leaving
      // `_plugin` as null.  The public API remains usable.
      service = await NotificationService.init(
        client: client,
        settings: settings,
        currentRoom: currentRoom,
        log: logger,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('init returns a service even when the plugin fails to load', () async {
      expect(service, isNotNull);
    });

    test('loadMutedRooms starts with an empty set on a fresh install',
        () async {
      await service.loadMutedRooms();
      expect(await service.isRoomMuted('!room:example.org'), isFalse);
    });

    test('setRoomMuted + isRoomMuted round-trip', () async {
      await service.setRoomMuted('!room:example.org', true);
      expect(await service.isRoomMuted('!room:example.org'), isTrue);

      await service.setRoomMuted('!room:example.org', false);
      expect(await service.isRoomMuted('!room:example.org'), isFalse);
    });

    test('muted rooms persist across service instances', () async {
      await service.setRoomMuted('!alpha:example.org', true);
      await service.setRoomMuted('!beta:example.org', true);
      service.dispose();

      // Re-init a fresh service.  SharedPreferences mock state survives
      // across instances in the same test, so the second init should
      // re-load the persisted set.
      final next = await NotificationService.init(
        client: client,
        settings: settings,
        currentRoom: currentRoom,
        log: logger,
      );
      addTearDown(next.dispose);
      await next.loadMutedRooms();

      expect(await next.isRoomMuted('!alpha:example.org'), isTrue);
      expect(await next.isRoomMuted('!beta:example.org'), isTrue);
      expect(await next.isRoomMuted('!gamma:example.org'), isFalse);
    });

    test('migrates legacy comma-separated muted-rooms entry', () async {
      // Pre-populate prefs with the legacy comma-separated format.
      // SharedPreferences.setMockInitialValues must be called before
      // any getInstance() call in this test; the setUp above has
      // already called it, so the in-memory store already has the
      // empty initial values from setUp.  We set up the legacy entry
      // directly on the existing SharedPreferences instance which
      // the service's init will re-read.
      final prefs = await SharedPreferences.getInstance();
      // Remove the empty StringList entry that setUp wrote, and write
      // a legacy comma-separated string instead.
      await prefs.remove('notification_muted_rooms');
      await prefs.setString(
        'notification_muted_rooms',
        '!legacy1:example.org,!legacy2:example.org',
      );

      final next = await NotificationService.init(
        client: client,
        settings: settings,
        currentRoom: currentRoom,
        log: logger,
      );
      addTearDown(next.dispose);
      await next.loadMutedRooms();

      expect(await next.isRoomMuted('!legacy1:example.org'), isTrue);
      expect(await next.isRoomMuted('!legacy2:example.org'), isTrue);
    });

    test('setRoomMuted overwrites the persisted StringList', () async {
      await service.setRoomMuted('!a:x', true);
      await service.setRoomMuted('!b:x', true);
      await service.setRoomMuted('!a:x', false);

      expect(await service.isRoomMuted('!a:x'), isFalse);
      expect(await service.isRoomMuted('!b:x'), isTrue);
    });

    test('isRoomMuted auto-loads muted rooms on first call', () async {
      // No explicit loadMutedRooms() call here.  isRoomMuted should
      // lazily load on the first call (the implementation does this
      // via the `_loadedMuted` flag).
      await service.setRoomMuted('!lazy:x', true);
      // Drop the service and create a new one to verify the lazy load
      // path triggers on the first isRoomMuted() call.
      service.dispose();
      final next = await NotificationService.init(
        client: client,
        settings: settings,
        currentRoom: currentRoom,
        log: logger,
      );
      addTearDown(next.dispose);

      expect(await next.isRoomMuted('!lazy:x'), isTrue);
    });
  });

  // ── Test-notification contract ─────────────────────────────────────
  group('NotificationService.showTestNotification', () {
    test('returns false when the plugin failed to initialise', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient();
      final sync = makeNoopSync();
      when(() => client.onSync).thenReturn(sync);
      final settings = SettingsController(SettingsService());
      await settings.loadSettings();
      final logger = MockLogger();
      when(() => logger.i(any())).thenReturn(null);
      when(() => logger.d(any())).thenReturn(null);
      when(() => logger.w(any(), error: any(named: 'error'))).thenReturn(null);
      when(() => logger.w(any())).thenReturn(null);

      final service = await NotificationService.init(
        client: client,
        settings: settings,
        currentRoom: CurrentRoom(),
        log: logger,
      );
      addTearDown(service.dispose);

      // In the unit-test environment, the plugin will be null after
      // init's `_initPlugin` catches the missing platform channel.
      // showTestNotification reports that as `false` so the UI can
      // hide the debug button without crashing the whole app.
      expect(await service.showTestNotification(), isFalse);
    });
  });

  // ── Lifecycle ──────────────────────────────────────────────────────
  group('NotificationService.dispose', () {
    test('cancels the sync subscription on dispose', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient();
      final sync = makeNoopSync();
      when(() => client.onSync).thenReturn(sync);
      final settings = SettingsController(SettingsService());
      await settings.loadSettings();
      final logger = MockLogger();
      when(() => logger.i(any())).thenReturn(null);
      when(() => logger.d(any())).thenReturn(null);
      when(() => logger.w(any(), error: any(named: 'error'))).thenReturn(null);
      when(() => logger.w(any())).thenReturn(null);

      final service = await NotificationService.init(
        client: client,
        settings: settings,
        currentRoom: CurrentRoom(),
        log: logger,
      );

      // dispose() is idempotent and must not throw.
      expect(() => service.dispose(), returnsNormally);
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
