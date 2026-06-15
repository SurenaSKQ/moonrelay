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

/// A branding widget that displays a moon icon and the project name.
///
/// Replaces the previous raster-logo approach with a crisp vector icon
/// and styled text, avoiding platform-specific image loading issues.
class LogoWithTextThemed extends StatelessWidget {
  const LogoWithTextThemed({super.key, this.themeMode});

  /// Optional brightness override. When provided, the icon/text colours
  /// are tuned for that brightness; otherwise they follow the current theme.
  final Brightness? themeMode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.moon, size: 64, color: cs.primary),
        const SizedBox(height: 12),
        Text(
          'Moonrelay (Alpha)',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFamily: 'Oxanium',
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
