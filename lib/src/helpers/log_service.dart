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
/// These patterns are intentionally coarse; false positives are safer
/// than false negatives.  At the same time we avoid removing structural
/// characters that would break JSON in the log stream.
///
/// Exposed at the library level (rather than nested under
/// [_RedactingLogOutput]) so the redaction surface is unit-testable in
/// isolation; `_RedactingLogOutput` simply forwards through
/// [redactString] for each log line.
// ignore: library_private_types_in_public_api
const List<_RedactionPattern> redactionPatterns = <_RedactionPattern>[
  // Matrix access tokens (typically syt_... or MDA...)
  _RedactionPattern(
      pattern: r'\b(syt_[A-Za-z0-9]+)\b', replacement: 'syt_[REDACTED]'),
  _RedactionPattern(
      pattern: r'\bMDA[A-Za-z0-9]{100,}\b', replacement: 'MDA[REDACTED]'),
  // Bearer tokens in Authorization headers.  The leading byte
  // `[Aa]` matches both cases so we don't need a separate rule.
  // 16+ chars on the value side rejects natural-language words after
  // "Bearer" (e.g. "Bearer of this message").
  _RedactionPattern(
      pattern: r'((?:Authorization:\s*)?Bearer\s+)([A-Za-z0-9._~+/=-]{16,})',
      replacement: r'$1[REDACTED]',
      caseSensitive: false),
  // Raw Matrix login tokens (long base64-like strings in URL query params)
  _RedactionPattern(
      pattern: r'loginToken=[A-Za-z0-9+/=]{20,}',
      replacement: 'loginToken=[REDACTED]'),
  // Device IDs and session IDs (high-entropy identifiers).
  // Handles `device_id=VALUE`, `"device_id":"VALUE"`, `device_id:VALUE`,
  // and `device_id: VALUE`.  Uses `\b` so the rule doesn't pull in a
  // `device_id` substring that happens to follow `password=…` (since
  // the value-side chars are alphanumeric only, the rule would otherwise
  // happily munch an adjacent identifier).
  _RedactionPattern(
      pattern: r'\bdevice_id["\s]*[=:]\s*"?([A-Za-z0-9]{10,})"?',
      replacement: 'device_id=[REDACTED]'),
  _RedactionPattern(
      pattern: r'\bsession_id["\s]*[=:]\s*"?([A-Za-z0-9]{10,})"?',
      replacement: 'session_id=[REDACTED]'),
  // Passwords: matches `password=foo`, `password: foo`,
  // `"password": "foo"`, `"password":"foo"`, and trailing key=value in
  // URL-encoded bodies.  The capture class deliberately includes `[`
  // and `]` as stop characters so a `[REDACTED]` placeholder emitted
  // by an earlier rule cannot itself trigger another pass through this
  // rule (which would otherwise chew square brackets off the end of
  // previous redactions and degrade the log to garbage over time).
  _RedactionPattern(
      pattern:
          r'''(?:["']?password["']?\s*[=:]\s*["']?)([^\s,&}"'\]\[]+)["']?''',
      replacement: 'password=[REDACTED]'),
];

// /\\/\\/ Public redaction surface (tests + dev tooling).
// /\\/\\/ The detail type is intentionally private; consumers should
// /\\/\\/ only depend on [redactString] and the [redactionPatterns]
// /\\/\\/ list itself.

/// Apply every [redactionPatterns] rule to [line] in order and return
/// the cleaned string.  Exposed so unit tests can pin the ruleset without
/// having to construct a full [LogOutput] pipeline.
///
/// Uses [String.replaceAllMapped] when the pattern is a [RegExp] so
/// `$N` backreferences in the replacement string are honoured; Dart's
/// plain `String.replaceAll(Pattern, String)` treats `$N` as literal
/// text and would silently drop the `Authorization:` prefix when
/// redacting a bearer token.
String redactString(String line) {
  for (final rp in redactionPatterns) {
    if (rp.pattern is RegExp) {
      final re = rp.pattern as RegExp;
      if (RegExp(r'\$\d').hasMatch(rp.replacement)) {
        line = line.replaceAllMapped(re, (m) => _expand(rp.replacement, m));
      } else {
        line = line.replaceAll(re, rp.replacement);
      }
    } else {
      // String pattern: compile on the fly.
      line = line.replaceAllMapped(
        RegExp(rp.pattern as String, caseSensitive: rp.caseSensitive),
        (m) => _expand(rp.replacement, m),
      );
    }
  }
  return line;
}

/// Expands `$N` backreferences in [template] using the captured
/// groups from [m] (1-based).  Unknown indices are left as literal.
String _expand(String template, Match m) {
  return template.replaceAllMapped(
    RegExp(r'\$(\d+)'),
    (ref) {
      final idx = int.parse(ref.group(1)!);
      if (idx < 1 || idx > m.groupCount) return ref.group(0)!;
      return m.group(idx) ?? '';
    },
  );
}

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

  /// Updates the logger level in release mode when the user toggles
  /// [SettingsController.logVerboseRelease].  In debug mode the level
  /// is always [Level.all] so this is a no-op.
  void updateVerboseRelease(bool verbose) {
    if (!kReleaseMode) return;
    Logger.level = verbose ? Level.all : Level.warning;
  }

  // -- Factory ----------------------------------------------------------

  /// Creates a [LogService] whose log files live in the application
  /// support directory.
  static Future<LogService> create({
    String folderName = 'MoonrelayLogs',
    int maxFileSizeKB = 32768,
    Level releaseLevel = Level.warning,
    Level debugLevel = Level.all,
  }) async {
    // -- Determine log directory ----------------------------------------
    Directory appSupport;
    try {
      appSupport = await getApplicationSupportDirectory();
    } catch (_) {
      appSupport = Directory.current;
    }
    final logs = await Directory(
      p.join(appSupport.path, folderName),
    ).create(recursive: true);

    // -- Build the redacting output ------------------------------------
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

    // -- Wipe function -------------------------------------------------
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

// -----------------------------------------------------------------------------
// Redacting log output
// -----------------------------------------------------------------------------

/// A single regex-based redaction rule.
///
/// Public so tests can introspect the ruleset without going through
/// the regex pipeline, but treated as an implementation detail by
/// other consumers of the library.
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

  static String _redactLine(String line) => redactString(line);

  @override
  Future<void> init() => _inner.init();

  @override
  Future<void> destroy() => _inner.destroy();
}
