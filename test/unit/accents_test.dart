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
    test('is non-empty and ships the default accent first', () {
      expect(MoonrelayAccents.all, isNotEmpty);
      expect(MoonrelayAccents.all.first, same(MoonrelayAccents.defaultAccent));
      expect(
          MoonrelayAccents.defaultAccentId, MoonrelayAccents.defaultAccent.id);
    });

    test('every accent has a unique id, label and seed colour', () {
      final ids = <String>{};
      for (final accent in MoonrelayAccents.all) {
        expect(accent.id, isNotEmpty);
        expect(accent.label, isNotEmpty);
        expect(accent.seedColor, isNotNull);
        expect(ids.add(accent.id), isTrue,
            reason: 'duplicate accent id: ${accent.id}');
      }
    });

    test('byId resolves known ids and rejects unknown ones', () {
      expect(
          MoonrelayAccents.byId('vistaBlue'), same(MoonrelayAccents.vistaBlue));
      expect(MoonrelayAccents.byId('nope'), isNull);
      expect(MoonrelayAccents.byId(null), isNull);
    });

    test('fromId falls back to the default accent for unknown ids', () {
      expect(MoonrelayAccents.fromId('nope'),
          same(MoonrelayAccents.defaultAccent));
      expect(MoonrelayAccents.fromId(null),
          same(MoonrelayAccents.defaultAccent));
    });

    test('every accent yields a distinct seed colour', () {
      final seeds = MoonrelayAccents.all.map((a) => a.seedColor.toARGB32());
      expect(seeds.toSet().length, MoonrelayAccents.all.length);
    });

    test('every seed is fully opaque', () {
      // The palette these came from carried a `corporateDarkColor` whose
      // alpha byte was zero, so it rendered as nothing at all. Opaque is the
      // floor for a seed: ColorScheme.fromSeed needs the alpha to build a
      // scheme, and a transparent seed would produce a scheme with no colour
      // in it. Worth asserting now that the seeds are inlined.
      for (final accent in MoonrelayAccents.all) {
        expect(accent.seedColor.a, 1.0,
            reason: '${accent.id} has a non-opaque seed');
      }
    });

    test('every label names its own colour', () {
      // The ids are frozen because they are persisted, and three of them
      // misdescribe their colour: `midnight` is a green, `steel` is a lime
      // and `crimson` is a red. The label is the only part a user reads, so
      // it has to be the honest one.
      final expected = <String, String>{
        'indigo': 'Indigo',
        'ocean': 'Ocean Blue',
        'midnight': 'British Racing Green',
        'crimson': 'Crimson',
        'amber': 'Orange',
        'steel': 'Lime Green',
        'sky': 'Sky',
        'charcoal': 'Charcoal',
        'vistaBlue': 'Vista Blue',
      };
      for (final accent in MoonrelayAccents.all) {
        expect(accent.label, expected[accent.id],
            reason: '${accent.id} has an unexpected label');
      }
      expect(expected.keys.toSet(),
          MoonrelayAccents.all.map((a) => a.id).toSet(),
          reason: 'a shipped accent is missing from this table');
    });

    test('the seeds are the colours they are named after', () {
      expect(MoonrelayAccents.ocean.seedColor, const Color(0xFF0D47A1));
      expect(MoonrelayAccents.midnight.seedColor, const Color(0xFF004225));
      expect(MoonrelayAccents.crimson.seedColor, const Color(0xFFC32148));
      expect(MoonrelayAccents.amber.seedColor, const Color(0xFFFF9800));
      expect(MoonrelayAccents.steel.seedColor, const Color(0xFFCDDC39));
      expect(MoonrelayAccents.sky.seedColor, const Color(0xFF58A6FF));
      expect(MoonrelayAccents.charcoal.seedColor, const Color(0xFF212121));
    });

    test('vistaBlue captures the air-force blue (#5C8AA6)', () {
      expect(MoonrelayAccents.vistaBlue.seedColor, const Color(0xFF5C8AA6));
    });

    test('charcoal is the neutral accent', () {
      expect(MoonrelayAccents.charcoal.seedColor,
          MoonrelayAccentSeeds.nearBlack);
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
      await service.updateSelectedAccent('sky');
      expect(await service.selectedAccentId(), 'sky');
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
