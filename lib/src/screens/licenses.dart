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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// A single license entry with its full text (loaded from assets).
class _LicenseEntry {
  _LicenseEntry({
    required this.name,
    required this.description,
    this.assetName,
    this.packages,
    this.url,
  });

  final String name;
  final String description;
  final String? assetName;
  final String? packages;
  final String? url;

  /// Populated after the asset file is loaded asynchronously.
  String? fullText;

  bool get hasAsset => assetName != null;
}

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  final List<_LicenseEntry> _entries = [
    _LicenseEntry(
      name: 'GNU Affero General Public License v3.0',
      description: 'The license under which Moonrelay itself is distributed.',
      assetName: 'assets/agpl-3.0.txt',
      packages: 'moonrelay, matrix-dart-sdk',
      url: 'https://www.gnu.org/licenses/agpl-3.0.html',
    ),
    _LicenseEntry(
      name: 'GNU General Public License v3.0',
      description:
          'Used by several dependencies that are licensed under GPL v3.',
      assetName: 'assets/gpl-3.0.txt',
      packages: 'Various dependencies',
      url: 'https://www.gnu.org/licenses/gpl-3.0.html',
    ),
    _LicenseEntry(
      name: 'MIT License',
      description:
          'A permissive license used by many Dart and Flutter packages.',
      packages: 'provider, path_provider, google_fonts, shared_preferences, '
          'url_launcher, lucide_icons_flutter, badges, file_picker, '
          'and many others',
      url: 'https://opensource.org/licenses/MIT',
    ),
    _LicenseEntry(
      name: 'Apache License 2.0',
      description:
          'Used by the Flutter framework and several ecosystem packages.',
      packages: 'Flutter SDK, Dart SDK, go_router, sqflite, flutter_svg, '
          'and others',
      url: 'https://www.apache.org/licenses/LICENSE-2.0',
    ),
    _LicenseEntry(
      name: 'BSD 3-Clause License',
      description:
          'Used by some low‑level Dart packages and platform bindings.',
      packages:
          'flutter_acrylic, system_theme, window_manager, sqflite_common_ffi',
      url: 'https://opensource.org/licenses/BSD-3-Clause',
    ),
    _LicenseEntry(
      name: 'Mozilla Public License 2.0',
      description: 'Used by the Matrix SDK (matrix Dart package) and related '
          'libraries.',
      packages: 'matrix, flutter_vodozemac',
      url: 'https://www.mozilla.org/en-US/MPL/2.0/',
    ),
  ];

  /// Track which entries have been expanded (show full text).
  final Set<int> _expanded = {};

  /// Load the full license text for a single entry from its asset file.
  Future<void> _loadLicenseText(int index) async {
    final entry = _entries[index];
    if (entry.fullText != null || !entry.hasAsset) return;

    try {
      final text = await rootBundle.loadString(entry.assetName!);
      if (mounted) {
        setState(() {
          entry.fullText = text;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          entry.fullText = '(Could not load license text.)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.thirdPartyLicense),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final isOpen = _expanded.contains(index);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header (tappable) ──────────────────────────────
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isOpen) {
                          _expanded.remove(index);
                        } else {
                          _expanded.add(index);
                          // Kick off loading the license text if needed.
                          _loadLicenseText(index);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.scrollText,
                            size: 22,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isOpen
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Packages & URL row (always visible) ────────────
                  if (!isOpen && entry.packages != null)
                    _MetadataRow(
                      icon: LucideIcons.package,
                      text: entry.packages!,
                    ),
                  if (!isOpen && entry.url != null)
                    _MetadataRow(
                      icon: LucideIcons.externalLink,
                      text: entry.url!,
                    ),

                  // ── Expanded full license text ─────────────────────
                  if (isOpen) ...[
                    if (entry.hasAsset && entry.fullText == null)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),

                    if (entry.fullText != null)
                      Container(
                        width: double.infinity,
                        color: colors.surfaceContainerHighest,
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          entry.fullText!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontFamily: 'monospace',
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // Metadata below the license text
                    if (entry.packages != null)
                      _MetadataRow(
                        icon: LucideIcons.package,
                        text: entry.packages!,
                      ),
                    if (entry.url != null)
                      _MetadataRow(
                        icon: LucideIcons.externalLink,
                        text: entry.url!,
                      ),

                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small row showing package names or a URL.
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
