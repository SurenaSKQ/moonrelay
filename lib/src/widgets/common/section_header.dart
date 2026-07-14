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

/// A shared section header used across settings pages and profile screens.
///
/// When [icon] is provided the header renders as a row with an icon-lead
/// and colored text. Otherwise it renders as a simple styled text label.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.scheme,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.letterSpacing,
    this.padding,
  });

  final String title;
  final IconData? icon;
  final ColorScheme? scheme;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final double? letterSpacing;
  final EdgeInsetsGeometry? padding;

  Color _effectiveColor(ColorScheme scheme) {
    if (color != null) return color!;
    return icon != null ? scheme.primary : scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final cs = scheme ?? Theme.of(context).colorScheme;
    final effectiveColor = _effectiveColor(cs);

    final text = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: effectiveColor,
          letterSpacing: letterSpacing,
        ),
      ),
    );

    if (icon == null) return text;

    return Row(
      children: [
        Icon(icon, size: 18, color: effectiveColor),
        const SizedBox(width: 8),
        text,
      ],
    );
  }
}
