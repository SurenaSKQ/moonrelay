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
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/theme/component_tokens.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/theme/surface_layers.dart';
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

/// Moonrelay's route transition policy, driven by the user's animation
/// preference.
///
/// This used to live in the router as a `pageBuilder` that returned a
/// `CustomTransitionPage` (or a `NoTransitionPage` when animations were
/// off). That put the animation setting in two places at once: the router
/// had to consult [SettingsController] from inside a page build, and every
/// route had to remember to route its widget through the helper. Expressing
/// the same policy as a [PageTransitionsBuilder] means the router declares
/// plain `builder:` callbacks and the theme decides how they animate.
///
/// Durations match what the router used: [MotionDurations.medium] forward,
/// [MotionDurations.fast] back.
class MoonrelayPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates the builder for one platform slot.
  const MoonrelayPageTransitionsBuilder({
    required this.animationsEnabled,
  });

  /// Whether route transitions should animate at all.
  final bool animationsEnabled;

  @override
  Duration get transitionDuration =>
      animationsEnabled ? MotionDurations.medium : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      animationsEnabled ? MotionDurations.fast : Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Returning the child untouched is how a transition is disabled
    // without swapping the route type, so the page keeps its key and
    // restoration behaviour.
    if (!animationsEnabled) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}

/// Moonrelay's complete theme definition.
///
/// Provides [light] and [dark] [ThemeData] factories that configure Material 3
/// color schemes, typography, and component styles. The color scheme is
/// seeded from the active accent colour; geometry is fixed by the app's single
/// token set, so the only user-facing appearance controls are the seed colour,
/// the [LayoutDensity] and the font-family overrides.
class MoonrelayTheme {
  MoonrelayTheme._();

  /// App font used when no override is persisted.
  static const String fontFamilyFallback = 'Rubik';

  /// Font used for the display and headline sizes when no override is
  /// persisted.
  ///
  /// The body face does one job and cannot carry the display range as well:
  /// at 36px and up, Rubik's generous counters and rounded terminals read
  /// soft, and a page title set in the same face as a chat message gives
  /// the hierarchy nowhere to go. Space Grotesk was already bundled in
  /// `pubspec.yaml` and unused, and its wide apertures and flat terminals
  /// give the large sizes something to do that the body face cannot.
  ///
  /// Deliberately confined to [TextTheme]'s display and headline roles.
  /// `titleLarge` stays on the body face so that list titles, which sit next
  /// to body text, do not break into a second family mid-scale.
  static const String displayFontFamilyFallback = 'SpaceGrotesk';

  /// Monospace font fallback used when no override is persisted.
  static const String monoFontFamilyFallback = 'FiraCode';

  // -- ThemeData factories ---------------------------------------------

  /// Builds the light [ThemeData] for the given [seed] colour.
  ///
  /// [density], [fontFamily] and [monoFontFamily] are the user's persisted
  /// overrides; when null the built-in defaults win.  [enableAnimations]
  /// gates every route transition; see [MoonrelayPageTransitionsBuilder].
  static ThemeData light(
    Color seed, {
    LayoutDensity? density,
    String? fontFamily,
    String? displayFontFamily,
    String? monoFontFamily,
    bool enableAnimations = true,
  }) =>
      _buildThemeData(
        seed,
        Brightness.light,
        density: density ?? LayoutDensity.comfortable,
        fontFamily: fontFamily ?? fontFamilyFallback,
        displayFontFamily:
            displayFontFamily ?? fontFamily ?? displayFontFamilyFallback,
        monoFontFamily: monoFontFamily ?? monoFontFamilyFallback,
        enableAnimations: enableAnimations,
      );

  /// Builds the dark [ThemeData] for the given [seed] colour.
  static ThemeData dark(
    Color seed, {
    LayoutDensity? density,
    String? fontFamily,
    String? displayFontFamily,
    String? monoFontFamily,
    bool enableAnimations = true,
  }) =>
      _buildThemeData(
        seed,
        Brightness.dark,
        density: density ?? LayoutDensity.comfortable,
        fontFamily: fontFamily ?? fontFamilyFallback,
        displayFontFamily:
            displayFontFamily ?? fontFamily ?? displayFontFamilyFallback,
        monoFontFamily: monoFontFamily ?? monoFontFamilyFallback,
        enableAnimations: enableAnimations,
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
    Color seed,
    Brightness brightness, {
    required LayoutDensity density,
    required String fontFamily,
    required String displayFontFamily,
    required String monoFontFamily,
    required bool enableAnimations,
  }) {
    final seedScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    // The seed only decides the accent ramp. The surfaces are stated
    // explicitly, because a tonal derivation cannot produce a layout where
    // the rail, the room list, and the conversation are three depths of one
    // wall. See [MoonrelaySurfaceLayers].
    final layers = MoonrelaySurfaceLayers.forBrightness(
      brightness,
      accent: seed,
    );
    final colorScheme =
        MoonrelaySurfaceLayers.apply(seedScheme, brightness);
    final tokens = MoonrelayDesignTokens.standard(brightness: brightness);
    final components = MoonrelayComponentTokens.fromDesignTokens(tokens);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: _visualDensity(density),
      fontFamily: fontFamily,
      textTheme: _textTheme(fontFamily, displayFontFamily),
      scaffoldBackgroundColor: colorScheme.surface,

      // Interaction states.
      //
      // Material's defaults are alpha washes of `primary`, and on this
      // palette that reads as a purple tint rather than as the row moving
      // toward the light. Hover and selection are opaque steps from the
      // surface ramp instead, which is what actually happens visually when a
      // row lights up, and it keeps a hovered room row the same colour
      // whether or not it is also selected.
      hoverColor: layers.hover,
      highlightColor: layers.active,
      // Focus still outranks hover: a keyboard user cannot hover, so the
      // focus tint is their only cue and the only state they cannot produce
      // by accident. It is a tint rather than a ring, so it does not by
      // itself satisfy the WCAG 2.2 focus-appearance contrast minimum.
      focusColor: colorScheme.primary.withValues(alpha: tokens.opacityFocusRing),

      // Component themes derived from tokens
      appBarTheme: _appBarTheme(colorScheme, components.appBar, fontFamily, layers),
      cardTheme: _cardTheme(colorScheme, components.card),
      dividerTheme: _dividerTheme(colorScheme, components.divider, layers),
      dialogTheme: _dialogTheme(colorScheme, components.dialog),
      filledButtonTheme: _filledButtonTheme(colorScheme, components.button),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, components.button),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme, components.button),
      textButtonTheme: _textButtonTheme(colorScheme, components.button),
      iconButtonTheme: _iconButtonTheme(colorScheme, tokens),
      listTileTheme: _listTileTheme(colorScheme, components.list),
      snackBarTheme: _snackBarTheme(colorScheme, components.snackBar),
      inputDecorationTheme:
          _inputDecorationTheme(colorScheme, components.input, layers),
      progressIndicatorTheme:
          _progressIndicatorTheme(colorScheme, components.progress),
      chipTheme: _chipTheme(colorScheme, components.chip),
      badgeTheme: _badgeTheme(colorScheme, components.badge),
      tooltipTheme: _tooltipTheme(colorScheme, components.tooltip),
      navigationBarTheme:
          _navigationBarTheme(colorScheme, components.navigation),
      textSelectionTheme: _textSelectionTheme(colorScheme),
      scrollbarTheme: _scrollbarTheme(colorScheme, tokens, layers),

      // Route transitions are a theme concern, not a router concern.
      // See [MoonrelayPageTransitionsBuilder].
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final platform in TargetPlatform.values)
            platform: MoonrelayPageTransitionsBuilder(
              animationsEnabled: enableAnimations,
            ),
        },
      ),

      // Custom design tokens exposed via ThemeExtension
      extensions: <ThemeExtension<dynamic>>[
        MoonrelayThemeExtension(
          monoFontFamily: monoFontFamily,
          tokens: tokens,
          components: components,
          layers: layers,
        ),
      ],
    );
  }

  // -- Component theme builders --------------------------------------

  static AppBarTheme _appBarTheme(
    ColorScheme cs,
    MoonrelayAppBarTokens t,
    String fontFamily,
    MoonrelaySurfaceLayers layers,
  ) {
    return AppBarTheme(
      // `surfaceContainer`, not `surface`.  Every screen's AppBar was the same
      // value as the Scaffold behind it, so on every page in the app the top
      // bar had no visual existence and was defined entirely by its shadow.
      // One step down puts it behind the content, which is the same
      // relationship the mobile shell's own top bar now has.
      backgroundColor: cs.surfaceContainer,
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
      // The shadow never showed on a dark surface: Material renders it from
      // a hardcoded black map. The hairline is what actually separates the
      // bar from the content in both brightnesses.
      surfaceTintColor: Colors.transparent,
      shape: Border(
        bottom: BorderSide(color: layers.hairline),
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
    MoonrelaySurfaceLayers layers,
  ) {
    return DividerThemeData(
      // One hairline colour for every rule in the app.  The pane dividers
      // are the only lines in the layout that are not part of a component,
      // and letting each pick its own alpha is how a shell ends up with
      // five slightly different greys running down the same edge.
      color: layers.hairline,
      thickness: t.thickness,
      space: t.thickness,
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
    MoonrelaySurfaceLayers layers,
  ) {
    final radius = BorderRadius.circular(t.cornerRadius);
    // Filled, not outlined.
    //
    // An outlined field on this palette is a bright 1px rectangle around a
    // hole, which fights the layered surfaces for attention. The mockup's
    // search field is the better pattern: a recessed fill that reads as part
    // of the panel, and a border that only appears to say "this is
    // interactive" and thickens into the accent on focus.
    final resting = BorderSide(
      width: t.borderWidth,
      color: layers.hairline,
    );
    final focused = BorderSide(
      width: t.borderWidth + 0.5,
      color: cs.primary,
    );
    OutlineInputBorder border(BorderSide side) =>
        OutlineInputBorder(borderRadius: radius, borderSide: side);

    return InputDecorationTheme(
      filled: true,
      // One step below its own pane, not the bottom of the ramp.
      //
      // The mockup's search field is filled with the app's darkest surface,
      // which is the rail step, sitting inside the room list one step above
      // it. Filling from `surfaceContainerLowest` instead made it a four-step
      // hole, which on a five-step ramp is closer to the rail's depth than to
      // the sidebar's and so read as a gap in the pane rather than as a
      // control in it.
      fillColor: cs.surfaceContainerLow,
      contentPadding: EdgeInsets.symmetric(
        horizontal: t.contentPaddingH,
        vertical: t.contentPaddingV,
      ),
      border: border(resting),
      enabledBorder: border(resting),
      focusedBorder: border(focused),
      errorBorder: border(
        BorderSide(width: t.borderWidth, color: cs.error),
      ),
      focusedErrorBorder: border(
        BorderSide(width: t.borderWidth + 0.5, color: cs.error),
      ),
      disabledBorder: border(resting),
    );
  }

  /// The scrollbar.
  ///
  /// There was no `scrollbarTheme` at all, so every scroll view in the app
  /// used Material's default: a wide, rounded, `primary`-tinted bar that
  /// appears over the content it is describing. On this palette that reads as
  /// an accent-coloured object lying on top of a room, which is the one thing
  /// a scrollbar must never look like.
  ///
  /// The thumb is the rail step, so it reads as part of the furniture behind
  /// the content rather than as a mark on it, and it darkens on hover instead
  /// of tinting. Thickness is the desktop convention rather than Material's
  /// touch-sized default, and it stays hidden until the pointer is over the
  /// view: the mockup draws a permanent thumb, which on a room list that is
  /// always full would mean paying eight pixels of the width for the whole
  /// session to advertise something the user did not ask about.
  static ScrollbarThemeData _scrollbarTheme(
    ColorScheme cs,
    MoonrelayDesignTokens t,
    MoonrelaySurfaceLayers layers,
  ) {
    // Eight, stated rather than derived. The token scale is a border scale;
    // stretching `borderWidthThick` by a factor to reach eight would be
    // arithmetic dressed up as a system, and the number would be unrepresentable
    // to anyone reading it later.
    const thickness = 8.0;
    final resting = cs.surfaceContainerLow;
    return ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(thickness),
      radius: Radius.circular(t.radiusSm),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return cs.onSurfaceVariant;
        }
        if (states.contains(WidgetState.hovered)) {
          // Darker, not lighter: on hover the bar is already the most
          // contrasty thing in the gutter, and a brighter step would be
          // brighter than anything it is describing.
          return Color.lerp(resting, cs.surfaceContainerLowest, 0.6);
        }
        return resting;
      }),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackVisibility: const WidgetStatePropertyAll(false),
      // Hover-to-reveal, not always-on. See above.
      thumbVisibility: const WidgetStatePropertyAll(false),
      interactive: true,
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

  /// Builds the app's text scale.
  ///
  /// Three things here are load-bearing rather than decorative.
  ///
  /// **Tracking.** Every role used to be set at Flutter's default of zero.
  /// That is fine at 14px and wrong at both ends of the scale: at 36px and up
  /// the same gaps that look relaxed in body copy look like the words have
  /// come apart, so the display and headline roles pull their tracking in as
  /// they grow; at 11px the counters need help staying legible, so the label
  /// roles push theirs out. The crossover sits between `titleMedium` and
  /// `bodyLarge`, which is roughly where the role stops being a heading and
  /// becomes a sentence.
  ///
  /// **Two families.** See [displayFontFamilyFallback].
  ///
  /// **Tabular figures.** The small label roles carry timestamps, unread
  /// counts and room ids. With proportional figures those change width as
  /// their digits change, so a column of them jitters as they tick and a row
  /// of them will not line up. Rubik carries `tnum`, so this is a real
  /// change rather than a no-op; the variation is ignored harmlessly by any
  /// face that lacks it.
  static TextTheme _textTheme(String fontFamily, String displayFontFamily) {
    const tabular = <FontFeature>[FontFeature.tabularFigures()];
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 57,
        letterSpacing: -1.4,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 45,
        letterSpacing: -1.0,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 36,
        letterSpacing: -0.8,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 32,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        letterSpacing: -0.1,
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
        letterSpacing: 0.1,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 1.3,
        letterSpacing: 0.1,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.3,
        fontFeatures: tabular,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.4,
        fontFeatures: tabular,
      ),
    );
  }
}
