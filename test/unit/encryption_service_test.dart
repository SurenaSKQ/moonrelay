// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' as logger_pkg;
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockClient client;
  late logger_pkg.Logger logger;
  late CachedStreamController<SyncUpdate> syncController;
  late int getDevicesCalls;

  setUp(() {
    client = MockClient();
    logger = logger_pkg.Logger(level: logger_pkg.Level.off);
    syncController = CachedStreamController<SyncUpdate>();
    getDevicesCalls = 0;

    when(() => client.isLogged()).thenReturn(true);
    when(() => client.encryption).thenReturn(null);
    when(() => client.onSync).thenReturn(syncController);
    when(() => client.getDevices()).thenAnswer((_) async {
      getDevicesCalls++;
      return [Device(deviceId: 'DEV1')];
    });
  });

  tearDown(() async {
    await syncController.close();
  });

  SyncUpdate tick() => SyncUpdate(nextBatch: 'b$getDevicesCalls');

  /// Runs [EncryptionService.init] to completion. init() waits up to
  /// 5s for the SDK encryption object to appear (stubbed to null here),
  /// so the fake clock must be advanced past that before the sync
  /// listener is attached.
  Future<EncryptionService> pumpInit(WidgetTester tester) async {
    final enc = EncryptionService(client: client, logger: logger);
    unawaited(enc.init());
    await tester.pump(const Duration(seconds: 6));
    return enc;
  }

  testWidgets('device list refresh is throttled across sync ticks',
      (tester) async {
    final enc = await pumpInit(tester);
    // init() performs one forced device fetch.
    expect(getDevicesCalls, 1);

    // A burst of sync ticks within the throttle window must not re-fetch.
    for (var i = 0; i < 5; i++) {
      syncController.add(tick());
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(getDevicesCalls, 1,
        reason: 'per-sync device list refresh must be throttled');

    // An explicit force refresh bypasses the throttle.
    await enc.refresh();
    expect(getDevicesCalls, 2);
  });

  testWidgets('cached unverified aggregate is invalidated on sync tick',
      (tester) async {
    when(() => client.userID).thenReturn('@me:example.org');
    when(() => client.deviceID).thenReturn('DEV1');
    when(() => client.rooms).thenReturn(const <Room>[]);
    when(() => client.userDeviceKeys).thenReturn(const {});

    final enc = await pumpInit(tester);

    // First access computes and caches the aggregate from the single
    // own device (own device is skipped, so own = 0).
    final first = await enc.countUnverified();
    expect(first, (own: 0, other: 0));

    // The account gains a second device; without cache invalidation the
    // next count would keep returning the stale (0, 0).
    when(() => client.getDevices()).thenAnswer((_) async {
      getDevicesCalls++;
      return [Device(deviceId: 'DEV1'), Device(deviceId: 'DEV2')];
    });

    // A sync tick clears the cache; the forced refresh loads the new
    // device list, so the next access recomputes from it.
    syncController.add(tick());
    await tester.pump(const Duration(milliseconds: 800));
    await enc.refresh();
    final second = await enc.countUnverified();
    expect(second, (own: 1, other: 0),
        reason: 'unverified aggregate must recompute after a sync tick');
  });
}
