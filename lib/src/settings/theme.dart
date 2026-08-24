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
import 'package:moonrelay/src/settings/theme_spec.dart';
import 'package:moonrelay/src/theme/component_tokens.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:flutter/material.dart';

export 'package:moonrelay/src/theme/moonrelay_theme_extension.dart'
    show MoonrelayThemeExtension;

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
/// color schemes, typography, and component styles. The color scheme is seeded
/// from the active [MoonrelayAccent] while every geometric token (fonts,
/// density, corner radius, surface elevation, chat-bubble radius) is sourced
/// from the active [MoonrelayThemeSpec], so swapping either one changes the
/// whole look: a theme swap redefines the widget shape and layout, while an
/// accent swap only recolors the existing widgets. The independent
/// [LayoutDensity], font-family overrides layer on top of the spec's
/// defaults.
class MoonrelayTheme {
  MoonrelayTheme._();

  /// Monospace font fallback used when a theme or override does not specify one.
  static const String monoFontFamilyFallback = 'FiraCode';

  // -- ThemeData factories ---------------------------------------------

  /// Builds the light [ThemeData] for [spec] + [accent].
  ///
  /// [density], [fontFamily] and [monoFontFamily] are the user's persisted
  /// overrides; when null the spec's defaults win.
  static ThemeData light(
    MoonrelayThemeSpec spec,
    MoonrelayAccent accent, {
    LayoutDensity? density,
    String? fontFamily,
    String? monoFontFamily,
  }) =>
      _buildThemeData(
        spec,
        accent,
        Brightness.light,
        density: density ?? spec.defaultDensity,
        fontFamily: fontFamily ?? spec.defaultFontFamily,
        monoFontFamily: monoFontFamily ?? spec.defaultMonoFontFamily,
      );

  /// Builds the dark [ThemeData] for [spec] + [accent].
  static ThemeData dark(
    MoonrelayThemeSpec spec,
    MoonrelayAccent accent, {
    LayoutDensity? density,
    String? fontFamily,
    String? monoFontFamily,
  }) =>
      _buildThemeData(
        spec,
        accent,
        Brightness.dark,
        density: density ?? spec.defaultDensity,
        fontFamily: fontFamily ?? spec.defaultFontFamily,
        monoFontFamily: monoFontFamily ?? spec.defaultMonoFontFamily,
      );

  // -- Internal builder ------------------------------------------------

  /// Maps a [LayoutDensity] choice to a [VisualDensity] for the theme.
  static VisualDensity _visualDensity(LayoutDensity density) {
    return switch (density) {
      LayoutDensity.comfortable => VisualDensity.standard,
      LayoutDensity.compact => VisualDensity.compact,
    };
  }

  static ThemeData _buildThemeData(
    MoonrelayThemeSpec spec,
    MoonrelayAccent accent,
    Brightness brightness, {
    required LayoutDensity density,
    required String fontFamily,
    required String monoFontFamily,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent.seedColor,
      brightness: brightness,
    );
    final tokens = MoonrelayDesignTokens.fromSpec(spec);
    final components = MoonrelayComponentTokens.fromDesignTokens(tokens, spec);

    ThemeData data = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: _visualDensity(density),
      fontFamily: fontFamily,
      textTheme: _textTheme(fontFamily),

      // Component themes derived from tokens
      appBarTheme: _appBarTheme(colorScheme, components.appBar, fontFamily),
      cardTheme: _cardTheme(colorScheme, components.card),
      dividerTheme: _dividerTheme(colorScheme, components.divider),
      dialogTheme: _dialogTheme(colorScheme, components.dialog),
      filledButtonTheme: _filledButtonTheme(colorScheme, components.button),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, components.button),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme, components.button),
      textButtonTheme: _textButtonTheme(colorScheme, components.button),
      iconButtonTheme: _iconButtonTheme(colorScheme, tokens),
      listTileTheme: _listTileTheme(colorScheme, components.list),
      snackBarTheme: _snackBarTheme(colorScheme, components.snackBar),
      inputDecorationTheme:
          _inputDecorationTheme(colorScheme, components.input),
      progressIndicatorTheme:
          _progressIndicatorTheme(colorScheme, components.progress),
      chipTheme: _chipTheme(colorScheme, components.chip),
      badgeTheme: _badgeTheme(colorScheme, components.badge),
      tooltipTheme: _tooltipTheme(colorScheme, components.tooltip),
      navigationBarTheme:
          _navigationBarTheme(colorScheme, components.navigation),
      textSelectionTheme: _textSelectionTheme(colorScheme),

      // Custom design tokens exposed via ThemeExtension
      extensions: <ThemeExtension<dynamic>>[
        MoonrelayThemeExtension(
          monoFontFamily: monoFontFamily,
          tokens: tokens,
          components: components,
        ),
      ],
    );

    // A theme's widget style restyles the geometry (borders, button shape,
    // scrollbar, ...) on top of the shared tokens. Colours stay the accent's
    // job, so this only touches component themes, never the color scheme.
    if (spec.widgetStyle != null) {
      data = spec.widgetStyle!.mergeInto(data, colorScheme, tokens, components);
    }
    return data;
  }

  // -- Component theme builders --------------------------------------

  static AppBarTheme _appBarTheme(
    ColorScheme cs,
    MoonrelayAppBarTokens t,
    String fontFamily,
  ) {
    return AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      elevation: t.elevation,
      scrolledUnderElevation: t.scrolledElevation,
      toolbarHeight: t.toolbarHeight,
      titleTextStyle: t.titleStyle ??
          TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: cs.onSurface,
          ),
    );
  }

  static CardThemeData _cardTheme(ColorScheme cs, MoonrelayCardTokens t) {
    return CardThemeData(
      elevation: t.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.cornerRadius),
      ),
    );
  }

  static DividerThemeData _dividerTheme(
    ColorScheme cs,
    MoonrelayDividerTokens t,
  ) {
    return DividerThemeData(
      color: cs.outlineVariant.withValues(alpha: 0.5),
      thickness: t.thickness,
    );
  }

  static DialogThemeData _dialogTheme(
    ColorScheme cs,
    MoonrelayDialogTokens t,
  ) {
    return DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.cornerRadius),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(
    ColorScheme cs,
    MoonrelayButtonTokens t,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cornerRadius),
        ),
        minimumSize: Size(0, t.minHeight),
        padding: t.padding,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
    ColorScheme cs,
    MoonrelayButtonTokens t,
  ) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cornerRadius),
          side: BorderSide(width: t.borderWidth, color: cs.outline),
        ),
        minimumSize: Size(0, t.minHeight),
        padding: t.padding,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(
    ColorScheme cs,
    MoonrelayButtonTokens t,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(0, t.minHeight),
        padding: t.padding,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(
    ColorScheme cs,
    MoonrelayButtonTokens t,
  ) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cornerRadius),
        ),
        padding: t.padding,
      ),
    );
  }

  static IconButtonThemeData _iconButtonTheme(
    ColorScheme cs,
    MoonrelayDesignTokens t,
  ) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
        padding: EdgeInsets.all(t.spaceSm),
      ),
    );
  }

  static ListTileThemeData _listTileTheme(
    ColorScheme cs,
    MoonrelayListTokens t,
  ) {
    return ListTileThemeData(
      contentPadding: t.contentPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(
    ColorScheme cs,
    MoonrelaySnackBarTokens t,
  ) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.cornerRadius),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme cs,
    MoonrelayInputTokens t,
  ) {
    final radius = BorderRadius.circular(t.cornerRadius);
    final side = BorderSide(width: t.borderWidth, color: cs.outline);
    return InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius, borderSide: side),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(width: t.borderWidth, color: cs.primary),
      ),
    );
  }

  static ProgressIndicatorThemeData _progressIndicatorTheme(
    ColorScheme cs,
    MoonrelayProgressTokens t,
  ) {
    return ProgressIndicatorThemeData(
      linearTrackColor: cs.surfaceContainerHighest,
      strokeWidth: t.strokeWidth,
    );
  }

  static ChipThemeData _chipTheme(ColorScheme cs, MoonrelayChipTokens t) {
    return ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.cornerRadius),
        side: BorderSide(width: t.borderWidth, color: cs.outline),
      ),
      padding: t.padding,
    );
  }

  static BadgeThemeData _badgeTheme(ColorScheme cs, MoonrelayBadgeTokens t) {
    return BadgeThemeData(
      backgroundColor: cs.error,
      textColor: cs.onError,
      smallSize: t.size * 0.75,
      largeSize: t.size,
    );
  }

  static TooltipThemeData _tooltipTheme(
    ColorScheme cs,
    MoonrelayTooltipTokens t,
  ) {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(t.cornerRadius),
      ),
      padding: t.padding,
    );
  }

  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme cs,
    MoonrelayNavigationTokens t,
  ) {
    return NavigationBarThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.indicatorRadius),
      ),
    );
  }

  static TextSelectionThemeData _textSelectionTheme(ColorScheme cs) {
    return TextSelectionThemeData(
      cursorColor: cs.primary,
      selectionColor: cs.primary.withValues(alpha: 0.3),
      selectionHandleColor: cs.primary,
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
