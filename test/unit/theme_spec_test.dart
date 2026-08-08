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
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MoonrelayThemes registry', () {
    test('is non-empty and ships the default theme first', () {
      expect(MoonrelayThemes.all, isNotEmpty);
      expect(MoonrelayThemes.all.first, same(MoonrelayThemes.defaultTheme));
      expect(MoonrelayThemes.defaultThemeId,
          MoonrelayThemes.defaultTheme.id);
    });

    test('every theme has a unique id, a label and a seed-free geometry', () {
      final ids = <String>{};
      for (final theme in MoonrelayThemes.all) {
        expect(theme.id, isNotEmpty);
        expect(theme.label, isNotEmpty);
        expect(theme.defaultDensity, isNotNull);
        expect(theme.cornerRadius, greaterThanOrEqualTo(0));
        expect(ids.add(theme.id), isTrue,
            reason: 'duplicate theme id: ${theme.id}');
      }
    });

    test('byId resolves known ids and rejects unknown ones', () {
      expect(MoonrelayThemes.byId('compact'), same(MoonrelayThemes.compact));
      expect(MoonrelayThemes.byId('nope'), isNull);
      expect(MoonrelayThemes.byId(null), isNull);
    });

    test('fromId falls back to the default theme for unknown ids', () {
      expect(MoonrelayThemes.fromId('nope'), same(MoonrelayThemes.defaultTheme));
      expect(MoonrelayThemes.fromId(null), same(MoonrelayThemes.defaultTheme));
    });

    test('the compact theme is tighter than the default material theme', () {
      expect(MoonrelayThemes.compact.defaultDensity, LayoutDensity.compact);
      expect(MoonrelayThemes.compact.cornerRadius,
          lessThan(MoonrelayThemes.defaultTheme.cornerRadius));
    });

    test('the archVista theme uses Vista fonts and sharp corners', () {
      const spec = MoonrelayThemes.archVista;
      expect(spec.defaultFontFamily, 'Segoe UI');
      expect(spec.defaultMonoFontFamily, 'Consolas');
      expect(spec.cornerRadius, 4.0);
      expect(spec.defaultDensity, LayoutDensity.comfortable);
    });
  });

  group('MoonrelayAccents registry', () {
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

    test('byId/fromId resolve and fall back like the themes registry', () {
      expect(MoonrelayAccents.byId('vistaBlue'),
          same(MoonrelayAccents.vistaBlue));
      expect(MoonrelayAccents.fromId('nope'),
          same(MoonrelayAccents.defaultAccent));
    });

    test('vistaBlue captures ArchVista GTK accent (#5C8AA6)', () {
      expect(MoonrelayAccents.vistaBlue.seedColor,
          const Color(0xFF5C8AA6));
    });

    test('charcoal is the high-contrast neutral', () {
      expect(MoonrelayAccents.charcoal.seedColor,
          MoonrelayColorPalette.ordinaryDarkGrey);
    });
  });

  group('SettingsService theme+accent migration', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('falls back to defaults on a fresh install', () async {
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedThemeId, MoonrelayThemes.defaultThemeId);
      expect(snapshot.selectedAccentId, MoonrelayAccents.defaultAccentId);
    });

    test('migrates the legacy theme_option index to an accent', () async {
      // Legacy enum order: 0 indigo, 1 oceanBlue, 2 midnightSlate, ...
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 2,
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedThemeId, MoonrelayThemes.material.id);
      expect(snapshot.selectedAccentId, 'midnight');
    });

    test('clamps out-of-range legacy indices to the defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 999,
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedThemeId, MoonrelayThemes.defaultThemeId);
      expect(snapshot.selectedAccentId, MoonrelayAccents.defaultAccentId);
    });

    test('selected_skin takes precedence over the legacy theme_option', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 5,
        'selected_skin': 'compact',
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedThemeId, MoonrelayThemes.compact.id);
      expect(snapshot.selectedAccentId, 'ocean');
    });

    test('selected_theme + selected_accent take top precedence', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 1,
        'selected_skin': 'indigo',
        'selected_theme': 'archVista',
        'selected_accent': 'vistaBlue',
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedThemeId, MoonrelayThemes.archVista.id);
      expect(snapshot.selectedAccentId, MoonrelayAccents.vistaBlue.id);
    });

    test('updateSelectedAccent persists the id', () async {
      final service = SettingsService();
      await service.updateSelectedAccent('sky');
      expect(await service.selectedAccentId(), 'sky');
    });

    test('updateSelectedTheme persists the id', () async {
      final service = SettingsService();
      await service.updateSelectedTheme('compact');
      expect(await service.selectedThemeId(), 'compact');
    });
  });
}
