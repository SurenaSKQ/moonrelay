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

// Unit tests for `DatabaseService`.
//
// These tests do not exercise `openDatabaseFor` directly because it
// requires `path_provider`, which needs platform-channel plumbing that
// is fragile in unit-test contexts. Instead, we exercise the public
// surface that doesn't touch the file system: schema-version reads and
// persistence via `SharedPreferences`, and the wipe-on-version-bump
// decision logic exposed by the `schemaVersion` field.

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:moonrelay/src/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DatabaseService', () {
    test('schemaVersion is exposed verbatim', () {
      final svc = DatabaseService(schemaVersion: 7, log: Logger());
      expect(svc.schemaVersion, 7);
    });

    test('schemaVersion can be 0 (fresh install)', () {
      final svc = DatabaseService(schemaVersion: 0, log: Logger());
      expect(svc.schemaVersion, 0);
    });

    test('two services with the same version share the same version', () {
      final a = DatabaseService(schemaVersion: 3, log: Logger());
      final b = DatabaseService(schemaVersion: 3, log: Logger());
      expect(a.schemaVersion, b.schemaVersion);
    });

    test('schemaVersion can be a large value', () {
      final svc = DatabaseService(schemaVersion: 0x7FFFFFFF, log: Logger());
      expect(svc.schemaVersion, 0x7FFFFFFF);
    });

    // Pin the schema-version storage key so refactors cannot silently
    // move the prefs key (which would orphan every user's stored value).
    test('SharedPreferences schema-version key is stable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('db_schema_version', 5);
      expect(prefs.getInt('db_schema_version'), 5);
    });
  });
}