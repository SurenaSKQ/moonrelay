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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Agreed-on regex patterns for sensitive data that must be redacted from
/// log output before it hits disk.
///
/// These patterns are intentionally coarse — false positives are safer
/// than false negatives.  At the same time we avoid removing structural
/// characters that would break JSON in the log stream.
const _redactionPatterns = <_RedactionPattern>[
  // Matrix access tokens (typically syt_... or MDA...)
  _RedactionPattern(
      pattern: r'\b(syt_[A-Za-z0-9]+)\b', replacement: 'syt_[REDACTED]'),
  _RedactionPattern(
      pattern: r'\bMDA[A-Za-z0-9]{100,}\b', replacement: 'MDA[REDACTED]'),
  // Bearer tokens in Authorization headers
  _RedactionPattern(
      pattern: r'Bearer\s+\S+',
      replacement: 'Bearer [REDACTED]',
      caseSensitive: false),
  // Raw Matrix login tokens (long base64-like strings in URL query params)
  _RedactionPattern(
      pattern: r'loginToken=[A-Za-z0-9+/=]{20,}',
      replacement: 'loginToken=[REDACTED]'),
  // Device IDs and session IDs (high-entropy identifiers)
  _RedactionPattern(
      pattern: r'\bdevice_id[=:]"?([A-Za-z0-9]{10,})"?',
      replacement: 'device_id=[REDACTED]'),
  _RedactionPattern(
      pattern: r'\bsession_id[=:]"?([A-Za-z0-9]{10,})"?',
      replacement: 'session_id=[REDACTED]'),
  // Passwords in URL-encoded form bodies (password=foo, password: foo).
  // Matches `password=...`, `password:...`, JSON-style `"password":"..."`.
  // The regex character class uses both single and double quotes; raw
  // string literals cannot contain a raw `'`, so the leading `\` is a
  // literal backslash we strip with a `r"..."` boundary.
  _RedactionPattern(
      pattern: r'''password[=:"']?\s*([^\s&,"}\]]+)''',
      replacement: 'password=[REDACTED]'),
];

/// A token-length-sensitive, memory-constrained log sink that writes
/// structured log lines to rotating files and supports secure log-wipe
/// on user logout.
///
/// Logs are stored in the application's support directory (not cache) so
/// they survive OS cache purges.  In release builds the minimum log
/// level is raised to [Level.warning].
class LogService {
  LogService._({
    required this.logger,
    required this.logDir,
    required this.wipeLogs,
  });

  /// The underlying [Logger] instance.  All log calls should be made
  /// through this object.
  final Logger logger;

  /// The directory where log files are stored.
  final String logDir;

  /// Deletes all log files and re-creates the log directory.
  ///
  /// Call this on logout so that no session-related information persists
  /// on disk after the user's data has been removed from the application.
  final Future<void> Function() wipeLogs;

  // ── Factory ──────────────────────────────────────────────────────────

  /// Creates a [LogService] whose log files live in the application
  /// support directory.
  static Future<LogService> create({
    String folderName = 'MoonrelayLogs',
    int maxFileSizeKB = 32768,
    Level releaseLevel = Level.warning,
    Level debugLevel = Level.all,
  }) async {
    // ── Determine log directory ────────────────────────────────────────
    Directory appSupport;
    try {
      appSupport = await getApplicationSupportDirectory();
    } catch (_) {
      appSupport = Directory.current;
    }
    final logs = await Directory(
      p.join(appSupport.path, folderName),
    ).create(recursive: true);

    // ── Build the redacting output ────────────────────────────────────
    final fileOutput = AdvancedFileOutput(
      path: logs.path,
      encoding: utf8,
      maxFileSizeKB: maxFileSizeKB,
      maxDelay: const Duration(minutes: 2),
    );

    final safeOutput = _RedactingLogOutput(fileOutput);

    final logLevel = kReleaseMode ? releaseLevel : debugLevel;

    final logger = Logger(
      printer: SimplePrinter(
        colors: !Platform.isMacOS,
        printTime: false,
      ),
      output: safeOutput,
      filter: ProductionFilter(),
      level: logLevel,
    );

    // ── Wipe function ─────────────────────────────────────────────────
    Future<void> wipe() async {
      // Flush any buffered output before deleting.
      await fileOutput.destroy();
      // Delete all files inside the log folder (but keep the folder).
      if (await Directory(logs.path).exists()) {
        await for (final entity in Directory(logs.path).list()) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {
              // best-effort
            }
          }
        }
      }
    }

    return LogService._(
      logger: logger,
      logDir: logs.path,
      wipeLogs: wipe,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redacting log output
// ─────────────────────────────────────────────────────────────────────────────

class _RedactionPattern {
  final Pattern pattern;
  final String replacement;
  final bool caseSensitive;

  const _RedactionPattern({
    required this.pattern,
    required this.replacement,
    this.caseSensitive = true,
  });

  RegExp get regex => pattern is RegExp
      ? pattern as RegExp
      : RegExp(pattern as String, caseSensitive: caseSensitive);
}

/// Wraps a [LogOutput] and redacts known secrets before forwarding lines
/// to the inner output.
class _RedactingLogOutput extends LogOutput {
  _RedactingLogOutput(this._inner);

  final LogOutput _inner;

  @override
  void output(OutputEvent event) {
    // Redact each line individually.
    final redacted =
        event.lines.map((line) => _redactLine(line)).toList(growable: false);
    _inner.output(OutputEvent(event.origin, redacted));
  }

  static String _redactLine(String line) {
    for (final rp in _redactionPatterns) {
      line = line.replaceAll(rp.regex, rp.replacement);
    }
    return line;
  }

  @override
  Future<void> init() => _inner.init();

  @override
  Future<void> destroy() => _inner.destroy();
}
