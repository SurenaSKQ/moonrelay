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

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/skins.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MoonrelaySkins registry', () {
    test('is non-empty and ships the default skin first', () {
      expect(MoonrelaySkins.all, isNotEmpty);
      expect(MoonrelaySkins.all.first, same(MoonrelaySkins.defaultSkin));
      expect(MoonrelaySkins.defaultSkinId, MoonrelaySkins.defaultSkin.id);
    });

    test('every skin has a unique id, a label and a seed colour', () {
      final ids = <String>{};
      for (final skin in MoonrelaySkins.all) {
        expect(skin.id, isNotEmpty);
        expect(skin.label, isNotEmpty);
        expect(skin.seedColor, isNotNull);
        expect(ids.add(skin.id), isTrue,
            reason: 'duplicate skin id: ${skin.id}');
      }
    });

    test('byId resolves known ids and rejects unknown ones', () {
      expect(MoonrelaySkins.byId('compact'), same(MoonrelaySkins.compact));
      expect(MoonrelaySkins.byId('nope'), isNull);
      expect(MoonrelaySkins.byId(null), isNull);
    });

    test('fromId falls back to the default skin for unknown ids', () {
      expect(MoonrelaySkins.fromId('nope'), same(MoonrelaySkins.defaultSkin));
      expect(MoonrelaySkins.fromId(null), same(MoonrelaySkins.defaultSkin));
    });

    test('the compact skin is tighter than the default', () {
      expect(MoonrelaySkins.compact.defaultDensity, LayoutDensity.compact);
      expect(MoonrelaySkins.compact.cornerRadius,
          lessThan(MoonrelaySkins.defaultSkin.cornerRadius));
    });
  });

  group('SettingsService selected skin migration', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('falls back to the default on a fresh install', () async {
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedSkinId, MoonrelaySkins.defaultSkinId);
    });

    test('migrates the legacy theme_option index to a skin id', () async {
      // Legacy enum order: 0 indigo, 1 oceanBlue, 2 midnightSlate, ...
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 2,
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedSkinId, 'midnight');
    });

    test('clamps out-of-range legacy indices to the default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 999,
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedSkinId, MoonrelaySkins.defaultSkinId);
    });

    test('selected_skin takes precedence over the legacy key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_option': 5,
        'selected_skin': 'compact',
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.selectedSkinId, 'compact');
    });

    test('updateSelectedSkin persists the id', () async {
      final service = SettingsService();
      await service.updateSelectedSkin('sky');
      expect(await service.selectedSkinId(), 'sky');
    });
  });
}
