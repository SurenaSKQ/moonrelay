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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  group('StoredAccount', () {
    test('toJson / fromJson round-trip', () {
      final account = StoredAccount(
        userId: '@alice:matrix.org',
        homeserver: 'matrix.org',
      );
      final json = account.toJson();
      final restored = StoredAccount.fromJson(json);

      expect(restored.userId, account.userId);
      expect(restored.homeserver, account.homeserver);
      expect(restored.databaseName, account.databaseName);
    });

    test('databaseName is filesystem-safe', () {
      final account = StoredAccount(
        userId: '@user:my-server.dev',
        homeserver: 'my-server.dev',
      );
      // The '@', ':', '.' and '-' should be replaced with '_'
      expect(account.databaseName, 'moonrelay__user_my_server_dev.db');
    });

    test('equality is based on userId', () {
      final a = StoredAccount(
        userId: '@alice:matrix.org',
        homeserver: 'matrix.org',
      );
      final b = StoredAccount(
        userId: '@alice:matrix.org',
        homeserver: 'different.org',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on different userId', () {
      final a = StoredAccount(
        userId: '@alice:matrix.org',
        homeserver: 'matrix.org',
      );
      final b = StoredAccount(
        userId: '@bob:matrix.org',
        homeserver: 'matrix.org',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('AccountManager', () {
    late AccountManager manager;

    setUp(() {
      manager = AccountManager(log: MockLogger());
    });

    tearDown(() {
      manager.dispose();
    });

    Future<void> initPrefs([Map<String, Object>? values]) async {
      SharedPreferences.setMockInitialValues(values ?? {});
      await SharedPreferences.getInstance();
    }

    group('load with empty storage', () {
      test('has no accounts after load', () async {
        await initPrefs();
        await manager.load();
        expect(manager.hasAccounts, isFalse);
        expect(manager.accounts, isEmpty);
        expect(manager.activeAccount, isNull);
        expect(manager.client, isNull);
      });
    });

    group('load with persisted accounts', () {
      test('restores a single account', () async {
        final accounts = [
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
        ];
        final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());

        await initPrefs({
          'moonrelay_saved_accounts': encoded,
          'moonrelay_active_account': '@alice:matrix.org',
        });
        await manager.load();

        expect(manager.hasAccounts, isTrue);
        expect(manager.accounts, hasLength(1));
        expect(manager.activeAccount?.userId, '@alice:matrix.org');
      });

      test('restores multiple accounts', () async {
        final accounts = [
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          StoredAccount(userId: '@bob:server.io', homeserver: 'server.io'),
        ];
        final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());

        await initPrefs({
          'moonrelay_saved_accounts': encoded,
          'moonrelay_active_account': '@bob:server.io',
        });
        await manager.load();

        expect(manager.accounts, hasLength(2));
        expect(manager.activeAccount?.userId, '@bob:server.io');
      });

      test('falls back to first account if active is missing', () async {
        final accounts = [
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          StoredAccount(userId: '@bob:server.io', homeserver: 'server.io'),
        ];
        final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());

        await initPrefs({
          'moonrelay_saved_accounts': encoded,
          // no active account key
        });
        await manager.load();

        expect(manager.activeAccount?.userId, '@alice:matrix.org');
      });
    });

    group('addOrUpdateAccount', () {
      test('adds a new account', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          client: MockClient(),
        );

        expect(manager.hasAccounts, isTrue);
        expect(manager.accounts, hasLength(1));
        expect(manager.activeAccount?.userId, '@alice:matrix.org');
      });

      test('replaces existing account with same userId', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'old.org'),
          client: MockClient(),
        );
        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'new.org'),
          client: MockClient(),
        );

        expect(manager.accounts, hasLength(1));
        expect(manager.activeAccount?.homeserver, 'new.org');
      });

      test('sets as active', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          client: MockClient(),
        );
        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@bob:server.io', homeserver: 'server.io'),
          client: MockClient(),
        );

        expect(manager.activeAccount?.userId, '@bob:server.io');
      });
    });

    group('removeSavedAccount', () {
      test('removes an account from the list', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          client: MockClient(),
        );
        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@bob:server.io', homeserver: 'server.io'),
          client: MockClient(),
        );

        await manager.removeSavedAccount('@alice:matrix.org');
        expect(manager.accounts, hasLength(1));
        expect(manager.activeAccount?.userId, '@bob:server.io');
      });

      test('clears active account when removing last', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          client: MockClient(),
        );

        await manager.removeSavedAccount('@alice:matrix.org');
        expect(manager.hasAccounts, isFalse);
        expect(manager.activeAccount, isNull);
      });
    });

    group('persistence', () {
      test('addOrUpdateAccount persists to SharedPreferences', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          client: MockClient(),
        );

        // Create a new manager and verify it loads the saved data
        final manager2 = AccountManager(log: MockLogger());
        await manager2.load();

        expect(manager2.hasAccounts, isTrue);
        expect(manager2.accounts, hasLength(1));
        expect(manager2.activeAccount?.userId, '@alice:matrix.org');

        manager2.dispose();
      });

      test('removeSavedAccount persists the change', () async {
        await initPrefs();
        await manager.load();

        await manager.addOrUpdateAccount(
          StoredAccount(userId: '@alice:matrix.org', homeserver: 'matrix.org'),
          client: MockClient(),
        );
        await manager.removeSavedAccount('@alice:matrix.org');

        final manager2 = AccountManager(log: MockLogger());
        await manager2.load();

        expect(manager2.hasAccounts, isFalse);

        manager2.dispose();
      });
    });
  });
}
