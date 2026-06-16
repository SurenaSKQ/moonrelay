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
  });

  /// The display name of the space.
  final String name;

  /// Optional URL for the space avatar thumbnail.
  final String? thumbnailURL;

  /// Optional subtitle (e.g. room count or description).
  final String? subtitle;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Whether a valid thumbnail URL was provided.
  bool get _hasThumbnail => thumbnailURL != null && thumbnailURL!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                backgroundImage:
                    _hasThumbnail ? NetworkImage(thumbnailURL!) : null,
                onBackgroundImageError: _hasThumbnail ? (_, __) {} : null,
                child: _hasThumbnail
                    ? null
                    : Icon(
                        LucideIcons.folder,
                        size: 24,
                        color: scheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
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
