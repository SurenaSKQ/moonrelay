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
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A card widget for displaying a space's basic info in a grid or list.
///
/// Shows the space thumbnail (or a folder icon fallback), name, and
/// an optional subtitle. Used by the space hierarchy browser and
/// space home page for child subspace tiles.
class SpaceCard extends StatelessWidget {
  const SpaceCard({
    super.key,
    required this.name,
    this.thumbnailURL,
    this.subtitle,
    this.onTap,
    this.client,
  });

  /// The display name of the space.
  final String name;

  /// Optional URL for the space avatar thumbnail.
  final String? thumbnailURL;

  /// Optional subtitle (e.g. room count or description).
  final String? subtitle;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// The client whose token the thumbnail is fetched with.
  ///
  /// Explicit rather than read from a provider, because this widget has no
  /// callers and a card is a pure view: making it depend on an ambient
  /// client means the first person to use it has to discover the missing
  /// provider from a `ProviderNotFoundException` at runtime. Without a
  /// client the card shows its folder icon instead of attempting a request
  /// that would answer 401.
  final Client? client;

  /// Whether a valid thumbnail URL was provided and we can actually fetch it.
  bool get _hasThumbnail =>
      client != null && thumbnailURL != null && thumbnailURL!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Card(
      elevation: t.elevationNone,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(t.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: _hasThumbnail
                    ? NetworkImage(
                        thumbnailURL!,
                        headers: authHeaders(client!),
                      )
                    : null,
                onBackgroundImageError: _hasThumbnail ? (_, __) {} : null,
                child: _hasThumbnail
                    ? null
                    : Icon(
                        LucideIcons.folder,
                        size: t.iconSizeLarge,
                        color: scheme.onPrimaryContainer,
                      ),
              ),
              SizedBox(height: t.spaceSm),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: t.spaceXs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
