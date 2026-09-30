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
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/layouts/dashboard_layout/right_sidebar_content.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';

import '../helpers/widget_test_utils.dart';

/// The four tab labels, resolved through the same helper the widget uses.
///
/// Deliberately not restated as English literals: the previous
/// implementation had these strings hard-coded in the widget, which is the
/// bug being pinned, so writing them into the test as literals would make
/// the test agree with whichever wording the helper happens to have today.
Future<List<String>> _labels() async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  return RightSidebarHeader.destinations
      .map((c) => localizedRightPaneChoice(c, l10n))
      .toList();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    required RightPaneChoice choice,
    void Function(RightPaneChoice)? onChanged,
  }) async {
    await tester.pumpWidget(
      wrapWithProviders(
        child: Center(
          child: SizedBox(
            width: 280,
            child: RightSidebarHeader(
              currentChoice: choice,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('RightSidebarHeader', () {
    testWidgets('shows all four destinations at once', (tester) async {
      // It was a DropdownButton. That hid four destinations behind a closed
      // menu, and threads and pinned messages are not secondary: they are
      // where a user goes to answer a mention or find something they were
      // told to look at.
      await pump(tester, choice: RightPaneChoice.roomInfo);
      for (final label in await _labels()) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byType(DropdownButton<RightPaneChoice>), findsNothing);
    });

    testWidgets('every label comes from the shared localization helper',
        (tester) async {
      // The labels were hard-coded English. `localizedRightPaneChoice`
      // already existed and was already used by the hub's layout settings,
      // so the same mapping is used here rather than a second one.
      await pump(tester, choice: RightPaneChoice.roomInfo);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final choice in RightSidebarHeader.destinations) {
        final label = localizedRightPaneChoice(choice, l10n);
        expect(find.text(label), findsOneWidget, reason: '$choice');
      }
    });

    testWidgets('tapping a tab reports that destination', (tester) async {
      final picked = <RightPaneChoice>[];
      await pump(
        tester,
        choice: RightPaneChoice.roomInfo,
        onChanged: picked.add,
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester
          .tap(find.text(localizedRightPaneChoice(
              RightPaneChoice.threads, l10n)));
      await tester.pump();
      await tester.tap(find.text(
          localizedRightPaneChoice(RightPaneChoice.pinned, l10n)));
      await tester.pump();

      expect(picked, [RightPaneChoice.threads, RightPaneChoice.pinned]);
    });

    testWidgets('none is not a tab', (tester) async {
      // "Show nothing" is not a destination. The pane already has a
      // collapse control for it, and spending one of four slots on turning
      // the pane off would leave a primary destination off the strip.
      await pump(tester, choice: RightPaneChoice.roomInfo);
      expect(
        RightSidebarHeader.destinations,
        isNot(contains(RightPaneChoice.none)),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(localizedRightPaneChoice(RightPaneChoice.none, l10n)),
          findsNothing);
    });

    testWidgets('a stored value of none still renders the strip',
        (tester) async {
      // The value stays valid in storage, so a user who was last on `none`
      // opens the pane to a strip with nothing selected rather than to an
      // error or an empty header.
      await pump(tester, choice: RightPaneChoice.none);
      for (final label in await _labels()) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the four tabs share the strip evenly', (tester) async {
      // Evenly divided so a long label cannot push the next one off the
      // end of a narrow pane.
      await pump(tester, choice: RightPaneChoice.roomInfo);
      final centres = (await _labels())
          .map((t) => tester.getCenter(find.text(t)).dx)
          .toList();
      final gaps = <double>[
        for (var i = 1; i < centres.length; i++) centres[i] - centres[i - 1],
      ];
      for (final gap in gaps) {
        expect(gap, closeTo(gaps.first, 1.0));
      }
    });
  });

  group('RightSidebarContent', () {
    testWidgets('an empty pane invites a room rather than showing a header',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const Center(child: RightSidebarContent()),
        ),
      );
      await tester.pump();
      expect(find.byType(RightSidebarHeader), findsNothing);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.selectCategory), findsOneWidget);
    });
  });
}
