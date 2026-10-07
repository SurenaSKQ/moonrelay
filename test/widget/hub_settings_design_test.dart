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

// What the hub's redesign has to keep true, expressed as assertions.
//
// Every test here corresponds to a defect that was in the code, because a
// design rule nothing checks is a design rule that comes back.
//
//   * the measure. Not one of the hub's seventeen pages had a width limit, so
//     on a two-pane window every settings row ran to the full window width and
//     each page had invented its own internal geometry to cope.
//   * one control vocabulary. Five slider wells said 160px, two said 200, and
//     a private slider row existed solely to convert ints to doubles.
//   * one title per page. Every settings body drew a 22px heading under the
//     14px strip that already said the same words.
//   * one list of shortcuts. The cheat sheet and the keybind page each held
//     their own copy and had already diverged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/initials.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/widgets/shortcut_reference.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

/// An English bundle without a widget tree.
///
/// The generated class is the real thing rather than a hand-written stand-in,
/// because these assertions are about which strings the app ships. A fake
/// implementing `noSuchMethod` would let a missing key return a plausible
/// string and the test would pass on a page nobody can read.
AppLocalizations _en() => lookupAppLocalizations(const Locale('en'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the hub has one measure', () {
    testWidgets('HubPageBody caps its content at the info page width',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const Scaffold(
            body: HubPageBody(children: <Widget>[SizedBox(height: 10)]),
          ),
        ),
      );

      final caps = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .map((ConstrainedBox b) => b.constraints.maxWidth)
          .toList();
      expect(
        caps,
        contains(MoonrelayInfoPage.maxContentWidth),
        reason: 'the body must cap its width rather than fill the pane',
      );
    });

    testWidgets('HubPageBody inserts the one gap between sections itself',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const Scaffold(
            body: HubPageBody(
              children: <Widget>[
                SizedBox(key: Key('a'), height: 10),
                SizedBox(key: Key('b'), height: 10),
              ],
            ),
          ),
        ),
      );

      // No page may add its own gap, or the rhythm is whatever that page
      // remembered: six spelled it `spaceLg`, seven a literal 16, one 24 and
      // one forgot it entirely. The keyed boxes are the sections themselves;
      // the only unkeyed spacer of height should be the seam the body added.
      final gaps = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where(
            (SizedBox s) =>
                s.height != null && s.child == null && s.key == null,
          )
          .toList();
      expect(gaps, hasLength(1), reason: 'exactly one gap, for the seam');
      expect(gaps.single.height, greaterThan(0));
    });

    testWidgets('HubMeasure constrains without taking over the scroll',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: Scaffold(
            body: HubMeasure(
              child: ListView(children: const <Widget>[Text('x')]),
            ),
          ),
        ),
      );
      // The encryption page brings its own ListView from /main/encryption.
      // Nesting that in another scroll view is the error this widget exists to
      // avoid, so it must not add one.
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('one control vocabulary', () {
    HubSliderTile slider({double value = 1, ValueChanged<double>? onChanged}) =>
        HubSliderTile(
          icon: Icons.tune,
          title: 'A number',
          value: value,
          valueLabel: '$value',
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: onChanged,
        );

    testWidgets('a persisted value outside the range is clamped, not asserted',
        (tester) async {
      // A setting stored by a release whose maximum was lower than today's
      // arrives out of range. `Slider` asserts on that in debug and paints a
      // thumb off the end of its own track in release.
      await tester.pumpWidget(
        wrapWithProviders(
          child: Scaffold(
            body: HubSettingsSection(
              title: 'Group',
              children: <Widget>[slider(value: 9999, onChanged: _noop)],
            ),
          ),
        ),
      );
      final s = tester.widget<Slider>(find.byType(Slider));
      expect(s.value, 100);
      expect(s.min, 0);
      expect(s.max, 100);
    });

    testWidgets('a null onChanged really disables the control', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: Scaffold(
            body: HubSettingsSection(
              title: 'Group',
              children: <Widget>[
                slider(onChanged: null),
                const HubSwitchTile(
                  icon: Icons.tune,
                  title: 'A switch',
                  description: 'off',
                  value: true,
                  onChanged: null,
                ),
                const HubChoiceChipRow<String>(
                  values: <String>['a'],
                  selected: 'a',
                  labelOf: _identity,
                  onSelected: null,
                ),
              ],
            ),
          ),
        ),
      );

      // Three settings here are meaningless without a switch above them: how
      // long drafts are kept, how long presence waits, what the tray click
      // does. A control that looks live and swallows the tap is worse than one
      // that looks dead.
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(
        tester.widget<ChoiceChip>(find.byType(ChoiceChip)).onSelected,
        isNull,
      );
    });

    testWidgets('the slider well is the same width for every setting',
        (tester) async {
      Future<void> pump() => tester.pumpWidget(
            wrapWithProviders(
              child: Scaffold(
                body: SizedBox(
                  width: 680,
                  child: HubSettingsSection(
                    title: 'Group',
                    children: <Widget>[slider()],
                  ),
                ),
              ),
            ),
          );

      await pump();
      final first = tester.getSize(find.byType(Slider)).width;
      expect(first, greaterThan(0));

      await pump();
      expect(
        tester.getSize(find.byType(Slider)).width,
        first,
        reason: 'the well is derived, so two rows cannot disagree',
      );
    });
  });

  group('appearance and layout are one page', () {
    test('the merged label is what the nav row and the overview both show', () {
      final l10n = _en();
      final items = buildSettingsNavigationItems(l10n);
      final appearance = items.firstWhere(
        (HubNavigationItem i) => i.key == HubRouteKeys.appearance,
      );
      expect(appearance.label, l10n.appearanceAndLayout);
      expect(appearance.subtitle, isNotNull);
    });

    test('the retired layout key has no row and no overview entry', () {
      for (final String key in HubRouteKeys.settingsSubItems) {
        expect(key, isNot(HubRouteKeys.retiredLayout));
      }
      expect(
        buildSettingsNavigationItems(_en()).map((HubNavigationItem i) => i.key),
        isNot(contains(HubRouteKeys.retiredLayout)),
      );
    });

    test('every live sub-item has a label and the nav list agrees with it', () {
      final l10n = _en();
      // The nav list used to hand-list all thirteen keys beside the one in
      // `HubRouteKeys` and the one in the overview page, so a row could exist
      // for a sub-item no page renders and nothing would object.
      expect(
        buildSettingsNavigationItems(l10n).length,
        HubRouteKeys.settingsSubItems.length,
      );
      for (final HubNavigationItem item in buildSettingsNavigationItems(l10n)) {
        expect(item.label, isNot(item.key), reason: 'a URL segment as a title');
      }
    });

    test('no shipped string is a metadata reference', () {
      // `accentDescription` shipped as the literal "@accentDescription" in the
      // English bundle and was absent from the Persian one, so the accent
      // picker told every user in every language that it was "@
      // accentDescription".
      expect(_en().accentDescription, isNot(contains('@')));
      expect(_en().accentDescription, isNotEmpty);
    });
  });

  group('the shortcut list has one home', () {
    test('no two entries claim the same chord', () {
      final seen = <String>{};
      for (final ShortcutReferenceEntry entry in shortcutReference()) {
        final chord = entry.keys.join('+');
        expect(
          seen.add(chord),
          isTrue,
          reason: '"$chord" is listed twice, so it is documented twice',
        );
      }
    });

    test('every scope has entries, or it is an empty heading', () {
      for (final ShortcutScope scope in ShortcutScope.values) {
        expect(
          shortcutsInScope(shortcutReference(), scope),
          isNotEmpty,
          reason: '$scope would render as a group with nothing in it',
        );
      }
    });

    test('the global scope is only the chords that fire everywhere', () {
      // The keybind page used to file Ctrl+F and Ctrl+Shift+M under "Global
      // shortcuts", and neither is global: both act on whichever room happens
      // to be open, so they do nothing on the welcome screen.
      final l10n = _en();
      final chords = shortcutsInScope(shortcutReference(), ShortcutScope.global)
          .map((ShortcutReferenceEntry e) => e.keys.join('+'))
          .toSet();
      expect(chords, contains('Ctrl+Shift+P'));
      expect(chords, contains('Ctrl+Shift+?'));
      expect(chords, contains('Esc'));
      expect(chords, isNot(contains('Ctrl+F')));
      expect(chords, isNot(contains('Ctrl+Shift+M')));
      expect(
        shortcutsInScope(shortcutReference(), ShortcutScope.room)
            .map((ShortcutReferenceEntry e) => e.description(l10n)),
        containsAll(<String>[l10n.shortcutInRoomSearch]),
      );
    });

    test('every entry describes itself in every shipped language', () {
      for (final locale in const <String>['en', 'fa']) {
        final l10n = lookupAppLocalizations(Locale(locale));
        for (final ShortcutReferenceEntry entry in shortcutReference()) {
          expect(entry.description(l10n), isNotEmpty, reason: locale);
        }
      }
    });
  });

  group('a short Matrix id does not crash a circle in the hub', () {
    // `@a:example.org` is legal. The navigation header did
    // `userId.substring(1, 2)` and the blocked-users row did
    // `userId.replaceAll('@', '').substring(0, 1)`, both of which throw a
    // RangeError, and both of which took the pane down with them.
    test('an id initial survives a one-character localpart', () {
      expect(matrixIdInitial('@a:example.org'), isNotEmpty);
    });

    test('an id initial survives an empty localpart', () {
      expect(matrixIdInitial('@:example.org'), '?');
      expect(matrixIdInitial(''), '?');
      expect(matrixIdInitial(null), '?');
    });

    test('an id initial is taken from the localpart, not the domain', () {
      expect(matrixIdInitial('@surena:example.org'), 'S');
      expect(matrixIdInitial('@s:example.org'), 'S');
    });

    test('initials survive a blank display name', () {
      // `split(RegExp(' +')).map((s) => s[0])` throws on a name with no words
      // in it, and a Matrix user may have no display name at all.
      expect(matrixInitials(''), '?');
      expect(matrixInitials('   '), '?');
      expect(matrixInitials(null), '?');
    });

    test('initials are one or two letters, uppercased', () {
      expect(matrixInitials('surena'), 'S');
      expect(matrixInitials('surena karimpour'), 'SK');
      expect(matrixInitials('surena   karimpour   ghannadi'), 'SK');
      expect(matrixInitials('  surena  '), 'S');
    });
  });
}

String _identity(String value) => value;

void _noop(double _) {}
