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

// Auto-update check: polls the GitHub Releases API for newer Moonrelay
// versions and surfaces an in-app banner so users can download the new
// release without leaving the app.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Holds the result of an auto-update check.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.available,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
  });

  final bool available;
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? releaseNotes;

  factory UpdateCheckResult.upToDate(String current) => UpdateCheckResult(
        available: false,
        currentVersion: current,
        latestVersion: current,
        releaseUrl: '',
      );
}

class AutoUpdateService {
  AutoUpdateService({http.Client? client, Logger? log})
      : _client = client ?? http.Client(),
        _log = log ?? Logger();

  final http.Client _client;
  final Logger _log;

  /// GitHub slug for the Moonrelay repository.  Configurable so unit
  /// tests can inject a fixture endpoint.
  String repoSlug = 'SurenaSKQ/moonrelay';

  /// Performs a one-shot check for a newer version.  Returns an
  /// [UpdateCheckResult] describing the current and latest versions.
  Future<UpdateCheckResult> check({String? overrideVersion}) async {
    final current = overrideVersion ?? await _currentVersion();
    try {
      final response = await _client.get(
        Uri.parse('https://api.github.com/repos/$repoSlug/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'moonrelay-desktop',
        },
      );
      if (response.statusCode != 200) {
        _log.w(
          'auto-update: GitHub API returned ${response.statusCode}',
        );
        return UpdateCheckResult.upToDate(current);
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (decoded['tag_name'] as String?) ?? '';
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      final available = _isNewer(version, current);
      return UpdateCheckResult(
        available: available,
        currentVersion: current,
        latestVersion: version,
        releaseUrl:
            (decoded['html_url'] as String?) ?? 'https://github.com/$repoSlug',
        releaseNotes: decoded['body'] as String?,
      );
    } catch (e) {
      _log.w('auto-update: failed to query GitHub', error: e);
      return UpdateCheckResult.upToDate(current);
    }
  }

  Future<String> _currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Compares [remote] to [local] using simple semver rules.  Returns
  /// `true` when [remote] is strictly newer than [local].
  ///
  /// Falls back to lexicographic comparison if either side cannot be
  /// parsed as three numeric components.  A `+build` suffix is stripped
  /// before parsing so `1.2.3+12` compares equal to `1.2.3` on the
  /// version triplet (a build number is never "newer" on its own).
  static bool _isNewer(String remote, String local) {
    if (remote.isEmpty) return false;
    final remoteParts = _semverParts(remote);
    final localParts = _semverParts(local);
    if (remoteParts.length == 3 &&
        localParts.length == 3 &&
        remoteParts.every((p) => p != null) &&
        localParts.every((p) => p != null)) {
      for (var i = 0; i < 3; i++) {
        final r = remoteParts[i]!;
        final l = localParts[i]!;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    }
    return remote.compareTo(local) > 0;
  }

  /// Splits a version string like `1.2.3+build.7` into its numeric
  /// components, dropping the build suffix.
  static List<int?> _semverParts(String version) {
    final noBuild = version.split('+').first;
    return noBuild.split('.').take(3).map(int.tryParse).toList();
  }

  void dispose() {
    try {
      _client.close();
    } catch (_) {}
  }
}
