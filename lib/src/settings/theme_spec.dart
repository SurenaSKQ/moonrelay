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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/theme/component_tokens.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/shipped_themes/shipped_themes.dart';

/// A complete "look and feel" recipe for Moonrelay.
///
/// A theme spec owns every visual token that defines the app's *geometry*:
/// the default font families, the default [LayoutDensity], the corner radius
/// applied to cards and surfaces, the surface elevation, and the default
/// chat-bubble radius. Together these fully determine what the app *looks
/// like*, independent of the colour (the job of [MoonrelayAccent]).
///
/// Swapping the active theme ([SettingsController.updateSelectedTheme]) resets
/// the independent appearance controls (density, app font family, mono font
/// family and chat bubble radius) to this spec's defaults, so the change
/// redefines the entire look in one action. New themes can be added by
/// appending to [MoonrelayThemes.all]; no other call site needs to change.
@immutable
class MoonrelayThemeSpec {
  /// Stable machine id persisted in settings and used for migration.
  final String id;

  /// Human-readable name shown in the theme picker. English only; matches the
  /// convention used by [LayoutDensity], [DisplayType], etc.
  final String label;

  /// Short sentence describing the spec's character, shown as a subtitle.
  final String description;

  /// Default application font family for this theme.
  final String defaultFontFamily;

  /// Default monospace font family for this theme (code blocks, event IDs).
  final String defaultMonoFontFamily;

  /// Default [LayoutDensity] applied when this theme is selected.
  final LayoutDensity defaultDensity;

  /// Border radius applied to cards, dialogs and other Material surfaces.
  final double cornerRadius;

  /// Elevation applied to cards and tonal surfaces.
  final double surfaceElevation;

  /// Default corner radius for chat message bubbles.
  final double defaultBubbleRadius;

  const MoonrelayThemeSpec({
    required this.id,
    required this.label,
    required this.description,
    this.defaultFontFamily = 'Rubik',
    this.defaultMonoFontFamily = 'FiraCode',
    this.defaultDensity = LayoutDensity.comfortable,
    this.cornerRadius = 12.0,
    this.surfaceElevation = 0.0,
    this.defaultBubbleRadius = 12.0,
    this.widgetStyle,
  });

  /// Optional per-theme widget geometry. When null the theme uses the default
  /// Material 3 component styling; a non-null style redefines how the
  /// widgets *feel* (borders, button shape, scrollbar, etc.) while every
  /// colour stays the job of the active accent.
  final MoonrelayWidgetStyle? widgetStyle;
}

/// Central registry of every theme Moonrelay ships with.
///
/// Add a theme here and it automatically appears in the settings picker and is
/// accepted by [MoonrelayThemes.byId] / [MoonrelayThemes.fromId]. The first
/// entry is the default.
class MoonrelayThemes {
  MoonrelayThemes._();

  // -- Shipped themes ---------------------------------------------------

   /// The bundled themes, in their persisted/display order. The first entry is
   /// [MoonrelayThemes.defaultTheme].
   static const List<MoonrelayThemeSpec> all = <MoonrelayThemeSpec>[
     material,
     highContrast,
     compact,
     archVista,
     moonrelay,
     minimal,
     organic,
   ];

   /// The default Material 3 look shared by most accent colours.
   static const MoonrelayThemeSpec material = materialTheme;

   /// Sharp-cornered, elevated variant for clarity on large screens.
   static const MoonrelayThemeSpec highContrast = highContrastTheme;

   /// Tighter, smaller-cornered variant for dense workspaces.
   static const MoonrelayThemeSpec compact = compactTheme;

   /// "Darkened Windows Vista UI" look: near-square corners, Sego UI font and a
   /// comfortable density, plus a [MoonrelayWidgetStyle.vista] that re-styles
   /// buttons, checkboxes, scrollbars and dividers with Vista's flat, bordered
   /// chrome. The signature air-force-blue accent (#5C8AA6) is a separate
   /// [MoonrelayAccents.vistaBlue] so it can be swapped independently.
   static const MoonrelayThemeSpec archVista = archVistaTheme;

   /// Moonrelay's signature look: distinctive app bar, signature shadows.
   static const MoonrelayThemeSpec moonrelay = moonrelayTheme;

   /// Flat, borderless variant with no surface elevation.
   static const MoonrelayThemeSpec minimal = minimalTheme;

   /// Soft, generously rounded variant with low elevation.
   static const MoonrelayThemeSpec organic = organicTheme;

  // -- Defaults --------------------------------------------------------

  /// The theme used on first install and when an unknown id is requested.
  static const MoonrelayThemeSpec defaultTheme = material;

  /// Stable machine id of [defaultTheme].
  static const String defaultThemeId = 'material';

  // -- Lookup ----------------------------------------------------------

  /// Returns the theme whose [MoonrelayThemeSpec.id] matches [id], or null
  /// when no such theme exists.
  static MoonrelayThemeSpec? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return null;
  }

  /// Returns [byId] or [defaultTheme] when [id] is unknown, so callers always
  /// receive a valid theme.
  static MoonrelayThemeSpec fromId(String? id) => byId(id) ?? defaultTheme;
}

/// A swappable colour accent applied *within* the active
/// [MoonrelayThemeSpec].
///
/// Where a theme spec owns the geometry (fonts, density, corners), an accent
/// owns the hue: its [seedColor] drives the Material 3 color scheme. Changing
/// the accent recolors the current theme's widgets but leaves their shape and
/// layout untouched.
@immutable
class MoonrelayAccent {
  /// Stable machine id persisted in settings.
  final String id;

  /// Human-readable name shown in the accent picker.
  final String label;

  /// Seed colour fed to [ColorScheme.fromSeed].
  final Color seedColor;

  const MoonrelayAccent({
    required this.id,
    required this.label,
    required this.seedColor,
  });
}

/// Central registry of every accent colour Moonrelay ships with.
class MoonrelayAccents {
  MoonrelayAccents._();

  // -- Shipped accents --------------------------------------------------

  /// The bundled accents, in their persisted/display order. The first entry is
  /// [MoonrelayAccents.defaultAccent].
  static const List<MoonrelayAccent> all = <MoonrelayAccent>[
    indigo,
    ocean,
    midnight,
    crimson,
    amber,
    steel,
    sky,
    charcoal,
    vistaBlue,
  ];

  static const MoonrelayAccent indigo = MoonrelayAccent(
    id: 'indigo',
    label: 'Indigo',
    seedColor: Colors.indigo,
  );

  static const MoonrelayAccent ocean = MoonrelayAccent(
    id: 'ocean',
    label: 'Ocean Blue',
    seedColor: MoonrelayColorPalette.ordinaryBlue,
  );

  static const MoonrelayAccent midnight = MoonrelayAccent(
    id: 'midnight',
    label: 'British Racing Green',
    seedColor: MoonrelayColorPalette.britishRacingGreen,
  );

  static const MoonrelayAccent crimson = MoonrelayAccent(
    id: 'crimson',
    label: 'Bright Maroon',
    seedColor: MoonrelayColorPalette.brightMaroon,
  );

  static const MoonrelayAccent amber = MoonrelayAccent(
    id: 'amber',
    label: 'Amber',
    seedColor: MoonrelayColorPalette.ordinaryOrange,
  );

  static const MoonrelayAccent steel = MoonrelayAccent(
    id: 'steel',
    label: 'Lime Green',
    seedColor: MoonrelayColorPalette.ordinaryLimeGreen,
  );

  static const MoonrelayAccent sky = MoonrelayAccent(
    id: 'sky',
    label: 'Sky',
    seedColor: MoonrelayColorPalette.accentColor,
  );

  /// Neutral accent used as the default for the high-contrast theme.
  static const MoonrelayAccent charcoal = MoonrelayAccent(
    id: 'charcoal',
    label: 'Charcoal',
    seedColor: MoonrelayColorPalette.ordinaryDarkGrey,
  );

  /// ArchVista's signature air-force blue (#5C8AA6), the dominant filled
  /// accent in the GTK theme's `gtk.css`.
  static const MoonrelayAccent vistaBlue = MoonrelayAccent(
    id: 'vistaBlue',
    label: 'Vista Blue',
    seedColor: Color(0xFF5C8AA6),
  );

  // -- Defaults --------------------------------------------------------

  /// The accent used on first install and when an unknown id is requested.
  static const MoonrelayAccent defaultAccent = indigo;

  /// Stable machine id of [defaultAccent].
  static const String defaultAccentId = 'indigo';

  // -- Lookup ----------------------------------------------------------

  /// Returns the accent whose [MoonrelayAccent.id] matches [id], or null when
  /// no such accent exists.
  static MoonrelayAccent? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final accent in all) {
      if (accent.id == id) return accent;
    }
    return null;
  }

  /// Returns [byId] or [defaultAccent] when [id] is unknown, so callers always
  /// receive a valid accent.
  static MoonrelayAccent fromId(String? id) => byId(id) ?? defaultAccent;
}

/// Distinguishes the different widget-geometry looks a theme can apply.
///
/// A [MoonrelayWidgetStyle] only touches *geometry and neutral chrome*; the
/// accent color always comes from the active [MoonrelayAccent]. Each value
/// dispatches to a dedicated merge strategy inside
/// [MoonrelayWidgetStyle.mergeInto].
enum MoonrelayStyleType {
  /// "Darkened Windows Vista UI" chrome: flat buttons with a thin outline.
  vista,

  /// Flat, borderless, no-elevation surfaces.
  minimal,

  /// Soft, generously rounded with subtle borders.
  organic,

  /// Moonrelay's signature look: distinctive app bar and signature shadows.
  moonrelay,
}

/// A theme's widget geometry: the bits of "feel" that a color accent cannot
/// express (button shape and borders, scrollbar thickness, checkbox style,
/// divider weight, etc.).
///
/// A [MoonrelayWidgetStyle] only ever touches *geometry and the neutral
/// chrome* (borders, outlines); it never sets an accent color directly. The
/// accent color comes exclusively from the active [MoonrelayAccent], so
/// recoloring stays a pure, single-axis change. The theme builder merges a
/// spec's widget style on top of the base [ThemeData] (see
/// `MoonrelayTheme._buildThemeData`).
@immutable
class MoonrelayWidgetStyle {
  const MoonrelayWidgetStyle({
    required this.styleType,
    required this.cornerRadius,
    required this.borderWidth,
    required this.borderAlpha,
    required this.buttonMinHeight,
    required this.sliderThumbRadius,
    required this.scrollbarThickness,
  });

  /// The look profile that selects which merge strategy [mergeInto] applies.
  final MoonrelayStyleType styleType;

  /// The Vista look: flat buttons with a thin outline, square-ish corners,
  /// a narrow scrollbar and the thin divider line characteristic of the GTK
  /// theme. Colours are derived from the running color scheme, so this same
  /// style works with any accent.
  static const MoonrelayWidgetStyle vista = MoonrelayWidgetStyle(
    styleType: MoonrelayStyleType.vista,
    cornerRadius: 4.0,
    borderWidth: 1.0,
    borderAlpha: 0.5,
    buttonMinHeight: 28.0,
    sliderThumbRadius: 7.0,
    scrollbarThickness: 8.0,
  );

  /// Flat, borderless, no-elevation style. Removes all surface chrome for a
  /// monochrome, utility-focused look.
  static const MoonrelayWidgetStyle minimal = MoonrelayWidgetStyle(
    styleType: MoonrelayStyleType.minimal,
    cornerRadius: 0.0,
    borderWidth: 0.0,
    borderAlpha: 0.0,
    buttonMinHeight: 32.0,
    sliderThumbRadius: 6.0,
    scrollbarThickness: 4.0,
  );

  /// Soft, generously rounded style with subtle borders and low elevation.
  static const MoonrelayWidgetStyle organic = MoonrelayWidgetStyle(
    styleType: MoonrelayStyleType.organic,
    cornerRadius: 20.0,
    borderWidth: 1.0,
    borderAlpha: 0.2,
    buttonMinHeight: 42.0,
    sliderThumbRadius: 8.0,
    scrollbarThickness: 6.0,
  );

  /// Moonrelay's signature look: a distinctive app bar with an accent-accented
  /// bottom indicator, signature card shadows, and softly rounded buttons.
  static const MoonrelayWidgetStyle moonrelay = MoonrelayWidgetStyle(
    styleType: MoonrelayStyleType.moonrelay,
    cornerRadius: 12.0,
    borderWidth: 1.0,
    borderAlpha: 0.4,
    buttonMinHeight: 36.0,
    sliderThumbRadius: 7.0,
    scrollbarThickness: 8.0,
  );

  /// Corner radius applied to buttons, inputs and menu surfaces.
  final double cornerRadius;

  /// Stroke width for component outlines (buttons, checkboxes, dividers).
  final double borderWidth;

  /// Opacity of the `outlineVariant` color used for those outlines, so the
  /// chrome tracks the light/dark theme.
  final double borderAlpha;

  /// Minimum height of a filled/button control.
  final double buttonMinHeight;

  /// Radius of the slider thumb overlay.
  final double sliderThumbRadius;

  /// Thickness of the scrollbar thumb.
  final double scrollbarThickness;

  /// Resolves the neutral border color used across Vista's chrome.
  Color _borderColor(ColorScheme cs) =>
      cs.outlineVariant.withValues(alpha: borderAlpha);

  /// Returns [base] with theme-specific component themes layered on top.
  ///
  /// [tokens] and [components] provide the atomic and per-component design
  /// tokens for the active theme, allowing style overrides to reference
  /// semantic values instead of hardcoded numbers.
  ThemeData mergeInto(
    ThemeData base,
    ColorScheme cs,
    MoonrelayDesignTokens tokens,
    MoonrelayComponentTokens components,
  ) {
    switch (styleType) {
      case MoonrelayStyleType.vista:
        return _mergeVista(base, cs, tokens, components);
      case MoonrelayStyleType.minimal:
        return _mergeMinimal(base, cs, tokens, components);
      case MoonrelayStyleType.organic:
        return _mergeOrganic(base, cs, tokens, components);
      case MoonrelayStyleType.moonrelay:
        return _mergeMoonrelay(base, cs, tokens, components);
    }
  }

  // -- Vista merge -------------------------------------------------------

  /// Vista look: flat, bordered buttons; bordered surfaces; narrow scrollbar.
  ThemeData _mergeVista(
    ThemeData base,
    ColorScheme cs,
    MoonrelayDesignTokens tokens,
    MoonrelayComponentTokens components,
  ) {
    final border = _borderColor(cs);
    final radius = BorderRadius.circular(cornerRadius);
    final innerRadius = BorderRadius.circular(cornerRadius - 1);
    final side = BorderSide(width: borderWidth, color: border);

    return base.copyWith(
      // -- Buttons ---------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: EdgeInsets.all(tokens.spaceSm),
        ),
      ),

      // -- Toggle controls -------------------------------------------
      checkboxTheme: CheckboxThemeData(
        side: side,
        shape: RoundedRectangleBorder(borderRadius: innerRadius),
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: 0.24)
                : null),
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.0)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.54)),
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: 0.24)
                : null),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? cs.primary : cs.outline),
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: 0.24)
                : null),
      ),

      // -- Slider ----------------------------------------------------
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.24),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: components.button.iconSize,
        ),
      ),

      // -- Scrollbar -------------------------------------------------
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        thickness: WidgetStateProperty.all(scrollbarThickness),
        radius: Radius.circular(cornerRadius - 1),
        mainAxisMargin: 2,
        crossAxisMargin: 2,
      ),

      // -- Surfaces --------------------------------------------------
      cardTheme: CardThemeData(
        elevation: base.cardTheme.elevation,
        color: base.cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      ),

      // -- Inputs ----------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius, borderSide: side),
        enabledBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: side),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(width: borderWidth, color: cs.primary),
        ),
      ),

      // -- Dividers --------------------------------------------------
      dividerTheme: DividerThemeData(color: border, thickness: borderWidth),

      // -- AppBar ----------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: border, width: borderWidth)),
        titleTextStyle: base.appBarTheme.titleTextStyle,
      ),

      // -- List tiles ------------------------------------------------
      listTileTheme: ListTileThemeData(
        contentPadding: components.list.contentPadding,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // -- SnackBar --------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.snackBar.cornerRadius),
        ),
      ),

      // -- Progress indicators ---------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: cs.surfaceContainerHighest,
        strokeWidth: components.progress.strokeWidth,
      ),

      // -- Chips -----------------------------------------------------
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.chip.cornerRadius),
          side: BorderSide(
            width: components.chip.borderWidth,
            color: border,
          ),
        ),
        padding: components.chip.padding,
      ),

      // -- Tooltips --------------------------------------------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(components.tooltip.cornerRadius),
        ),
        padding: components.tooltip.padding,
      ),

      // -- Navigation ------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(components.navigation.indicatorRadius),
        ),
      ),

      // -- Popup menu ------------------------------------------------
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),

      // -- Badge -----------------------------------------------------
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
        smallSize: components.badge.size * 0.75,
        largeSize: components.badge.size,
      ),

       // -- Text selection --------------------------------------------
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.3),
        selectionHandleColor: cs.primary,
      ),
    );
  }

  // -- Minimal merge -----------------------------------------------------

  /// Flat, borderless style: no elevation, no component borders, thin chrome.
  ThemeData _mergeMinimal(
    ThemeData base,
    ColorScheme cs,
    MoonrelayDesignTokens tokens,
    MoonrelayComponentTokens components,
  ) {
    final radius = BorderRadius.circular(cornerRadius);
    final thin = BorderSide(
      width: tokens.borderWidthThin,
      color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
    );

    return base.copyWith(
      // Flat surfaces: no elevation, no borders
      cardTheme: CardThemeData(
        elevation: 0,
        color: base.cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // Borderless buttons with standard Material background
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: EdgeInsets.all(tokens.spaceSm),
        ),
      ),

      // Flat app bar
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.appBarTheme.titleTextStyle,
      ),

      // Thin monochrome dividers
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
        thickness: tokens.borderWidthThin,
      ),

      // Thin scrollbar, square thumb
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          cs.onSurfaceVariant.withValues(alpha: tokens.opacitySubtle),
        ),
        thickness: WidgetStateProperty.all(scrollbarThickness),
        radius: Radius.zero,
        mainAxisMargin: 0,
        crossAxisMargin: 0,
      ),

      // Borderless inputs
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: thin,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: thin,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            width: tokens.borderWidthThin,
            color: cs.primary,
          ),
        ),
      ),

      // Borderless chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.chip.cornerRadius),
        ),
        padding: components.chip.padding,
      ),

      // Borderless list tiles
      listTileTheme: ListTileThemeData(
        contentPadding: components.list.contentPadding,
      ),

      // Standard toggle controls
      checkboxTheme: CheckboxThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: tokens.opacityHover)
                : null),
      ),
      radioTheme: RadioThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: tokens.opacityHover)
                : null),
      ),
      switchTheme: SwitchThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: tokens.opacityHover)
                : null),
      ),

      // Standard slider
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.24),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: sliderThumbRadius,
        ),
      ),

      // Standard progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: cs.surfaceContainerHighest,
        strokeWidth: components.progress.strokeWidth,
      ),

      // Standard badge
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
        smallSize: components.badge.size * 0.75,
        largeSize: components.badge.size,
      ),

      // Standard navigation
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(components.navigation.indicatorRadius),
        ),
      ),

      // Standard popup menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),

      // Standard tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(components.tooltip.cornerRadius),
        ),
        padding: components.tooltip.padding,
      ),

      // Standard text selection
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.3),
        selectionHandleColor: cs.primary,
      ),
    );
  }

  // -- Organic merge -----------------------------------------------------

  /// Soft, generously rounded style with subtle borders and low elevation.
  ThemeData _mergeOrganic(
    ThemeData base,
    ColorScheme cs,
    MoonrelayDesignTokens tokens,
    MoonrelayComponentTokens components,
  ) {
    final radius = BorderRadius.circular(cornerRadius);
    final subtle = BorderSide(
      width: tokens.borderWidthThin,
      color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
    );

    return base.copyWith(
      // Softly elevated surfaces with rounded corners
      cardTheme: CardThemeData(
        elevation: tokens.elevationLow,
        color: base.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: subtle,
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: tokens.elevationLow,
        shape: RoundedRectangleBorder(borderRadius: radius, side: subtle),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        elevation: tokens.elevationLow,
        shape: RoundedRectangleBorder(borderRadius: radius, side: subtle),
      ),

      // Rounded buttons with subtle borders
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              width: tokens.borderWidthThin,
              color: cs.primary.withValues(alpha: tokens.opacitySubtle),
            ),
          ),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              width: tokens.borderWidthThin,
              color: cs.outline,
            ),
          ),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius),
          overlayColor: cs.primary.withValues(alpha: tokens.opacityHover),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: EdgeInsets.all(tokens.spaceSm),
        ),
      ),

      // Softly elevated app bar
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: tokens.elevationLow,
        scrolledUnderElevation: tokens.elevationMedium,
        titleTextStyle: base.appBarTheme.titleTextStyle,
        shape: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
            width: tokens.borderWidthThin,
          ),
        ),
      ),

      // Subtle dividers
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
        thickness: tokens.borderWidthThin,
      ),

      // Rounded scrollbar thumb
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          cs.onSurfaceVariant.withValues(alpha: tokens.opacitySubtle),
        ),
        thickness: WidgetStateProperty.all(scrollbarThickness),
        radius: Radius.circular(cornerRadius),
        mainAxisMargin: 2,
        crossAxisMargin: 2,
      ),

      // Rounded inputs with subtle border
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: subtle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: subtle,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            width: tokens.borderWidthThin,
            color: cs.primary,
          ),
        ),
      ),

      // Rounded chips with subtle border
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.chip.cornerRadius),
          side: BorderSide(
            width: components.chip.borderWidth,
            color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
          ),
        ),
        padding: components.chip.padding,
      ),

      // Rounded list tiles with generous padding
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spaceXl,
          vertical: tokens.spaceSm,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // Rounded snack bar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.snackBar.cornerRadius),
        ),
      ),

      // Standard toggle controls with subtle overlay
      checkboxTheme: CheckboxThemeData(
        side: subtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius - 1),
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: tokens.opacityHover)
                : null),
      ),
      radioTheme: RadioThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: tokens.opacityHover)
                : null),
      ),
      switchTheme: SwitchThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: tokens.opacityHover)
                : null),
      ),

      // Rounded slider
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.24),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: sliderThumbRadius,
        ),
      ),

      // Standard progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: cs.surfaceContainerHighest,
        strokeWidth: components.progress.strokeWidth,
      ),

      // Standard badge
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
        smallSize: components.badge.size * 0.75,
        largeSize: components.badge.size,
      ),

      // Rounded navigation indicator
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(components.navigation.indicatorRadius),
        ),
      ),

      // Rounded popup menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // Standard tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(components.tooltip.cornerRadius),
        ),
        padding: components.tooltip.padding,
      ),

      // Standard text selection
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.3),
        selectionHandleColor: cs.primary,
      ),
    );
  }

  // -- Moonrelay signature merge ------------------------------------------

  /// Moonrelay's signature look: distinctive app bar with an accent indicator
  /// line, elevated cards with signature shadow, and softly rounded buttons.
  ThemeData _mergeMoonrelay(
    ThemeData base,
    ColorScheme cs,
    MoonrelayDesignTokens tokens,
    MoonrelayComponentTokens components,
  ) {
    final radius = BorderRadius.circular(cornerRadius);
    final border = _borderColor(cs);
    final side = BorderSide(width: borderWidth, color: border);

    return base.copyWith(
      // Elevated cards with signature shadow and rounded corners
      cardTheme: CardThemeData(
        elevation: tokens.elevationMedium,
        color: base.cardTheme.color,
        shadowColor: cs.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      ),
      dialogTheme: DialogThemeData(
        elevation: tokens.elevationMedium,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        elevation: tokens.elevationMedium,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      ),

      // Standard buttons with signature hover shadow
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
          shadowColor: cs.shadow,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
          shadowColor: cs.shadow,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              width: tokens.borderWidthThin,
              color: cs.outline,
            ),
          ),
          minimumSize: Size(0, buttonMinHeight),
          padding: components.button.padding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: EdgeInsets.all(tokens.spaceSm),
        ),
      ),

      // Distinctive app bar: low elevation with accent-accented bottom border
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: tokens.elevationLow,
        scrolledUnderElevation: tokens.elevationLow,
        toolbarHeight: tokens.minTapTarget,
        titleTextStyle: base.appBarTheme.titleTextStyle ??
            TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface,
            ),
        shape: Border(
          bottom: BorderSide(
            color: cs.primary.withValues(alpha: tokens.opacityMuted),
            width: tokens.borderWidthMedium,
          ),
        ),
      ),

      // Subtle dividers
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
        thickness: tokens.borderWidthThin,
      ),

      // Rounded scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        thickness: WidgetStateProperty.all(scrollbarThickness),
        radius: Radius.circular(cornerRadius),
        mainAxisMargin: 2,
        crossAxisMargin: 2,
      ),

      // Rounded inputs with accent focus
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            width: tokens.borderWidthThin,
            color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            width: tokens.borderWidthThin,
            color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            width: tokens.borderWidthMedium,
            color: cs.primary,
          ),
        ),
      ),

      // Rounded chips with subtle border
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.chip.cornerRadius),
          side: BorderSide(
            width: components.chip.borderWidth,
            color: cs.outlineVariant.withValues(alpha: tokens.opacitySubtle),
          ),
        ),
        padding: components.chip.padding,
      ),

      // Standard list tiles
      listTileTheme: ListTileThemeData(
        contentPadding: components.list.contentPadding,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // Floating snackbar with signature shadow
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: tokens.elevationMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.snackBar.cornerRadius),
        ),
      ),

      // Standard toggle controls
      checkboxTheme: CheckboxThemeData(
        side: side,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius - 1),
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: 0.24)
                : null),
      ),
      radioTheme: RadioThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: 0.24)
                : null),
      ),
      switchTheme: SwitchThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? cs.primary.withValues(alpha: 0.24)
                : null),
      ),

      // Standard slider
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.24),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: components.button.iconSize,
        ),
      ),

      // Standard progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: cs.surfaceContainerHighest,
        strokeWidth: components.progress.strokeWidth,
      ),

      // Standard badge
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
        smallSize: components.badge.size * 0.75,
        largeSize: components.badge.size,
      ),

      // Rounded navigation indicator
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(components.navigation.indicatorRadius),
        ),
      ),

      // Rounded popup menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // Standard tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(components.tooltip.cornerRadius),
        ),
        padding: components.tooltip.padding,
      ),

      // Standard text selection
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.3),
        selectionHandleColor: cs.primary,
      ),
    );
  }
}
