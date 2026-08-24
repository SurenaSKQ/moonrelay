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

/// Moon icon and wordmark shown on the startup screen and in the sidebar.
///
/// Rendered as a vector icon plus styled text so no platform-specific
/// image asset needs to load. The icon gets an animated gradient glow,
/// and colors follow the active theme (or [themeMode] when given).
class LogoWithTextThemed extends StatelessWidget {
  const LogoWithTextThemed({super.key, this.themeMode, this.compact = false});

  /// Optional brightness override. When provided, the icon/text colours
  /// are tuned for that brightness; otherwise they follow the current theme.
  final Brightness? themeMode;

  /// When `true` renders a smaller layout suitable for sidebar footers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = themeMode ?? cs.brightness;

    if (compact) {
      return _buildCompact(context, cs, brightness);
    }
    return _buildFull(context, cs, brightness);
  }

  Widget _buildFull(
    BuildContext context,
    ColorScheme cs,
    Brightness brightness,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final isDark = brightness == Brightness.dark;
    final glowColor = cs.primary.withValues(alpha: isDark ? t.opacityFocus : t.opacityHover);
    final accentColor = cs.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated moon icon with glow
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.3 : t.opacityFocus),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Inner gradient ring
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Moon icon
              Icon(
                LucideIcons.moon,
                size: 48,
                color: accentColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // App name
        Text(
          'Moonrelay',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            fontFamily: 'Oxanium',
            color: cs.onSurface,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: t.spaceXs),

        // Subtitle / alpha label
        Text(
          'Alpha',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Oxanium',
            color: cs.primary,
            letterSpacing: 4,
          ),
        ),
        SizedBox(height: t.spaceSm),

        // Tagline
        Text(
          'A modern Matrix client\nfor professional teams',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(
    BuildContext context,
    ColorScheme cs,
    Brightness brightness,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primaryContainer.withValues(alpha: t.opacitySubtle),
          ),
          child: Icon(
            LucideIcons.moon,
            size: 18,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Moonrelay',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Oxanium',
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceXs,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(t.radiusXs),
          ),
          child: Text(
            'Alpha',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
