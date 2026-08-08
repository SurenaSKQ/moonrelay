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
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';

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

/// Preconfigured theme option a user can select in settings.
///
/// Each option maps to a different seed color and produces a distinct
/// light/dark colour palette via [MoonrelayTheme].
enum MoonrelayThemeOption {
  indigo(
    label: 'Default (Indigo)',
    seedColor: Colors.indigo,
  ),
  oceanBlue(
    label: 'Ocean Blue',
    seedColor: MoonrelayColorPalette.ordinaryBlue,
  ),
  midnightSlate(
    label: 'British Racing Green',
    seedColor: MoonrelayColorPalette.britishRacingGreen,
  ),
  crimson(
    label: 'Bright Maroon',
    seedColor: MoonrelayColorPalette.brightMaroon,
  ),
  amber(
    label: 'Amber',
    seedColor: MoonrelayColorPalette.ordinaryOrange,
  ),
  steel(
    label: 'Lime Green',
    seedColor: MoonrelayColorPalette.ordinaryLimeGreen,
  ),
  sky(
    label: 'Sky',
    seedColor: MoonrelayColorPalette.accentColor,
  );

  /// Human-readable name shown in the settings UI.
  final String label;

  /// Seed colour passed to [ColorScheme.fromSeed].
  final Color seedColor;

  const MoonrelayThemeOption({
    required this.label,
    required this.seedColor,
  });
}

/// Moonrelay's complete theme definition.
///
/// Provides [light] and [dark] [ThemeData] factories that configure
/// Material 3 color schemes, typography, and component styles.
/// All visual tokens are centralized here so that changing the seed color,
/// font family, or component defaults propagates everywhere.
class MoonrelayTheme {
  MoonrelayTheme._();

  /// Default UI font family used throughout the application.
  static const String defaultFontFamily = 'Rubik';

  /// Monospace font family used in code blocks, the event viewer, etc.
  static const String monoFontFamily = 'FiraCode';

  // ── ThemeData factories ────────────────────────────────

  /// Creates the light [ThemeData] for the given [option].
  ///
  /// Defaults to [MoonrelayThemeOption.indigo] when omitted.
  ///
  /// [density] selects the [VisualDensity] applied to the theme; it defaults
  /// to [LayoutDensity.comfortable] so existing call sites keep their look.
  static ThemeData light(
    MoonrelayThemeOption option, [
    LayoutDensity density = LayoutDensity.comfortable,
  ]) =>
      _buildThemeData(
        ColorScheme.fromSeed(
          seedColor: option.seedColor,
          brightness: Brightness.light,
        ),
        density,
      );

  /// Creates the dark [ThemeData] for the given [option].
  ///
  /// Defaults to [MoonrelayThemeOption.indigo] when omitted.
  static ThemeData dark(
    MoonrelayThemeOption option, [
    LayoutDensity density = LayoutDensity.comfortable,
  ]) =>
      _buildThemeData(
        ColorScheme.fromSeed(
          seedColor: option.seedColor,
          brightness: Brightness.dark,
        ),
        density,
      );

  // ── Internal builder ────────────────────────────────────────────────────

  /// Maps a [LayoutDensity] choice to a [VisualDensity] for the theme.
  static VisualDensity _visualDensity(LayoutDensity density) {
    return switch (density) {
      LayoutDensity.comfortable => VisualDensity.standard,
      LayoutDensity.compact => VisualDensity.compact,
    };
  }

  static ThemeData _buildThemeData(ColorScheme colorScheme, LayoutDensity density) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Density controls the tightness of Material components based on the
      // user's LayoutDensity setting (previously persisted but unwired).
      visualDensity: _visualDensity(density),


      // Font defaults  all Text widgets that don't explicitly set a
      // fontFamily will inherit this value.
      fontFamily: defaultFontFamily,

      // Typography
      textTheme: _textTheme(),

      // Component themes
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: defaultFontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),

      // Custom design tokens exposed via ThemeExtension
      extensions: const <ThemeExtension<dynamic>>[
        MoonrelayThemeExtension(
          monoFontFamily: monoFontFamily,
        ),
      ],
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 57,
      ),
      displayMedium: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 45,
      ),
      displaySmall: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 36,
      ),
      headlineLarge: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 32,
      ),
      headlineMedium: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 28,
      ),
      headlineSmall: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
      titleLarge: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      titleMedium: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      titleSmall: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(
        fontFamily: defaultFontFamily,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: defaultFontFamily,
        fontSize: 14,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: defaultFontFamily,
        fontSize: 12,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelMedium: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      labelSmall: TextStyle(
        fontFamily: defaultFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    );
  }
}

// ── ThemeExtension for app-specific design tokens ──────────────────────────

/// Custom design tokens that fall outside Material 3's [ColorScheme].
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
