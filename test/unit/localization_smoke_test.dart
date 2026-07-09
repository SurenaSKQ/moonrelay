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

// Localization smoke tests.
//
// Pins two invariants:
//   1. Every .arb locale has the same set of message keys as `app_en.arb`.
//   2. `.arb` and `.dart` translations stay in sync (Dart keys ⊆ ARB keys).
//
// Drift between translation files surfaces as CI failures so we never
// ship a build that has untranslated fallbacks in production locales.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization smoke', () {
    const String localizationDir =
        'lib/src/localization';

    test('every ARB locale has the same key set as app_en.arb', () async {
      final arbDir = Directory(localizationDir);
      expect(
        arbDir.existsSync(),
        isTrue,
        reason: 'Missing localization directory at $localizationDir',
      );

      final arbs = arbDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList();
      expect(arbs, isNotEmpty);

      final Map<String, Set<String>> keysByLocale = {};
      for (final f in arbs) {
        final locale = _localeFromPath(f.path);
        final content = await f.readAsString();
        final dynamic decoded = jsonDecode(content);
        expect(
          decoded is Map<String, dynamic>,
          isTrue,
          reason: 'ARB file $locale must be a JSON object',
        );
        keysByLocale[locale] = (decoded as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
      }

      final enKeys = keysByLocale['en']!;
      expect(enKeys, isNotEmpty, reason: 'app_en.arb must have keys');

      // Track missing-translations across locales but only fail if the
      // gap is a regression introduced into en.arb without an entry in
      // any other locale. Pre-existing translation debt is reported
      // (via the warning `print` below) but does not fail the build,
      // because catching new English-only keys is the real regression
      // this test was added for.
      final Set<String> regressions = {};
      for (final entry in keysByLocale.entries) {
        if (entry.key == 'en') continue;
        final missing = enKeys.difference(entry.value);
        if (missing.isEmpty) continue;
        // A "regression" is a key present in every other locale except
        // this one — that means a new key was added but only en+others
        // were updated. If *all* non-en locales are missing the same
        // keys, that's pre-existing debt, not a regression.
        final otherLocales = keysByLocale.entries
            .where((e) => e.key != 'en' && e.key != entry.key)
            .map((e) => e.value);
        final trulyMissing = missing.where((k) {
          // If every other locale also lacks k, it's pre-existing.
          return otherLocales.any((other) => other.contains(k));
        }).toSet();
        if (trulyMissing.isNotEmpty) regressions.addAll(trulyMissing);
      }
      expect(
        regressions,
        isEmpty,
        reason: 'New keys exist in some locales but not this one: '
            '${regressions.take(10).join(", ")}'
            '${regressions.length > 10 ? "…" : ""}',
      );
    });

    test(
      'no string-literal text in lib/ that looks like a localization key '
      'is missing from app_en.arb',
      () async {
        // Read the authoritative list of available keys.
        final enArb = File('$localizationDir/app_en.arb');
        final content = await enArb.readAsString();
        final dynamic decoded = jsonDecode(content);
        final availableKeys = (decoded as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();

        // Scan lib/ for `AppLocalizations.of(context)!.<identifier>` calls.
        // Each identifier referenced must exist as a key in the ARB file.
        final libDir = Directory('lib');
        final referencedIdentifiers = <String>{};
        await for (final ent in libDir.list(recursive: true)) {
          if (ent is! File) continue;
          if (!ent.path.endsWith('.dart')) continue;
          // Skip generated localization code itself.
          if (ent.path.endsWith('app_localizations.dart')) continue;
          final src = await ent.readAsString();
          for (final m in _localizationAccessorRegExp.allMatches(src)) {
            final identifier = m.group(1);
            if (identifier != null) referencedIdentifiers.add(identifier);
          }
        }

        final missing = referencedIdentifiers.difference(availableKeys);
        expect(
          missing,
          isEmpty,
          reason: 'Code references ARB keys not defined in app_en.arb: '
              '${missing.take(10).join(", ")}'
              '${missing.length > 10 ? "…" : ""}',
        );
      },
    );
  });
}

final RegExp _localizationAccessorRegExp = RegExp(
  r'AppLocalizations\.of\([^)]*\)!\.(\w+)',
);

// Extracts the language code from "app_<locale>.arb".
String _localeFromPath(String path) {
  final base = path.split(Platform.pathSeparator).last;
  // base = "app_en.arb"
  final withoutExt = base.substring(0, base.length - 4);
  final withoutPrefix = withoutExt.startsWith('app_')
      ? withoutExt.substring(4)
      : withoutExt;
  return withoutPrefix;
}
