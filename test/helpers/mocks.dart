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

import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/services/deep_link_service.dart';

// ---------------------------------------------------------------------------
// Mocktail-based mocks for Matrix SDK types and app dependencies
// ---------------------------------------------------------------------------

class MockClient extends Mock implements Client {
  MockClient() {
    registerFallbackValue(Uri());
  }
}

/// A stream of [SyncStatusUpdate] that can be used to simulate sync status
/// changes in tests.
class MockSyncStatusUpdate extends Mock implements SyncStatusUpdate {
  @override
  // ignore: overridden_fields
  final SyncStatus status;
  MockSyncStatusUpdate({this.status = SyncStatus.finished});

  @override
  String toString() => 'MockSyncStatusUpdate($status)';
}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class MockUser extends Mock implements User {}

class MockProfile extends Mock implements Profile {}

class MockLogger extends Mock implements Logger {}

class MockSyncUpdate extends Mock implements SyncUpdate {}

class MockAccountManager extends Mock implements AccountManager {}

class MockEncryptionService extends Mock implements EncryptionService {}

class MockDeepLinkService extends Mock implements DeepLinkService {}
