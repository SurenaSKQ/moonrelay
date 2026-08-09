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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders an m.location event. Shows the latitude, longitude and accuracy,
/// and a button to open the position in a maps app (via `geo:` URI).
class LocationMessageType extends StatelessWidget {
  const LocationMessageType({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    final content = event.content;
    final info = content['info'];
    double? lat;
    double? lon;
    double? accuracy;
    if (info is Map) {
      lat = (info['latitude'] as num?)?.toDouble();
      lon = (info['longitude'] as num?)?.toDouble();
      accuracy = (info['accuracy'] as num?)?.toDouble();
    }
    if (lat == null || lon == null) {
      // Fall back to geo_uri "geo:lat,lon"
      final geoUri = content['geo_uri'] as String?;
      if (geoUri != null) {
        final match =
            RegExp(r'^geo:(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(geoUri);
        if (match != null) {
          lat = double.tryParse(match.group(1)!);
          lon = double.tryParse(match.group(2)!);
        }
      }
    }

    if (lat == null || lon == null) {
      return _buildUnavailable(context, cs);
    }

    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaSizePrefs.of(context).locationMax),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
        borderRadius: BorderRadius.circular(t.radiusMd + 2),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: t.opacityDisabled),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Header ---------------------------------------------------
          Padding(
            padding:
                EdgeInsets.fromLTRB(t.spaceMd + 2, t.spaceMd, t.spaceMd + 2, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: t.opacityFocus),
                    borderRadius: BorderRadius.circular(t.radiusMd - 2),
                  ),
                  child: Icon(
                    LucideIcons.mapPin,
                    size: t.iconSizeMedium,
                    color: cs.primary,
                  ),
                ),
                SizedBox(width: t.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lat: ${lat.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                      SizedBox(height: t.spaceXxs),
                      Text(
                        'Lon: ${lon.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -- Body / metadata ------------------------------------------
          Padding(
            padding: EdgeInsets.fromLTRB(
                t.spaceMd + 2, t.spaceMd - 2, t.spaceMd + 2, t.spaceMd - 2),
            child: Row(
              children: [
                if (accuracy != null) ...[
                  Icon(
                    LucideIcons.crosshair,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: t.spaceXs),
                  Text(
                    l10n.locationAccuracyMeters(accuracy.round()),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                FilledButton.tonalIcon(
                  icon: Icon(LucideIcons.externalLink, size: t.iconSizeSmall),
                  label: Text(l10n.openInMaps),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spaceMd,
                      vertical: t.spaceXs + 2,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _openInMaps(context, lat!, lon!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(
    BuildContext context,
    double lat,
    double lon,
  ) async {
    final url = Uri.parse(
      'geo:$lat,$lon?q=$lat,$lon(${AppLocalizations.of(context)!.shareLocation})',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _buildUnavailable(BuildContext context, ColorScheme cs) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: t.opacityDragged),
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Icon(LucideIcons.map, size: 40, color: cs.error),
    );
  }
}
