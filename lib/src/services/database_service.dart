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
///
/// Owns no long-lived resource and so has no `dispose`: every database
/// it opens is handed to the Matrix [Client] that wraps it, and the SDK
/// closes the handle from `Client.dispose`. It is deliberately absent
/// from the `ServiceRegistry` for the same reason; registering a no-op
/// disposer would imply an ownership that does not exist.
class DatabaseService {
  DatabaseService({
    required this.schemaVersion,
    required this.log,
    this.backupKeepCount = 1,
  });

  final int schemaVersion;
  final Logger log;

  /// How many timestamped `.bak` files to keep when a wipe happens, from
  /// `SettingsController.dbBackupKeepCount`. Zero means keep none, which
  /// is the privacy-consistent reading of a slider whose minimum is 0.
  ///
  /// Set once at construction rather than read per wipe, because a wipe
  /// happens at most once per boot per database and the alternative is
  /// threading a settings controller into a service that otherwise needs
  /// no user preferences.
  final int backupKeepCount;

  /// Opens (or creates) a SQLite database for the given [dbName], wrapping it
  /// in a [MatrixSdkDatabase] and wiping the file if the schema version
  /// changed since the last boot.
  Future<MatrixSdkDatabase> openDatabaseFor(String dbName) async {
    const String schemaVersionKey = 'db_schema_version';
    final prefs = await SharedPreferences.getInstance();
    final int? storedVersion = prefs.getInt('$schemaVersionKey:$dbName');
    final dbdir = await getApplicationSupportDirectory();
    final String dbPath = p.join(dbdir.path, dbName);

    if (storedVersion == null || storedVersion != schemaVersion) {
      log.i(
        'Database schema version changed ( -> ); '
        'wiping $dbName',
      );
      if (await File(dbPath).exists()) {
        // -- Backup before wipe ----------------------------
        // Timestamped rather than a fixed `.bak` name: the previous
        // fixed name meant every schema-bump wipe silently overwrote the
        // one before it, so there was exactly one backup in existence no
        // matter what the retention setting said.
        final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
              RegExp(r'[:.]'),
              '-',
            );
        final backupPath = '$dbPath.$stamp.bak';
        try {
          if (backupKeepCount > 0) {
            await File(dbPath).copy(backupPath);
            log.i('Backed up old database to $backupPath');
            await _pruneBackups(dbPath);
          } else {
            log.i('Skipping database backup; retention is set to 0');
          }
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
      // Keyed per database file. The previous single global key meant a
      // second account, still on an older schema, would read the version
      // the first account had just written and skip its own wipe, then run
      // an old schema against new code.
      await prefs.setInt('$schemaVersionKey:$dbName', schemaVersion);
    }
    return dbobj;
  }

  /// Deletes all but the newest [backupKeepCount] backups of [dbPath].
  ///
  /// Backups are named `<dbPath>.<iso-timestamp>.bak`, so the prefix
  /// matches both this database's backups and nothing else, and the ISO
  /// timestamps sort lexicographically in chronological order. Ordered
  /// newest-first and the tail deleted, so the retained set is the most
  /// recent N.
  Future<void> _pruneBackups(String dbPath) async {
    if (backupKeepCount <= 0) return;
    final dir = File(dbPath).parent;
    if (!await dir.exists()) return;
    final prefix = '$dbPath.';
    final backups = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(prefix) || !name.endsWith('.bak')) continue;
      backups.add(entity);
    }
    if (backups.length <= backupKeepCount) return;
    backups.sort((a, b) => b.path.compareTo(a.path));
    for (final stale in backups.skip(backupKeepCount)) {
      try {
        await stale.delete();
        log.i('Pruned old database backup ${p.basename(stale.path)}');
      } catch (e) {
        // Leaving one extra file on disk is not worth failing a boot
        // over; the next wipe will try again.
        log.w('Could not prune database backup ${stale.path}', error: e);
      }
    }
  }
}
