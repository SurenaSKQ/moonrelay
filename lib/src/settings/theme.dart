// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/skins.dart';
import 'package:flutter/material.dart';

/// Central store for text-direction state.
///
/// Kept as a standalone [ChangeNotifier] so it can be wired into the app's
/// widget tree independently of [MoonrelayTheme].
class MoonrelayAppTheme extends ChangeNotifier {
  TextDirection _textDirection = TextDirection.ltr;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection direction) {
    _textDirection = direction;
    notifyListeners();
  }

  /// Update text direction based on a locale code.
  ///
  /// Sets RTL for Persian (fa) and LTR for everything else.
  void updateFromLocale(String? localeCode) {
    final dir = localeCode != null && localeCode.startsWith('fa')
        ? TextDirection.rtl
        : TextDirection.ltr;
    if (_textDirection != dir) {
      _textDirection = dir;
      notifyListeners();
    }
  }
}

/// Moonrelay's complete theme definition.
///
/// Provides [light] and [dark] [ThemeData] factories that configure Material 3
/// color schemes, typography, and component styles. All visual tokens are
/// sourced from a [MoonrelaySkin], so swapping the skin (see
/// [MoonrelaySkins]) changes the entire look and feel. The independent
/// [LayoutDensity], font-family overrides layered on top of the skin's
/// defaults.
class MoonrelayTheme {
  MoonrelayTheme._();

  /// Monospace font fallback used when a skin does not specify one.
  static const String monoFontFamilyFallback = 'FiraCode';

  // ── ThemeData factories ─────────────────────────────────────────────

  /// Builds the light [ThemeData] for [skin].
  ///
  /// [density], [fontFamily] and [monoFontFamily] are the user's persisted
  /// overrides; when null the skin's defaults win.
  static ThemeData light(
    MoonrelaySkin skin, {
    LayoutDensity? density,
    String? fontFamily,
    String? monoFontFamily,
  }) =>
      _buildThemeData(
        skin,
        Brightness.light,
        density: density ?? skin.defaultDensity,
        fontFamily: fontFamily ?? skin.defaultFontFamily,
        monoFontFamily: monoFontFamily ?? skin.defaultMonoFontFamily,
      );

  /// Builds the dark [ThemeData] for [skin].
  static ThemeData dark(
    MoonrelaySkin skin, {
    LayoutDensity? density,
    String? fontFamily,
    String? monoFontFamily,
  }) =>
      _buildThemeData(
        skin,
        Brightness.dark,
        density: density ?? skin.defaultDensity,
        fontFamily: fontFamily ?? skin.defaultFontFamily,
        monoFontFamily: monoFontFamily ?? skin.defaultMonoFontFamily,
      );

  // ── Internal builder ────────────────────────────────────────────────

  /// Maps a [LayoutDensity] choice to a [VisualDensity] for the theme.
  static VisualDensity _visualDensity(LayoutDensity density) {
    return switch (density) {
      LayoutDensity.comfortable => VisualDensity.standard,
      LayoutDensity.compact => VisualDensity.compact,
    };
  }

  static ThemeData _buildThemeData(
    MoonrelaySkin skin,
    Brightness brightness, {
    required LayoutDensity density,
    required String fontFamily,
    required String monoFontFamily,
  }) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: skin.seedColor,
      brightness: brightness,
    );
    final double radius = skin.cornerRadius;
    final double elevation = skin.surfaceElevation;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Density controls the tightness of Material components based on the
      // user's LayoutDensity setting.
      visualDensity: _visualDensity(density),

      // Font defaults: any Text widget that does not explicitly set a
      // fontFamily inherits this value, so the font-family setting now
      // applies app-wide instead of being hard-coded.
      fontFamily: fontFamily,

      // Typography
      textTheme: _textTheme(fontFamily),

      // Component themes
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),

      // Dialog / bottom-sheet corners follow the skin radius too, so the
      // surface language stays consistent across the app.
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      // Custom design tokens exposed via ThemeExtension
      extensions: <ThemeExtension<dynamic>>[
        MoonrelayThemeExtension(monoFontFamily: monoFontFamily),
      ],
    );
  }

  static TextTheme _textTheme(String fontFamily) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 57,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 45,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 36,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 32,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 28,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    );
  }
}

// ── ThemeExtension for app-specific design tokens ────────────────────────────

/// Custom design tokens that fall outside Material 3's [ColorScheme].
///
/// Access via `Theme.of(context).extension<MoonrelayThemeExtension>()`.
@immutable
class MoonrelayThemeExtension extends ThemeExtension<MoonrelayThemeExtension> {
  /// Font family for monospace text (code blocks, etc.).
  final String monoFontFamily;

  const MoonrelayThemeExtension({
    required this.monoFontFamily,
  });

  @override
  MoonrelayThemeExtension copyWith({
    String? monoFontFamily,
  }) {
    return MoonrelayThemeExtension(
      monoFontFamily: monoFontFamily ?? this.monoFontFamily,
    );
  }

  @override
  MoonrelayThemeExtension lerp(
    covariant MoonrelayThemeExtension? other,
    double t,
  ) {
    if (other is! MoonrelayThemeExtension) return this;
    return MoonrelayThemeExtension(
      monoFontFamily: t < 0.5 ? monoFontFamily : other.monoFontFamily,
    );
  }
}
