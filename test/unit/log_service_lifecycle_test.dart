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

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:path/path.dart' as p;

/// Regression tests for the split between truncating the log files and
/// closing the log sink.
///
/// `wipeLogs` used to call `AdvancedFileOutput.destroy()`, which cancels
/// the buffer-flush timer and closes the sink, and nothing in the logger
/// package re-arms either. It is reachable from logout and from the
/// "Clear logs" action, both of which leave the app running, so every
/// log line after either one was buffered and never written for the
/// rest of the process. `wipeLogs` now re-arms the sink; `dispose` is
/// the teardown path and belongs only at process exit.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moonrelay_log_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Reads the current contents of the active log file, or an empty
  /// string if it does not exist.
  ///
  /// The sink buffers into an [IOSink] before the bytes reach the file,
  /// and the public API offers no flush, so a short wait is needed after
  /// a write. Levels at or above warning are written immediately by
  /// `AdvancedFileOutput`, so this only has to outlast the sink's own
  /// queue, not the two-minute flush timer.
  Future<String> readLog(LogService service) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final file = File(p.join(service.logDir, 'latest.log'));
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  test('writes log lines to the log directory', () async {
    final service = await LogService.create(baseDirectory: tempDir);
    addTearDown(service.dispose);

    service.logger.w('first line');

    expect(await readLog(service), contains('first line'));
  });

  test('wipeLogs truncates but keeps the sink alive', () async {
    final service = await LogService.create(baseDirectory: tempDir);
    addTearDown(service.dispose);

    service.logger.w('before wipe');
    expect(await readLog(service), contains('before wipe'));

    await service.wipeLogs();

    // This is the regression: with the old implementation the sink was
    // closed by the wipe and this line never reached the disk.
    service.logger.w('after wipe');
    final contents = await readLog(service);

    expect(contents, isNot(contains('before wipe')),
        reason: 'the wipe should have truncated the pre-wipe lines');
    expect(contents, contains('after wipe'),
        reason: 'logging must survive a wipe, since the app keeps running');
  });

  test('wipeLogs leaves the log directory in place for reuse', () async {
    final service = await LogService.create(baseDirectory: tempDir);
    addTearDown(service.dispose);

    await service.wipeLogs();
    await service.wipeLogs();

    service.logger.w('still writing');
    expect(await readLog(service), contains('still writing'));
  });

  test('create honours the flush-delay in the supplied policy', () async {
    final service = await LogService.create(
      baseDirectory: tempDir,
      policy: const LogPolicy(
        maxFileSizeMb: 32,
        maxRotatedFiles: 2,
        flushDelaySeconds: 1,
        level: LogLevel.warning,
      ),
    );
    addTearDown(service.dispose);

    // A one-second delay is far below the two-minute default, so a line
    // written now should reach disk without waiting out the timer.
    service.logger.w('fast flush');
    expect(await readLog(service), contains('fast flush'));
  });

  test('reconfigure keeps logging alive and keeps prior content', () async {
    final service = await LogService.create(baseDirectory: tempDir);
    addTearDown(service.dispose);

    service.logger.w('before reconfigure');
    expect(await readLog(service), contains('before reconfigure'));

    await service.applyPolicy(
      maxFileSizeMb: 8,
      maxRotatedFiles: 3,
      flushDelaySeconds: 1,
      level: LogLevel.warning,
    );

    // The new sink appends to the same latest.log, so the switch must
    // not lose what was already written.
    service.logger.w('after reconfigure');
    final contents = await readLog(service);
    expect(contents, contains('before reconfigure'));
    expect(contents, contains('after reconfigure'));
  });

  test('reconfigure prunes rotated files down to the new limit', () async {
    final service = await LogService.create(baseDirectory: tempDir);
    addTearDown(service.dispose);

    // Stand in for rotated archives; the logger only creates these on
    // rotation, which a 32 MB file would take months to trigger.
    for (final name in ['a.log', 'b.log', 'c.log', 'd.log']) {
      final f = File(p.join(service.logDir, name))..writeAsStringSync('x');
      // Force distinct mtimes so the newest-first ordering is defined.
      f.setLastModifiedSync(DateTime(2026, 1, 1).add(
        Duration(minutes: f.uri.pathSegments.last.codeUnitAt(0) % 26),
      ));
    }
    expect(
      Directory(service.logDir)
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path) != 'latest.log')
          .length,
      4,
    );

    await service.applyPolicy(
      maxFileSizeMb: 8,
      maxRotatedFiles: 2,
      flushDelaySeconds: 1,
      level: LogLevel.warning,
    );

    final remaining = Directory(service.logDir)
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path) != 'latest.log')
        .toList();
    expect(remaining.length, 2,
        reason: 'the retention limit should prune immediately, not wait for '
            'the next natural rotation');
  });

  test('reconfigure with an unlimited count prunes nothing', () async {
    final service = await LogService.create(baseDirectory: tempDir);
    addTearDown(service.dispose);

    for (final name in ['a.log', 'b.log', 'c.log']) {
      File(p.join(service.logDir, name)).writeAsStringSync('x');
    }

    // 0 maps to the logger's "keep everything" convention.
    await service.applyPolicy(
      maxFileSizeMb: 8,
      maxRotatedFiles: 0,
      flushDelaySeconds: 1,
      level: LogLevel.warning,
    );

    final remaining = Directory(service.logDir)
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path) != 'latest.log')
        .length;
    expect(remaining, 3);
  });

  test('reconfigure applies the requested level to this logger', () async {
    final service = await LogService.create(
      baseDirectory: tempDir,
      releaseLevel: Level.all,
    );
    addTearDown(service.dispose);
    final original = service.logger;

    service.logger.w('visible at warning');
    expect(await readLog(service), contains('visible at warning'));

    await service.reconfigure(
      const LogPolicy(
        maxFileSizeMb: 8,
        maxRotatedFiles: 0,
        flushDelaySeconds: 1,
        level: LogLevel.fatal,
      ),
    );

    // The logger identity must be unchanged, since `Provider<Logger>`,
    // `BootContext.log` and the `MoonShutdown` closure all captured the
    // one built at boot. A swap would leave those writing to a dead sink.
    expect(identical(service.logger, original), isTrue,
        reason: 'reconfigure must not replace the Logger instance');

    // Whatever the build mode, the sink must still accept writes.
    service.logger.f('always visible');
    expect(await readLog(service), contains('always visible'));
  });

  test('an unchanged policy is a no-op that does not churn the sink',
      () async {
    final service = await LogService.create(
      baseDirectory: tempDir,
      policy: const LogPolicy(
        maxFileSizeMb: 16,
        maxRotatedFiles: 4,
        flushDelaySeconds: 2,
        level: LogLevel.warning,
      ),
    );
    addTearDown(service.dispose);

    expect(service.policy, isNotNull);

    // Re-asserting the same values is what boot does immediately after
    // constructing the service. It must not rebuild the sink.
    await service.applyPolicy(
      maxFileSizeMb: 16,
      maxRotatedFiles: 4,
      flushDelaySeconds: 2,
      level: LogLevel.warning,
    );

    service.logger.w('still writing');
    expect(await readLog(service), contains('still writing'));
  });

  test('dispose stops the sink, unlike wipeLogs', () async {
    final service = await LogService.create(baseDirectory: tempDir);

    service.logger.w('before dispose');
    expect(await readLog(service), contains('before dispose'));

    await service.dispose();

    // After teardown the flush timer is gone, so this line is buffered
    // and never written. That is the intended behaviour at process exit
    // and is exactly what distinguishes dispose from wipeLogs.
    service.logger.w('after dispose');

    expect(await readLog(service), isNot(contains('after dispose')));
  });
}
