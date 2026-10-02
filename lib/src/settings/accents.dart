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

/// The seed colours the shipped accents are built from.
///
/// These used to live in lib/src/helpers/color_palette.dart, a reference
/// palette copied from elsewhere with eight unused swatches, four wrapper
/// methods and two comments that grouped the wrong colours together. None of
/// that was reachable: the palette's only consumer was this file, asking for
/// seven constants. They are inlined here so each accent can state the colour
/// it actually is, which is the only fact a user or a maintainer needs.
abstract final class MoonrelayAccentSeeds {
  /// Material blue 900.
  static const Color oceanBlue = Color(0xFF0D47A1);

  /// The green of British racing paint.
  static const Color racingGreen = Color(0xFF004225);

  /// A deep raspberry red.
  static const Color raspberry = Color(0xFFC32148);

  /// Material orange 500.
  static const Color orange = Color(0xFFFF9800);

  /// Material lime 500.
  static const Color lime = Color(0xFFCDDC39);

  /// Material blue 400.
  static const Color skyBlue = Color(0xFF58A6FF);

  /// Material grey 900.
  static const Color nearBlack = Color(0xFF212121);
}

/// A swappable colour accent for the app.
///
/// An accent owns the hue and nothing else: its [seedColor] drives the
/// Material 3 color scheme built by `MoonrelayTheme`. Switching accents
/// recolours the widgets but never changes their shape, spacing or density.
@immutable
class MoonrelayAccent {
  /// Stable machine id persisted in settings.
  ///
  /// **Frozen.** These strings are written to `SharedPreferences` on the
  /// user's machine, so renaming one silently resets their choice to the
  /// default. Three of them also do not describe their own colour
  /// ([MoonrelayAccents.midnight] is a green, [MoonrelayAccents.steel] is a
  /// lime, [MoonrelayAccents.crimson] is a red). The labels were corrected to
  /// name what the colours actually are instead; the ids were left alone
  /// because the cost of fixing them is a user-visible reset and the cost of
  /// leaving them is a misleading identifier nobody reads.
  final String id;

  /// Human-readable name shown in the accent picker. This is the only part
  /// of an accent a user ever sees.
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
///
/// Add an accent here and it automatically appears in the settings picker and
/// is accepted by [MoonrelayAccents.byId] / [MoonrelayAccents.fromId]. The
/// first entry is the default.
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
    seedColor: MoonrelayAccentSeeds.oceanBlue,
  );

  /// Racing green (#004225). The id is historical; see [MoonrelayAccent.id].
  static const MoonrelayAccent midnight = MoonrelayAccent(
    id: 'midnight',
    label: 'British Racing Green',
    seedColor: MoonrelayAccentSeeds.racingGreen,
  );

  /// Deep raspberry red (#C32148). The id is historical; see
  /// [MoonrelayAccent.id].
  static const MoonrelayAccent crimson = MoonrelayAccent(
    id: 'crimson',
    label: 'Crimson',
    seedColor: MoonrelayAccentSeeds.raspberry,
  );

  /// Material orange 500 (#FF9800). The id is close enough to read; see
  /// [MoonrelayAccent.id].
  static const MoonrelayAccent amber = MoonrelayAccent(
    id: 'amber',
    label: 'Orange',
    seedColor: MoonrelayAccentSeeds.orange,
  );

  /// Material lime 500 (#CDDC39). The id is historical; see
  /// [MoonrelayAccent.id].
  static const MoonrelayAccent steel = MoonrelayAccent(
    id: 'steel',
    label: 'Lime Green',
    seedColor: MoonrelayAccentSeeds.lime,
  );

  static const MoonrelayAccent sky = MoonrelayAccent(
    id: 'sky',
    label: 'Sky',
    seedColor: MoonrelayAccentSeeds.skyBlue,
  );

  /// Neutral accent for users who want the app to stay grey.
  static const MoonrelayAccent charcoal = MoonrelayAccent(
    id: 'charcoal',
    label: 'Charcoal',
    seedColor: MoonrelayAccentSeeds.nearBlack,
  );

  /// A desaturated air-force blue (#5C8AA6).
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
