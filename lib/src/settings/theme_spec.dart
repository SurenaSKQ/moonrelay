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

  // ── Shipped themes ───────────────────────────────────────────────────

  /// The bundled themes, in their persisted/display order. The first entry is
  /// [MoonrelayThemes.defaultTheme].
  static const List<MoonrelayThemeSpec> all = <MoonrelayThemeSpec>[
    material,
    highContrast,
    compact,
    archVista,
  ];

  /// The default Material 3 look shared by most accent colours.
  static const MoonrelayThemeSpec material = MoonrelayThemeSpec(
    id: 'material',
    label: 'Material',
    description: 'Smooth Material 3 surfaces.',
  );

  /// Sharp-cornered, elevated variant for clarity on large screens.
  static const MoonrelayThemeSpec highContrast = MoonrelayThemeSpec(
    id: 'highContrast',
    label: 'High Contrast',
    description: 'Sharp corners and elevated surfaces.',
    cornerRadius: 0.0,
    surfaceElevation: 0.5,
  );

  /// Tighter, smaller-cornered variant for dense workspaces.
  static const MoonrelayThemeSpec compact = MoonrelayThemeSpec(
    id: 'compact',
    label: 'Compact Modern',
    description: 'Slim corners and a compact layout.',
    cornerRadius: 6.0,
    defaultDensity: LayoutDensity.compact,
  );

  /// "Darkened Windows Vista UI" look: near-square corners, Sego UI font and a
  /// comfortable density, plus a [MoonrelayWidgetStyle.vista] that re-styles
  /// buttons, checkboxes, scrollbars and dividers with Vista's flat, bordered
  /// chrome. The signature air-force-blue accent (#5C8AA6) is a separate
  /// [MoonrelayAccents.vistaBlue] so it can be swapped independently.
  static const MoonrelayThemeSpec archVista = MoonrelayThemeSpec(
    id: 'archVista',
    label: 'ArchVista',
    description: 'Darkened Windows Vista UI.',
    defaultFontFamily: 'Segoe UI',
    defaultMonoFontFamily: 'Consolas',
    cornerRadius: 4.0,
    defaultDensity: LayoutDensity.comfortable,
    defaultBubbleRadius: 10.0,
    widgetStyle: MoonrelayWidgetStyle.vista,
  );

  // ── Defaults ────────────────────────────────────────────────────────

  /// The theme used on first install and when an unknown id is requested.
  static const MoonrelayThemeSpec defaultTheme = material;

  /// Stable machine id of [defaultTheme].
  static const String defaultThemeId = 'material';

  // ── Lookup ──────────────────────────────────────────────────────────

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

  // ── Shipped accents ──────────────────────────────────────────────────

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

  // ── Defaults ────────────────────────────────────────────────────────

  /// The accent used on first install and when an unknown id is requested.
  static const MoonrelayAccent defaultAccent = indigo;

  /// Stable machine id of [defaultAccent].
  static const String defaultAccentId = 'indigo';

  // ── Lookup ──────────────────────────────────────────────────────────

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

/// A theme's widget geometry — the bits of "feel" that a color accent cannot
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
    required this.cornerRadius,
    required this.borderWidth,
    required this.borderAlpha,
    required this.buttonMinHeight,
    required this.sliderThumbRadius,
    required this.scrollbarThickness,
  });

  /// The Vista look: flat buttons with a thin outline, square-ish corners,
  /// a narrow scrollbar and the thin divider line characteristic of the GTK
  /// theme. Colours are derived from the running color scheme, so this same
  /// style works with any accent.
  static const MoonrelayWidgetStyle vista = MoonrelayWidgetStyle(
    cornerRadius: 4.0,
    borderWidth: 1.0,
    borderAlpha: 0.5,
    buttonMinHeight: 28.0,
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
    final border = _borderColor(cs);
    final radius = BorderRadius.circular(cornerRadius);
    final innerRadius = BorderRadius.circular(cornerRadius - 1);
    final side = BorderSide(width: borderWidth, color: border);

    return base.copyWith(
      // ── Buttons ───────────────────────────────────────────────────
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

      // ── Toggle controls ───────────────────────────────────────────
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

      // ── Slider ────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.24),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: components.button.iconSize,
        ),
      ),

      // ── Scrollbar ─────────────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        thickness: WidgetStateProperty.all(scrollbarThickness),
        radius: Radius.circular(cornerRadius - 1),
        mainAxisMargin: 2,
        crossAxisMargin: 2,
      ),

      // ── Surfaces ──────────────────────────────────────────────────
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

      // ── Inputs ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius, borderSide: side),
        enabledBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: side),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(width: borderWidth, color: cs.primary),
        ),
      ),

      // ── Dividers ──────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: border, thickness: borderWidth),

      // ── AppBar ────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: border, width: borderWidth)),
        titleTextStyle: base.appBarTheme.titleTextStyle,
      ),

      // ── List tiles ────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: components.list.contentPadding,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // ── SnackBar ──────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(components.snackBar.cornerRadius),
        ),
      ),

      // ── Progress indicators ───────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: cs.surfaceContainerHighest,
        strokeWidth: components.progress.strokeWidth,
      ),

      // ── Chips ─────────────────────────────────────────────────────
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

      // ── Tooltips ──────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(components.tooltip.cornerRadius),
        ),
        padding: components.tooltip.padding,
      ),

      // ── Navigation ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(components.navigation.indicatorRadius),
        ),
      ),

      // ── Popup menu ────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),

      // ── Badge ─────────────────────────────────────────────────────
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
        smallSize: components.badge.size * 0.75,
        largeSize: components.badge.size,
      ),

      // ── Text selection ────────────────────────────────────────────
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withValues(alpha: 0.3),
        selectionHandleColor: cs.primary,
      ),
    );
  }
}
