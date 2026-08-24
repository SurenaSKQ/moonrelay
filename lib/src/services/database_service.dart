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

import 'dart:io';

import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Handles per-account SQLite database lifecycle: schema version checks,
/// backup-before-wipe, and creation of [MatrixSdkDatabase] instances.
class DatabaseService {
  DatabaseService({
    required this.schemaVersion,
    required this.log,
  });

  final int schemaVersion;
  final Logger log;

  /// Opens (or creates) a SQLite database for the given [dbName], wrapping it
  /// in a [MatrixSdkDatabase] and wiping the file if the schema version
  /// changed since the last boot.
  Future<MatrixSdkDatabase> openDatabaseFor(String dbName) async {
    const String schemaVersionKey = 'db_schema_version';
    final prefs = await SharedPreferences.getInstance();
    final int? storedVersion = prefs.getInt(schemaVersionKey);
    final dbdir = await getApplicationSupportDirectory();
    final String dbPath = p.join(dbdir.path, dbName);

    if (storedVersion == null || storedVersion != schemaVersion) {
      log.i(
        'Database schema version changed ($storedVersion → $schemaVersion); '
        'wiping $dbName',
      );
      if (await File(dbPath).exists()) {
        // ── Backup before wipe ────────────────────────────
        final backupPath = '$dbPath.bak';
        try {
          await File(dbPath).copy(backupPath);
          log.i('Backed up old database to $backupPath');
        } catch (e) {
          log.w('Could not create database backup', error: e);
        }
        try {
          await sql.deleteDatabase(dbPath);
        } catch (e, s) {
          // The wipe failed; if we let [openDatabase] proceed the SDK
          // will read the old schema with the new version constant and
          // explode at runtime.  Re-throw with a clear prefix so the
          // boot pipeline surfaces a Recovery / exit dialog instead
          // of a `SqliteException` deep inside the SDK.
          log.e(
            'Database wipe failed for $dbPath  refusing to boot',
            error: e,
            stackTrace: s,
          );
          throw StateError(
            'Failed to delete stale database at $dbPath. '
            'Please close any running process holding the file and retry.',
          );
        }
      }
    }

    final database = await sql.openDatabase(dbPath);
    final dbobj = await MatrixSdkDatabase.init(
      'moonrelay',
      database: database,
      sqfliteFactory: databaseFactoryFfi,
    );
    await dbobj.open();

    // Persist the schema version only after the open succeeded.  Storing
    // it up front would hide a failed open on the next boot (the stale
    // file would no longer be wiped), which is exactly what the version
    // check exists to protect against.
    if (storedVersion == null || storedVersion != schemaVersion) {
      await prefs.setInt(schemaVersionKey, schemaVersion);
    }
    return dbobj;
  }
}
