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

/// A complete, self-contained "look and feel" recipe for Moonrelay.
///
/// A skin owns every visual token that defines the app's *appearance*: the
/// seed colour (drives the Material 3 tonal palette), the default font
/// families, the default layout [LayoutDensity], the corner radius applied to
/// cards and surfaces, and the default elevation of those surfaces. Together
/// these fully determine what the app *looks like*, independent of per-user
/// readability fine-tunes (font size, UI scale) that layer on top.
///
/// Swapping the active skin [SettingsController.updateSelectedSkin] resets the
/// independent appearance controls to the skin's defaults and rebuilds the
/// [ThemeData], so switching skins changes the entire look and feel in one
/// action. New skins can be added by appending to [MoonrelaySkins.all]; no
/// other call site needs to change.
@immutable
class MoonrelaySkin {
  /// Stable machine id persisted in settings and used for migration.
  final String id;

  /// Human-readable name shown in the skin picker. English only; matches the
  /// convention used by [LayoutDensity], [DisplayType], etc.
  final String label;

  /// Short sentence describing the skin's character, shown as a subtitle.
  final String description;

  /// Seed colour fed to [ColorScheme.fromSeed].
  final Color seedColor;

  /// Default application font family for this skin.
  final String defaultFontFamily;

  /// Default monospace font family for this skin (code blocks, event IDs).
  final String defaultMonoFontFamily;

  /// Default [LayoutDensity] applied when this skin is selected.
  final LayoutDensity defaultDensity;

  /// Border radius applied to cards, dialogs and other Material surfaces.
  final double cornerRadius;

  /// Elevation applied to cards and tonal surfaces.
  final double surfaceElevation;

  /// Default corner radius for chat message bubbles.
  final double defaultBubbleRadius;

  const MoonrelaySkin({
    required this.id,
    required this.label,
    required this.description,
    required this.seedColor,
    this.defaultFontFamily = 'Rubik',
    this.defaultMonoFontFamily = 'FiraCode',
    this.defaultDensity = LayoutDensity.comfortable,
    this.cornerRadius = 12.0,
    this.surfaceElevation = 0.0,
    this.defaultBubbleRadius = 12.0,
  });
}

/// Central registry of every skin Moonrelay ships with.
///
/// Add a skin here and it automatically appears in the settings picker and is
/// accepted by [MoonrelaySkins.byId] / [MoonrelaySkins.fromId]. The first entry
/// is the default.
class MoonrelaySkins {
  MoonrelaySkins._();

  // ── Shipped skins ───────────────────────────────────────────────────

  /// The bundled skins, in their persisted/display order. The first entry is
  /// [MoonrelaySkins.defaultSkin].
  static const List<MoonrelaySkin> all = <MoonrelaySkin>[
    indigo,
    ocean,
    midnight,
    crimson,
    amber,
    steel,
    sky,
    highContrast,
    compact,
  ];

  static const MoonrelaySkin indigo = MoonrelaySkin(
    id: 'indigo',
    label: 'Default (Indigo)',
    description: 'Moonrelay classic: deep indigo tones.',
    seedColor: Colors.indigo,
  );

  static const MoonrelaySkin ocean = MoonrelaySkin(
    id: 'ocean',
    label: 'Ocean Blue',
    description: 'Cool oceanic blues.',
    seedColor: MoonrelayColorPalette.ordinaryBlue,
  );

  static const MoonrelaySkin midnight = MoonrelaySkin(
    id: 'midnight',
    label: 'British Racing Green',
    description: 'Rich, dark green racing heritage.',
    seedColor: MoonrelayColorPalette.britishRacingGreen,
  );

  static const MoonrelaySkin crimson = MoonrelaySkin(
    id: 'crimson',
    label: 'Bright Maroon',
    description: 'Bold maroon throughout.',
    seedColor: MoonrelayColorPalette.brightMaroon,
  );

  static const MoonrelaySkin amber = MoonrelaySkin(
    id: 'amber',
    label: 'Amber',
    description: 'Warm amber highlights.',
    seedColor: MoonrelayColorPalette.ordinaryOrange,
  );

  static const MoonrelaySkin steel = MoonrelaySkin(
    id: 'steel',
    label: 'Lime Green',
    description: 'Sharp steel with a lime accent.',
    seedColor: MoonrelayColorPalette.ordinaryLimeGreen,
  );

  static const MoonrelaySkin sky = MoonrelaySkin(
    id: 'sky',
    label: 'Sky',
    description: 'Breezy sky-blues.',
    seedColor: MoonrelayColorPalette.accentColor,
  );

  /// High-contrast, sharp-cornered variant for clarity on large screens.
  static const MoonrelaySkin highContrast = MoonrelaySkin(
    id: 'highContrast',
    label: 'High Contrast',
    description: 'Sharp corners and elevated surfaces.',
    seedColor: MoonrelayColorPalette.ordinaryDarkGrey,
    cornerRadius: 0.0,
    surfaceElevation: 0.5,
  );

  /// Tighter, smaller-cornered variant for dense workspaces.
  static const MoonrelaySkin compact = MoonrelaySkin(
    id: 'compact',
    label: 'Compact Modern',
    description: 'Slim corners and a compact layout.',
    seedColor: MoonrelayColorPalette.ordinaryBlue,
    cornerRadius: 6.0,
    defaultDensity: LayoutDensity.compact,
  );

  // ── Defaults ────────────────────────────────────────────────────────

  /// The skin used on first install and when an unknown id is requested.
  static const MoonrelaySkin defaultSkin = indigo;

  /// Stable machine id of [defaultSkin].
  static const String defaultSkinId = 'indigo';

  // ── Lookup ────────────────────────────────────────────────────────

  /// Returns the skin whose [MoonrelaySkin.id] matches [id], or null when no
  /// such skin exists.
  static MoonrelaySkin? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final skin in all) {
      if (skin.id == id) return skin;
    }
    return null;
  }

  /// Returns [byId] or [defaultSkin] when [id] is unknown, so callers always
  /// receive a valid skin.
  static MoonrelaySkin fromId(String? id) => byId(id) ?? defaultSkin;
}
