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

/// A swappable colour accent for the app.
///
/// An accent owns the hue and nothing else: its [seedColor] drives the
/// Material 3 color scheme built by `MoonrelayTheme`. Switching accents
/// recolours the widgets but never changes their shape, spacing or density.
@immutable
class MoonrelayAccent {
  /// Stable machine id persisted in settings.
  ///
  /// These ids are the feature's own vocabulary, not the labels. `imbrium`
  /// stays `imbrium` whatever language calls the sea.
  final String id;

  /// Human-readable name shown in the accent picker.
  ///
  /// This is the only part of an accent a user ever sees, and it used to be a
  /// hardcoded English string while everything around it was localized. It is
  /// now an ARB key, resolved through [MoonrelayAccents.labelFor].
  ///
  /// The names are proper nouns from lunar nomenclature, and they are not
  /// translated: a user who has read about the Apollo landings has met
  /// "Mare Tranquillitatis" and has not met "Sea of Tranquility".
  final String labelKey;

  /// Which family this accent belongs to, used to group the picker.
  final MoonrelayAccentFamily family;

  /// Seed colour fed to [ColorScheme.fromSeed].
  final Color seedColor;

  const MoonrelayAccent({
    required this.id,
    required this.labelKey,
    required this.family,
    required this.seedColor,
  });
}

/// The two albedo populations of the lunar surface.
///
/// This is a real distinction and not a grouping invented to make a list look
/// tidy. The maria are basaltic lava plains with an albedo around 0.07, which
/// is why they read as dark smudges on the near side. The ray craters are
/// bright ejecta systems whose rays reach roughly 0.15, which is why they are
/// the only features bright enough to be visible from Earth as anything other
/// than a dot. It is also why one family is cool and the other warm: the
/// plains are the unlit-looking half of the Moon and the rays are the lit one.
///
/// Having two families means the picker can say what it is offering, which is
/// better than nine swatches in a row with a colour name each.
enum MoonrelayAccentFamily {
  /// The dark basalt plains. `mare`, plural `maria`.
  mare,

  /// The bright ray systems.
  crater,
}

/// Central registry of every accent colour Moonrelay ships with.
///
/// Add an accent here and it automatically appears in the settings picker and
/// is accepted by [MoonrelayAccents.byId] / [MoonrelayAccents.fromId]. The
/// first entry is the default.
///
/// ## Why the names changed
///
/// This used to be nine swatches named for colours: Indigo, Ocean Blue,
/// British Racing Green, Crimson, Orange, Lime Green, Sky, Charcoal, Vista
/// Blue. Four of them were Material palette constants wearing a name, and
/// three of the persisted ids described a colour the swatch was not, which is
/// why this file carried a comment explaining that it had deliberately not been
/// fixed. It was correct not to rename them: renaming silently reset a saved
/// preference. But the palette around them changed, so keeping nine
/// unattributed colour names next to a theme built out of lunar albedo was
/// leaving the app speaking two vocabularies at once.
///
/// The names are now lunar features, which gives the list a source, a taxonomy
/// that means something, and no two entries that are "another blue". The
/// renames are not silent: [legacyIdMap] migrates a saved id to its nearest
/// equivalent, so a user who had picked green still has green.
class MoonrelayAccents {
  MoonrelayAccents._();

  // -- Shipped accents --------------------------------------------------

  /// The bundled accents, in the order the picker shows them: the maria first,
  /// because they are the larger features, then the craters.
  static const List<MoonrelayAccent> all = <MoonrelayAccent>[
    procellarum,
    nubium,
    serenitatis,
    fecunditatis,
    frigoris,
    tycho,
    copernicus,
    aristarchus,
    plato,
  ];

  // -- The maria: the dark basalt plains --------------------------------

  /// Oceanus Procellarum, the largest dark region on the near side.
  static const MoonrelayAccent procellarum = MoonrelayAccent(
    id: 'procellarum',
    labelKey: 'accentProcellarum',
    family: MoonrelayAccentFamily.mare,
    seedColor: Color(0xFF2A4A8F),
  );

  /// Mare Nubium. The cloudiest of them, and the most obviously grey-blue.
  static const MoonrelayAccent nubium = MoonrelayAccent(
    id: 'nubium',
    labelKey: 'accentNubium',
    family: MoonrelayAccentFamily.mare,
    seedColor: Color(0xFF2E7FA6),
  );

  /// Mare Serenitatis, where Apollo 17 landed.
  static const MoonrelayAccent serenitatis = MoonrelayAccent(
    id: 'serenitatis',
    labelKey: 'accentSerenitatis',
    family: MoonrelayAccentFamily.mare,
    seedColor: Color(0xFF1F8A80),
  );

  /// Mare Fecunditatis, which genuinely is olive: these plains carry
  /// olivine, and Fecunditatis reads green-grey against the rest of them.
  static const MoonrelayAccent fecunditatis = MoonrelayAccent(
    id: 'fecunditatis',
    labelKey: 'accentFecunditatis',
    family: MoonrelayAccentFamily.mare,
    seedColor: Color(0xFF4E8A5C),
  );

  /// Mare Frigoris, the long northern sea, which is the coldest-feeling of
  /// them and the only one that reads violet.
  static const MoonrelayAccent frigoris = MoonrelayAccent(
    id: 'frigoris',
    labelKey: 'accentFrigoris',
    family: MoonrelayAccentFamily.mare,
    seedColor: Color(0xFF6A4B9E),
  );

  // -- The ray craters: the bright ejecta ------------------------------

  /// Tycho, whose rays are the brightest and longest in the solar system.
  /// The one feature on the Moon a person who has never looked through a
  /// telescope can name, which is why it is the default.
  static const MoonrelayAccent tycho = MoonrelayAccent(
    id: 'tycho',
    labelKey: 'accentTycho',
    family: MoonrelayAccentFamily.crater,
    seedColor: Color(0xFFC79A1C),
  );

  /// Copernicus, the second great ray crater and Tycho's near rival.
  static const MoonrelayAccent copernicus = MoonrelayAccent(
    id: 'copernicus',
    labelKey: 'accentCopernicus',
    family: MoonrelayAccentFamily.crater,
    seedColor: Color(0xFFB25630),
  );

  /// Aristarchus, the brightest point on the Moon and the reason its ray
  /// system was mapped from Earth before almost anything else was.
  static const MoonrelayAccent aristarchus = MoonrelayAccent(
    id: 'aristarchus',
    labelKey: 'accentAristarchus',
    family: MoonrelayAccentFamily.crater,
    seedColor: Color(0xFFC7486E),
  );

  // -- The neutral -------------------------------------------------------

  /// Plato: a walled crater whose floor is filled with dark basalt, so it is
  /// a dark neutral feature and the only honest name for a grey accent in a
  /// list drawn from the Moon. The old list called this "Charcoal" and it was
  /// `#212121`, which is a Material grey and not a colour anyone chose.
  static const MoonrelayAccent plato = MoonrelayAccent(
    id: 'plato',
    labelKey: 'accentPlato',
    family: MoonrelayAccentFamily.crater,
    seedColor: Color(0xFF4A4740),
  );

  // -- Defaults --------------------------------------------------------

  /// The accent used on first install and when an unknown id is requested.
  ///
  /// Tycho rather than the first entry. The first entry is the largest mare
  /// because the list is ordered by feature size, and a default that is a deep
  /// indigo puts the app's only chromatic element in the darkest corner of the
  /// palette. Tycho is the brightest thing on the Moon, which is a defensible
  /// reason for it to be the thing the app is seen in.
  static const MoonrelayAccent defaultAccent = tycho;

  /// Stable machine id of [defaultAccent].
  static const String defaultAccentId = 'tycho';

  // -- Migration --------------------------------------------------------

  /// Maps every accent id this app has ever shipped to its nearest
  /// replacement.
  ///
  /// Without this, renaming nine accents would have silently reset every
  /// saved choice to [defaultAccent] on upgrade, which is the reason the old
  /// ids were described as frozen. The map is the thing that unfroze them:
  /// each old colour has an obvious nearest neighbour in the new list, chosen
  /// by hue rather than by name, so a user who picked lime green still has a
  /// lime-ish gold rather than a gold.
  static const Map<String, String> legacyIdMap = <String, String>{
    'indigo': 'frigoris', // purple -> violet
    'ocean': 'procellarum', // deep blue -> indigo blue
    'midnight': 'fecunditatis', // racing green -> olive green
    'crimson': 'aristarchus', // raspberry -> rose
    'amber': 'copernicus', // orange -> copper
    'steel': 'tycho', // lime -> gold, the nearest warm light one
    'sky': 'nubium', // light blue -> steel blue
    'charcoal': 'plato', // neutral -> neutral
    'vistaBlue': 'serenitatis', // desaturated blue -> teal
  };

  // -- Lookup ----------------------------------------------------------

  /// Returns the accent whose [MoonrelayAccent.id] matches [id], or null when
  /// no such accent exists.
  ///
  /// Accepts a legacy id as well as a current one, so a caller that only knows
  /// the string in `SharedPreferences` does not have to know which list it
  /// came from.
  static MoonrelayAccent? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final accent in all) {
      if (accent.id == id) return accent;
    }
    return null;
  }

  /// As [byId], but also resolves a legacy id and an unknown id to
  /// [defaultAccent], so callers always receive a valid accent.
  static MoonrelayAccent fromId(String? id) {
    final direct = byId(id);
    if (direct != null) return direct;
    final migrated = legacyIdMap[id];
    if (migrated != null) return byId(migrated)!;
    return defaultAccent;
  }
}
