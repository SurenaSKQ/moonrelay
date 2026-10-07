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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Full-screen backdrop for the welcome / sign-on flow.
///
/// Provides a clean, theme-aware surface with a subtle gradient and
/// backdrop blur behind the startup, login, and registration pages.
/// Each child page supplies its own card-based layout, so this frame
/// is intentionally minimal: just a background that respects the
/// current light/dark theme.
class StartupHomeFrame extends StatelessWidget {
  const StartupHomeFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final t = theme.moonrelay.tokens;

    // The app floor with a faint accent glow off the top-left corner.
    //
    // This was a two-stop diagonal from `surface` to `surfaceContainerLow`,
    // which is a real but very quiet gradient: a couple of luminance points
    // across the whole window. It read as a flat page with a slight tint.
    //
    // The three stops put the accent at four percent in the corner and let
    // it fall away to nothing, which is the one place in the app where the
    // accent is allowed to be an atmosphere rather than a signal. Everything
    // else on this screen is the neutral ramp, so the glow is what tells you
    // the window is the app and not a form.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.7, -0.9),
          radius: 1.4,
          colors: [
            colors.primary.withValues(alpha: t.opacityDragged),
            colors.surface,
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Center(child: child),
    );
  }
}
