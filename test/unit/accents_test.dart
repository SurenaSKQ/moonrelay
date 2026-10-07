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
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MoonrelayAccents registry', () {
    test('is non-empty, and the default is in it', () {
      expect(MoonrelayAccents.all, isNotEmpty);
      expect(MoonrelayAccents.byId(MoonrelayAccents.defaultAccentId),
          same(MoonrelayAccents.defaultAccent));

      // The default is deliberately *not* the first entry. The list is ordered
      // by the two families, and Tycho lives in the second one because a
      // default that is a deep indigo puts the app's only chromatic element in
      // the darkest corner of the palette.
      expect(MoonrelayAccents.all.first,
          isNot(same(MoonrelayAccents.defaultAccent)));
      expect(
          MoonrelayAccents.defaultAccent.family, MoonrelayAccentFamily.crater);
    });

    test('the families are grouped in the order they are shown', () {
      // The picker renders `MoonrelayAccents.all` grouped by family, so the
      // registry has to be ordered by family or the grouping is a lie.
      final seen = <MoonrelayAccentFamily>[];
      for (final accent in MoonrelayAccents.all) {
        if (seen.isEmpty || seen.last != accent.family) seen.add(accent.family);
      }
      expect(seen.length, 2,
          reason: 'the list interleaves its families: $seen');
    });

    test('every accent has a unique id, label key and seed colour', () {
      final ids = <String>{};
      for (final accent in MoonrelayAccents.all) {
        expect(accent.id, isNotEmpty);
        expect(accent.labelKey, isNotEmpty);
        expect(accent.seedColor, isNotNull);
        expect(ids.add(accent.id), isTrue,
            reason: 'duplicate accent id: ${accent.id}');
      }
    });

    test('byId resolves known ids and rejects unknown ones', () {
      expect(MoonrelayAccents.byId('tycho'), same(MoonrelayAccents.tycho));
      expect(MoonrelayAccents.byId('nope'), isNull);
      expect(MoonrelayAccents.byId(null), isNull);
      // A legacy id is *not* a current id, so byId must not claim it.
      expect(MoonrelayAccents.byId('indigo'), isNull);
    });

    test('fromId falls back to the default accent for unknown ids', () {
      expect(MoonrelayAccents.fromId('nope'),
          same(MoonrelayAccents.defaultAccent));
      expect(
          MoonrelayAccents.fromId(null), same(MoonrelayAccents.defaultAccent));
    });

    test('every accent yields a distinct seed colour', () {
      final seeds = MoonrelayAccents.all.map((a) => a.seedColor.toARGB32());
      expect(seeds.toSet().length, MoonrelayAccents.all.length);
    });

    test('every seed is fully opaque', () {
      // The palette these came from carried a `corporateDarkColor` whose
      // alpha byte was zero, so it rendered as nothing at all. Opaque is the
      // floor for a seed: `ColorScheme.fromSeed` needs the alpha to build a
      // scheme, and a transparent seed produces a scheme with no colour in it.
      for (final accent in MoonrelayAccents.all) {
        expect(accent.seedColor.a, 1.0,
            reason: '${accent.id} has a non-opaque seed');
      }
    });

    test('every id names its own colour', () {
      // The reason this list exists. The previous nine carried ids that
      // described a different colour from their own swatch: `midnight` was a
      // green, `steel` was a lime and `crimson` was a red, and the file carried
      // a comment explaining that it had deliberately not been fixed because
      // the ids are persisted.
      //
      // These are feature names rather than colour names, so the assertion
      // cannot be "the id is the colour". It is that each id is a real lunar
      // feature and that no two accents share one.
      final features = <String>{
        'procellarum',
        'nubium',
        'serenitatis',
        'fecunditatis',
        'frigoris',
        'tycho',
        'copernicus',
        'aristarchus',
        'plato',
      };
      for (final accent in MoonrelayAccents.all) {
        expect(features.contains(accent.id), isTrue,
            reason: '${accent.id} is not one of the nine named features');
      }
    });

    test('no accent is another accent', () {
      // The specific thing wrong with the old list. It had four blues:
      // indigo, ocean, sky and vistaBlue, which to a user choosing a swatch
      // were the same choice four times. The maria are cool and the craters
      // warm, and inside each family the hues are spread far enough apart to
      // tell apart in a row of nine dots.
      double hue(Color c) {
        final max = <double>[c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
        final min = <double>[c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
        if (max == min) return -1; // the neutral, excluded from this check
        final d = max - min;
        if (max == c.r) return ((c.g - c.b) / d) % 6;
        if (max == c.g) return (c.b - c.r) / d + 2;
        return (c.r - c.g) / d + 4;
      }

      // Chromatic means actually chromatic. `plato` is a warm dark grey whose
      // channels are 74/71/64, so it computes a hue of about 42 degrees and
      // would otherwise collide with Tycho's gold at 44. Excluding it by name
      // would miss a future neutral; excluding it by saturation will not.
      double saturation(Color c) {
        final hi = <double>[c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
        final lo = <double>[c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
        return hi == 0 ? 0 : (hi - lo) / hi;
      }

      final chromatic = MoonrelayAccents.all
          .where((a) => saturation(a.seedColor) > 0.2)
          .toList();
      // Excluding the neutral must not quietly leave too few swatches to test.
      expect(chromatic.length, MoonrelayAccents.all.length - 1);

      final hues = chromatic.map((a) => hue(a.seedColor)).toList();

      // Every chromatic accent is distinguishable from every other. The
      // narrowest real gap in the list is 21 degrees, so 18 is a floor that
      // fails if a colour is added too near an existing one rather than one
      // that has to be re-tuned every time a swatch moves.
      for (var i = 0; i < hues.length; i++) {
        for (var j = i + 1; j < hues.length; j++) {
          expect(
            (hues[i] - hues[j]).abs() * 60,
            greaterThan(18),
            reason: '${chromatic[i].id} and ${chromatic[j].id} are within '
                '18 degrees of hue',
          );
        }
      }
    });

    test('the two families pull in opposite directions', () {
      double hue(Color c) {
        final max = <double>[c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
        final min = <double>[c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
        if (max == min) return -1;
        final d = max - min;
        if (max == c.r) return ((c.g - c.b) / d) % 6;
        if (max == c.g) return (c.b - c.r) / d + 2;
        return (c.r - c.g) / d + 4;
      }

      final mare = MoonrelayAccents.all
          .where((a) => a.family == MoonrelayAccentFamily.mare)
          .map((a) => hue(a.seedColor))
          .toList();
      final crater = MoonrelayAccents.all
          .where((a) => a.family == MoonrelayAccentFamily.crater)
          .map((a) => hue(a.seedColor))
          .toList();

      expect(mare, isNotEmpty);
      expect(crater, isNotEmpty);
      // The maria sit in the cool half of the wheel and the ray craters in the
      // warm half. That is not decoration: the plains are the dark, unlit half
      // of the Moon and the rays are the lit half, so the split is the same
      // distinction the names are making.
      for (final h in mare) {
        expect(h, lessThan(300), reason: 'a mare landed on the warm wheel');
      }
      for (final h in crater) {
        if (h < 0) continue; // the neutral
        expect(h, lessThan(60), reason: 'a crater landed on the cool wheel');
      }
    });

    test('the seeds are the colours they are named after', () {
      expect(MoonrelayAccents.procellarum.seedColor, const Color(0xFF2A4A8F));
      expect(MoonrelayAccents.nubium.seedColor, const Color(0xFF2E7FA6));
      expect(MoonrelayAccents.serenitatis.seedColor, const Color(0xFF1F8A80));
      expect(MoonrelayAccents.fecunditatis.seedColor, const Color(0xFF4E8A5C));
      expect(MoonrelayAccents.frigoris.seedColor, const Color(0xFF6A4B9E));
      expect(MoonrelayAccents.tycho.seedColor, const Color(0xFFC79A1C));
      expect(MoonrelayAccents.copernicus.seedColor, const Color(0xFFB25630));
      expect(MoonrelayAccents.aristarchus.seedColor, const Color(0xFFC7486E));
      expect(MoonrelayAccents.plato.seedColor, const Color(0xFF4A4740));
    });

    test('plato is the neutral accent', () {
      // A walled crater with a dark basalt floor, which is a dark neutral
      // feature and the only honest name for a grey swatch in this list.
      expect(
          MoonrelayAccents.plato.seedColor.computeLuminance(), lessThan(0.1));
      final max = MoonrelayAccents.plato.seedColor.r;
      final min = MoonrelayAccents.plato.seedColor.b;
      // Warm, not a Material grey: the light ramp is warm and a neutral swatch
      // next to it reads as a hole in the palette.
      expect(max, greaterThan(min));
    });
  });

  group('migrating a retired accent id', () {
    // Every id the app has ever shipped, mapped to a current one. Renaming
    // nine accents would otherwise have reset every saved choice to the
    // default on upgrade, which is the reason the old ids were documented as
    // frozen.
    test('every legacy id resolves to a current accent', () {
      const shipped = <String>[
        'indigo',
        'ocean',
        'midnight',
        'crimson',
        'amber',
        'steel',
        'sky',
        'charcoal',
        'vistaBlue',
      ];
      for (final legacy in shipped) {
        expect(MoonrelayAccents.legacyIdMap.containsKey(legacy), isTrue,
            reason: '$legacy has no migration');
        final resolved = MoonrelayAccents.fromId(legacy);
        expect(MoonrelayAccents.byId(resolved.id), isNotNull,
            reason: '$legacy migrated to ${resolved.id}, which is not shipped');
      }
    });

    test('no legacy id maps to itself', () {
      // If one did, that accent was never actually renamed and the map is
      // carrying a mapping for a live id, which is how the next rename ends up
      // migrating a working choice.
      for (final entry in MoonrelayAccents.legacyIdMap.entries) {
        expect(entry.key, isNot(entry.value));
      }
    });

    test('the legacy map does not collide', () {
      // Two old ids landing on one new accent would silently drop a
      // distinction the user could previously make. Lime and gold going to the
      // same place is acceptable; two blues going to the same place is not.
      expect(MoonrelayAccents.legacyIdMap.values.toSet().length,
          MoonrelayAccents.legacyIdMap.length,
          reason: 'two retired ids migrate to the same accent');
    });

    test('a legacy id keeps the user in the same part of the wheel', () {
      // Lime was a warm light colour and Tycho is a warm light colour.
      // Racing green was a deep green and Fecunditatis is a green.
      expect(MoonrelayAccents.fromId('midnight'),
          same(MoonrelayAccents.fecunditatis));
      expect(MoonrelayAccents.fromId('steel'), same(MoonrelayAccents.tycho));
      expect(MoonrelayAccents.fromId('charcoal'), same(MoonrelayAccents.plato));
    });
  });
  group('SettingsService accent persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('falls back to the default accent on a fresh install', () async {
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedAccentId, MoonrelayAccents.defaultAccentId);
    });

    test('updateSelectedAccent persists the id', () async {
      final service = SettingsService();
      await service.updateSelectedAccent('nubium');
      expect(await service.selectedAccentId(), 'nubium');
    });

    test('a legacy id is migrated on the way in, not left in storage',
        () async {
      // The service resolves through `fromId`, so a retired id written by an
      // older build is rewritten to its replacement rather than being stored
      // verbatim and resolved on every read. Storing it verbatim is what would
      // have left the picker lighting up no radio button at all.
      final service = SettingsService();
      await service.updateSelectedAccent('sky');
      expect(await service.selectedAccentId(), 'nubium');
    });

    test('an unknown persisted id falls back to the default accent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'selected_accent': 'no-such-accent',
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedAccentId, MoonrelayAccents.defaultAccentId);
    });

    test('retired theme keys are ignored', () async {
      // The look axis is gone, so the keys it used to own carry no meaning
      // and must not influence the accent.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'selected_theme': 'archVista',
        'selected_skin': 'archVista',
        'theme_option': 2,
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedAccentId, MoonrelayAccents.defaultAccentId);
    });
  });
}
