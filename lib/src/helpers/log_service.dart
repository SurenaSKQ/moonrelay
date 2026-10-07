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

import 'package:moonrelay/src/settings/chat_preferences.dart';

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

/// Single mutable slot holding the active [LogPolicy].
///
/// A cell rather than a plain field so the closures built inside
/// [LogService.create] can read and write the same instance state the
/// `LogService` object exposes, without either side holding a stale copy.
class _PolicyCell {
  _PolicyCell(this.value);

  LogPolicy value;
}

/// The four user-facing logging knobs, resolved into one value.
///
/// Bundled because they are changed together and applied together, and
/// because a single value means there is exactly one place that knows
/// what "the current logging policy" is. Equality is by value, which is
/// what lets [LogService.reconfigure] treat an unchanged policy as a
/// no-op.
@immutable
class LogPolicy {
  const LogPolicy({
    required this.maxFileSizeMb,
    required this.maxRotatedFiles,
    required this.flushDelaySeconds,
    required this.level,
  });

  /// Maximum size of the active log file before rotation.
  final int maxFileSizeMb;

  /// How many rotated files to keep. Zero or less means unlimited.
  final int maxRotatedFiles;

  /// How long buffered lines may sit before being written.
  final int flushDelaySeconds;

  /// Verbosity floor.
  final LogLevel level;

  @override
  bool operator ==(Object other) =>
      other is LogPolicy &&
      other.maxFileSizeMb == maxFileSizeMb &&
      other.maxRotatedFiles == maxRotatedFiles &&
      other.flushDelaySeconds == flushDelaySeconds &&
      other.level == level;

  @override
  int get hashCode =>
      Object.hash(maxFileSizeMb, maxRotatedFiles, flushDelaySeconds, level);

  @override
  String toString() => 'LogPolicy(${maxFileSizeMb}MB, '
      '${maxRotatedFiles <= 0 ? "unlimited" : "$maxRotatedFiles files"}, '
      '${flushDelaySeconds}s, $level)';
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
    required this.teardown,
    required this.reconfigure,
    required ProductionFilter filter,
    required _PolicyCell currentPolicy,
  })  : _filter = filter,
        _currentPolicy = currentPolicy;

  /// The filter backing [logger]. Held so the level can be retuned in
  /// place; see [updateVerboseRelease] for why the static cannot be used.
  final ProductionFilter _filter;

  /// Mutable cell holding the policy in force.
  ///
  /// A one-field holder rather than a plain field because the [reconfigure]
  /// closure is built in the static [create] and so cannot reach an
  /// instance field; both the closure and the [policy] getter read this
  /// one cell, which is what keeps them in agreement.
  final _PolicyCell _currentPolicy;

  /// Sentinel for "keep every rotated log file", which is how the logger
  /// package spells unlimited (a null `maxRotatedFilesCount`).
  static const int _unlimitedRotatedFiles = 0;

  /// Maps the user's `logLevel` choice onto a logger-package [Level].
  ///
  /// Written as an explicit switch rather than a `values[i]` index cast
  /// so that adding a value to either enum surfaces as a compile error
  /// here rather than as a silently wrong threshold at runtime. The two
  /// enums happen to share ordinals today, which is exactly the
  /// coincidence worth not depending on.
  static Level toLoggerLevel(LogLevel level) {
    switch (level) {
      case LogLevel.all:
        return Level.all;
      case LogLevel.trace:
        return Level.trace;
      case LogLevel.debug:
        return Level.debug;
      case LogLevel.info:
        return Level.info;
      case LogLevel.warning:
        return Level.warning;
      case LogLevel.error:
        return Level.error;
      case LogLevel.fatal:
        return Level.fatal;
    }
  }

  /// Pushes the current logging policy into a live sink.
  ///
  /// Convenience wrapper over [reconfigure] for the settings page and the
  /// boot sequence, so the four values are read in one place. Equal
  /// policies are a no-op, so this is safe to call unconditionally, which
  /// matters at boot: `LogService` is built before settings load, so
  /// boot re-asserts the stored policy immediately afterwards.
  Future<void> applyPolicy({
    required int maxFileSizeMb,
    required int maxRotatedFiles,
    required int flushDelaySeconds,
    required LogLevel level,
  }) {
    return reconfigure(
      LogPolicy(
        maxFileSizeMb: maxFileSizeMb,
        maxRotatedFiles: maxRotatedFiles,
        flushDelaySeconds: flushDelaySeconds,
        level: level,
      ),
    );
  }

  /// The underlying [Logger] instance.  All log calls should be made
  /// through this object.
  final Logger logger;

  /// The directory where log files are stored.
  final String logDir;

  /// Truncates the log files and re-opens the sink so logging continues.
  ///
  /// Call this on logout, and from the "Clear logs" action, so that no
  /// session-related information persists on disk after the user's data
  /// has been removed from the application.  The application keeps
  /// running afterwards, so this must NOT close the log sink for good;
  /// see [dispose] for the process-exit path.
  final Future<void> Function() wipeLogs;

  /// Closes the log sink for good.  Only call this immediately before
  /// the process exits; after it, every further log line is buffered
  /// and never written, because the flush timer is gone.
  final Future<void> Function() teardown;

  /// Applies new size, retention, flush-delay and level policy.
  ///
  /// Backs `logMaxFileSizeMb`, `logMaxFiles`, `logFlushDelayS` and
  /// `logLevel`. The logger package exposes no setters for any of these,
  /// so the sink is rebuilt and swapped behind the stable [Logger]
  /// identity; see the implementation for why the [Logger] itself must
  /// not be replaced. A policy equal to the current one is a no-op, so
  /// callers do not have to debounce.
  final Future<void> Function(LogPolicy policy) reconfigure;

  /// The policy currently in force.
  ///
  /// Read by [applyPolicy] callers and tests to assert what the sink is
  /// actually running with, which is otherwise invisible.
  LogPolicy? get policy => _currentPolicy.value;

  /// Releases the log sink.  The single caller should be the shutdown
  /// sequence, never a runtime action.
  Future<void> dispose() => teardown();

  /// Retunes the verbosity floor in release mode when the user toggles
  /// [SettingsController.logVerboseRelease]. In debug mode the level is
  /// always [Level.all] so this is a no-op.
  ///
  /// The level is set on this logger's own filter, not on the static
  /// `Logger.level`: `LogService.create` hands the `Logger` constructor a
  /// non-null level, which `Logger` stores on the filter, and
  /// `LogFilter.level` reads `_level ?? Logger.level`. With `_level` set,
  /// the static is never consulted, so assigning it changed nothing. This
  /// also keeps the change scoped to this logger instead of every
  /// `Logger` in the process, including the raw one in the SSO server.
  void updateVerboseRelease(bool verbose) {
    if (!kReleaseMode) return;
    _filter.level = verbose ? Level.all : Level.warning;
  }

  // -- Factory ----------------------------------------------------------

  /// Creates a [LogService] whose log files live in the application
  /// support directory.
  ///
  /// [baseDirectory] overrides the support-directory lookup. It exists
  /// so tests can point the sink at a temp dir instead of relying on the
  /// `getApplicationSupportDirectory` failure path, which falls back to
  /// the current working directory and would litter the repository root.
  static Future<LogService> create({
    String folderName = 'MoonrelayLogs',
    Level releaseLevel = Level.warning,
    Level debugLevel = Level.all,
    Directory? baseDirectory,
    LogPolicy? policy,
  }) async {
    // -- Determine log directory ----------------------------------------
    Directory appSupport;
    if (baseDirectory != null) {
      appSupport = baseDirectory;
    } else {
      try {
        appSupport = await getApplicationSupportDirectory();
      } catch (_) {
        appSupport = Directory.current;
      }
    }
    final logs = await Directory(
      p.join(appSupport.path, folderName),
    ).create(recursive: true);

    // A cell rather than a plain local so the `LogService` instance and
    // the closures below all read the same value: the builder needs the
    // current one, and the instance exposes it through `policy`.
    final currentPolicy = _PolicyCell(
      policy ??
          const LogPolicy(
            maxFileSizeMb: 32,
            maxRotatedFiles: _unlimitedRotatedFiles,
            flushDelaySeconds: 120,
            level: LogLevel.warning,
          ),
    );

    // -- Build the redacting output ------------------------------------
    // Reads the mutable policy rather than the create() arguments, so the
    // same closure serves both the initial sink and every reconfigure.
    AdvancedFileOutput buildOutput() => AdvancedFileOutput(
          path: logs.path,
          encoding: utf8,
          maxFileSizeKB: currentPolicy.value.maxFileSizeMb * 1024,
          maxDelay: Duration(seconds: currentPolicy.value.flushDelaySeconds),
          // The logger treats a null count as "keep every rotated file".
          // `logMaxFiles` defaults to 0, which most naturally reads as
          // "unlimited" rather than "delete every archive on rotation",
          // so 0 is mapped to null here. A positive value prunes to that
          // many, but only on rotation, which is why reconfigure also
          // runs an explicit sweep.
          maxRotatedFilesCount:
              currentPolicy.value.maxRotatedFiles > 0
                  ? currentPolicy.value.maxRotatedFiles
                  : null,
        );

    final fileOutput = buildOutput();

    final safeOutput = _RedactingLogOutput(fileOutput);

    final logLevel = kReleaseMode ? releaseLevel : debugLevel;

    // The filter is held rather than discarded: `Logger.level` is static
    // and, because the constructor below stores a non-null level on the
    // filter, `LogFilter.level` never falls back to the static. Mutating
    // `Logger.level` is therefore inert, and the only way to retune the
    // threshold for this logger is to set it on the filter.
    final filter = ProductionFilter();

    final logger = Logger(
      printer: SimplePrinter(
        colors: !Platform.isMacOS,
        printTime: false,
      ),
      output: safeOutput,
      filter: filter,
      level: logLevel,
    );

    // -- Teardown functions ---------------------------------------------
    // Truncation and teardown are deliberately separate.  `destroy()`
    // cancels the buffer-flush and file-target timers and closes the
    // sink, after which nothing in the logger package re-arms them, so
    // a runtime "clear the logs" that called it would silently kill
    // logging for the rest of the process.  `init()` is re-callable and
    // re-opens the same `late final` target file, so the reverse
    // sequence (destroy, delete, init) gives a clean, still-live sink.
    // Destroys whichever sink is current. This has to go through
    // `safeOutput` rather than closing over `fileOutput`, because
    // `reconfigure` may have swapped in a different one by now, and
    // closing the stale handle would leave the live sink holding the
    // file (which shows up as a Windows sharing violation on delete).
    Future<void> teardown() => safeOutput.destroyCurrent();

    // Reconfigure the size, retention and level policy at runtime.
    //
    // `AdvancedFileOutput` exposes no setters for any of its three
    // knobs, so the only route is a new instance. The Logger itself
    // must NOT be replaced: `BootContext.log`, `Provider<Logger>` and
    // the closure captured by `MoonShutdown.register` all hold the one
    // built at boot, and a fresh Logger would leave every one of them
    // writing into a destroyed sink. Swapping the output behind the
    // stable `_RedactingLogOutput` wrapper keeps that identity intact.
    Future<void> reconfigure(LogPolicy next0) async {
      if (next0 == currentPolicy.value) return;
      currentPolicy.value = next0;

      final next = buildOutput();
      // Init the replacement before swapping, so no line is dropped
      // between the two sinks, and destroy the old one after, so
      // nothing buffered is lost. `openWrite` appends to the existing
      // latest.log, so the file does not restart.
      await next.init();
      final previous = safeOutput.replaceInner(next);
      // A debug build deliberately keeps everything: the level control is
      // a shipped-build verbosity knob, and silencing a debug build helps
      // nobody.
      filter.level =
          kReleaseMode ? toLoggerLevel(next0.level) : Level.all;
      // Pruning only happens on rotation inside the logger, which with a
      // 32 MB file may be months away, so lowering the retention limit
      // has to sweep for itself or the setting does not feel live.
      await _pruneRotatedFiles(logs.path, next0.maxRotatedFiles);
      await previous.destroy();
    }

    Future<void> wipe() async {
      // Flush and close so the handles are released before the files
      // go away; on Windows an open sink would block the delete.
      await safeOutput.destroyCurrent();
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
      // Re-arm the timers and re-open the sink.  `openWrite` in append
      // mode recreates the target file that was just deleted, so the
      // next log line starts a fresh file.  Goes through the wrapper
      // because a reconfigure may have swapped the inner output since
      // this service was built.
      try {
        await safeOutput.initCurrent();
      } catch (e) {
        // The old files are gone either way, which is what the caller
        // asked for; a sink that will not reopen only costs us the
        // remaining session's log, and throwing here would turn a
        // successful wipe into a failed logout.
        stderr.writeln('Log sink did not reopen after wipe: $e');
      }
    }

    return LogService._(
      logger: logger,
      logDir: logs.path,
      wipeLogs: wipe,
      teardown: teardown,
      reconfigure: reconfigure,
      filter: filter,
      currentPolicy: currentPolicy,
    );
  }

  /// Deletes rotated log files beyond the newest [keep], newest-first by
  /// modification time.
  ///
  /// Mirrors the logger's own pruning (it sorts by `lastModifiedSync()`
  /// ascending and excludes the active `latest.log` by path) so that a
  /// limit set through [LogService.reconfigure] and one reached by
  /// natural rotation converge on the same directory contents. [keep] of
  /// 0 or less means unlimited, matching how [LogService.create] maps
  /// the setting onto the logger's nullable parameter.
  static Future<void> _pruneRotatedFiles(String dir, int keep) async {
    if (keep <= 0) return;
    final directory = Directory(dir);
    if (!await directory.exists()) return;
    final latest = p.join(dir, 'latest.log');
    final List<File> rotated;
    try {
      rotated = (await directory.list().toList())
          .whereType<File>()
          .where((f) => f.path != latest)
          .toList();
    } catch (e) {
      // Best-effort: a retention limit that fails to prune leaves extra
      // files on disk, which is not worth failing a settings change over.
      stderr.writeln('Could not list log dir for pruning: $e');
      return;
    }
    if (rotated.length <= keep) return;
    rotated.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in rotated.take(rotated.length - keep)) {
      try {
        await file.delete();
      } catch (_) {
        // best-effort, same rationale as the listing
      }
    }
  }
}

// Redacting log output

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
///
/// [_inner] is mutable so [LogService.reconfigure] can swap in a sink
/// with different size and retention policy. The wrapper itself, and
/// therefore the [Logger] that holds it, is created once per process
/// and never replaced, which is what keeps every long-lived reference to
/// that logger valid.
class _RedactingLogOutput extends LogOutput {
  _RedactingLogOutput(this._inner);

  LogOutput _inner;

  /// Points this wrapper at [next] and returns the output it replaced, so
  /// the caller can flush and close the old sink after the swap.
  LogOutput replaceInner(LogOutput next) {
    final previous = _inner;
    _inner = next;
    return previous;
  }

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

  /// Closes the current inner output, whichever one that is.
  ///
  /// Exists because [LogService.teardown] and `wipeLogs` have to reach the
  /// live sink after a [LogService.reconfigure] swap, and `_inner` is
  /// private. Closing a stale handle instead would leave the live sink
  /// holding the file, which surfaces on Windows as a sharing violation
  /// when something later tries to delete it.
  Future<void> destroyCurrent() => _inner.destroy();

  /// Re-initialises the current inner output. See [destroyCurrent].
  Future<void> initCurrent() => _inner.init();
}
