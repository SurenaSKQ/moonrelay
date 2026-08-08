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
  });
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
  /// comfortable density. The signature air-force-blue accent (#5C8AA6) is a
  /// separate [MoonrelayAccents.vistaBlue] so it can be swapped independently.
  static const MoonrelayThemeSpec archVista = MoonrelayThemeSpec(
    id: 'archVista',
    label: 'ArchVista',
    description: 'Darkened Windows Vista UI.',
    defaultFontFamily: 'Segoe UI',
    defaultMonoFontFamily: 'Consolas',
    cornerRadius: 4.0,
    defaultBubbleRadius: 10.0,
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
