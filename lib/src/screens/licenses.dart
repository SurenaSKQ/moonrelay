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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

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
          'Used by some low-level Dart packages and platform bindings.',
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
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final mono = ext.monoFontFamily;

    return MoonrelayInfoPage(
      title: l10n.thirdPartyLicense,
      children: <Widget>[
        for (int index = 0; index < _entries.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: t.spaceMd),
            child: _LicensePanel(
              entry: _entries[index],
              expanded: _expanded.contains(index),
              onToggle: () {
                setState(() {
                  if (_expanded.contains(index)) {
                    _expanded.remove(index);
                  } else {
                    _expanded.add(index);
                    // Kick off loading the license text if needed.
                    _loadLicenseText(index);
                  }
                });
              },
              monoFamily: mono,
            ),
          ),
      ],
    );
  }
}

/// One dependency: its name, what it is for, and its licence behind a tap.
///
/// A widget rather than an inline `Card` so the loading, the mono block and the
/// metadata rows are one named thing instead of 130 lines inside a
/// `ListView.builder` item builder. It is also what makes the row testable, which
/// it was not while it was assembled in place.
class _LicensePanel extends StatelessWidget {
  const _LicensePanel({
    required this.entry,
    required this.expanded,
    required this.onToggle,
    required this.monoFamily,
  });

  final _LicenseEntry entry;
  final bool expanded;
  final VoidCallback onToggle;
  final String monoFamily;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;

    return InfoPanel(
      padding: EdgeInsets.zero,
      children: <Widget>[
        // The header. `Material` rather than a bare `InkWell`, so the ripple
        // lands on this row instead of on whatever `Material` happens to be
        // above the whole list.
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(t.spaceLg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        SizedBox(height: t.spaceXxs),
                        Text(
                          entry.description,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.spaceSm),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: t.iconSizeMedium,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Metadata, before the text when collapsed so the package names and the
        // homepage are one tap away without expanding, and after it when open
        // so the licence itself is the thing you arrived to read.
        if (!expanded) ...<Widget>[
          if (entry.packages != null)
            _MetadataRow(icon: LucideIcons.package, text: entry.packages!),
          if (entry.url != null)
            _MetadataRow(icon: LucideIcons.externalLink, text: entry.url!),
        ],

        if (expanded) ...<Widget>[
          if (entry.hasAsset && entry.fullText == null)
            Padding(
              padding: EdgeInsets.all(t.spaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: t.iconSizeMedium,
                    height: t.iconSizeMedium,
                    child: CircularProgressIndicator(
                      strokeWidth: t.borderWidthMedium,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (entry.fullText != null)
            Container(
              width: double.infinity,
              // `surfaceContainerLowest`, the ramp's inset-well step, rather
              // than `surfaceContainerHighest`, which is the composer's. A block
              // of body text is an inset, and on this ramp the composer step is
              // the brightest thing on screen.
              color: scheme.surfaceContainerLowest,
              padding: EdgeInsets.all(t.spaceLg),
              child: SelectableText(
                entry.fullText!,
                style: TextStyle(
                  // The app's mono family through the extension, not the
                  // literal `'monospace'`. The welcome screen's wordmark had a
                  // hardcoded `'Oxanium'` and this had a hardcoded
                  // `'monospace'`, which is the same mistake twice.
                  fontFamily: monoFamily,
                  fontSize: 12,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (entry.packages != null)
            _MetadataRow(icon: LucideIcons.package, text: entry.packages!),
          if (entry.url != null)
            _MetadataRow(icon: LucideIcons.externalLink, text: entry.url!),
          SizedBox(height: t.spaceSm),
        ],
      ],
    );
  }
}

/// A small row showing package names or a URL.
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(t.spaceLg, 0, t.spaceLg, t.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: t.iconSizeSmall, color: scheme.onSurfaceVariant),
          SizedBox(width: t.spaceSm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                // The muted token, not `0.8` alpha over the variant colour.
                // `opacitySubtle` is the one the rest of the app uses and the
                // two do not land on the same value.
                color:
                    scheme.onSurfaceVariant.withValues(alpha: t.opacitySubtle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
