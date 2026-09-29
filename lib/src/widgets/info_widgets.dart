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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// -- Shared information-panel pieces ---------------------------------------

/// A small labelled pill, used for a fact about the room or space rather
/// than something the user can act on.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: t.opacitySubtle),
        borderRadius: BorderRadius.circular(t.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          SizedBox(width: t.spaceXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoSectionHeader extends StatelessWidget {
  const InfoSectionHeader({
    super.key,
    required this.title,
    required this.scheme,
    this.icon,
  });

  final String title;
  final ColorScheme scheme;

  /// Optional leading glyph. The room and space panels use a bare title;
  /// the profile and encryption panels lead with an icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final text = Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
    final glyph = icon;
    if (glyph == null) return text;
    return Row(
      children: [
        Icon(glyph, size: 16, color: scheme.onSurfaceVariant),
        SizedBox(width: t.spaceXs),
        text,
      ],
    );
  }
}

class InfoActionTile extends StatelessWidget {
  const InfoActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.color,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final String? description;
  final Color? color;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final effectiveColor = color ?? scheme.primary;
    return Card(
      elevation: t.elevationNone,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, size: 22, color: effectiveColor),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: description != null
            ? Text(
                description!,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              )
            : null,
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

class InfoDetailRow extends StatelessWidget {
  const InfoDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    this.trailing,
    this.valueFontFamily,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  /// Optional widget rendered after the value, e.g. a verification badge.
  final Widget? trailing;

  /// Font for the value. The room and space panels pass a monospace face
  /// because their values are identifiers; the member list does not,
  /// because its values are names and a date.
  final String? valueFontFamily;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          SizedBox(width: t.spaceMd),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
                fontFamily: valueFontFamily,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

