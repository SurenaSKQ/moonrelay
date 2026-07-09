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

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Single source of truth for the displayed app version.
///
/// `version` is `pubspec.yaml`'s `version: X.Y.Z+B`, exposed as the
/// joined `X.Y.Z+B` string. UI code asks for `AppVersion.currentVersion`
/// and renders it anywhere it needs to. Tooling reads are also
/// available separately (see [build] and [name]).
///
/// On Linux/Windows, `package_info_plus` reads `version.json`
/// (Linux) and `ProductVersion` in `Runner.rc` (Windows), both of
/// which Flutter populates from `pubspec.yaml` during the release
/// build. When running under `flutter test` the values default to
/// `0.0.0+0`; the helper falls back to those instead of crashing
/// the UI.
class AppVersion {
  AppVersion._(this.version);

  /// Human-facing version plus build suffix, e.g. `0.6.0+0`.
  final String version;

  /// Just the build number, e.g. `0` (after the `+`).
  String get build {
    final i = version.indexOf('+');
    return i >= 0 ? version.substring(i + 1) : '';
  }

  /// Just the version name, e.g. `0.6.0` (before the `+`).
  String get name {
    final i = version.indexOf('+');
    return i >= 0 ? version.substring(0, i) : version;
  }

  /// Lazily-initialised from `PackageInfo` on first access.
  /// Cached on the singleton so repeated calls don't re-hit native code.
  static AppVersion? _current;

  /// Initialize from PackageInfo. Call once at boot before any UI
  /// reads `current`. Safe to call multiple times — the first one wins.
  static Future<void> init() async {
    if (_current != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      // PackageInfo exposes `version` (= X.Y.Z) and `buildNumber` (= B).
      // rejoin them so the UI just sees the canonical `X.Y.Z+B` form.
      _current = AppVersion._('${info.version}+${info.buildNumber}');
    } catch (e, st) {
      // Don't crash UI load if platform_info isn't wired up.
      if (kDebugMode) {
        debugPrint('AppVersion.init failed: $e\n$st');
      }
      _current = AppVersion._fallback;
    }
  }

  /// Test-only constructor. Lets widget tests pin a deterministic
  /// version without touching the singleton.
  @visibleForTesting
  static AppVersion test({required String version}) =>
      AppVersion._(version);

  /// Fallback when platform info isn't available (e.g. widget tests,
  /// or `flutter run` before `PackageInfo` initialises).
  static final AppVersion _fallback = AppVersion._('0.0.0+0');

  /// Reset for tests only.
  @visibleForTesting
  static void resetForTesting() => _current = null;

  /// The active version used by UI.
  static AppVersion get current {
    return _current ?? _fallback;
  }

  /// `current.version` shortcut for the common "show in About page" case.
  static String get currentVersion => current.version;
}
