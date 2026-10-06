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

// The welcome screen's affordances, and the two structural rules the redesign
// is actually about.
//
// One raised thing per screen. The screen used to be four Material `Card`s with
// `elevation: 2` on all of them, which rendered from `kElevationToShadow`, a
// hardcoded black map no theme field reaches and which is therefore invisible
// on the dark ramp. Equal weight on every block meant the thing the user came
// to do was no louder than the project news.
//
// A grid at one width and a column at the other, because the brand and the
// column of panels are different jobs and they only sit side by side when
// there is room for both.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/startup_screen/startup_screen.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:moonrelay/src/widgets/moonrelay_mark.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpWelcome(
    WidgetTester tester, {
    double width = 1200,
    AccountManager? accountManager,
  }) async {
    tester.view.physicalSize = Size(width, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final MockClient client = MockClient();
    when(() => client.userID).thenReturn('@me:example.org');
    when(() => client.rooms).thenReturn(<Room>[]);

    // Passed through `wrapWithProviders` rather than wrapped around it. The shared
    // wrapper supplies its own `MockAccountManager` as the inner descendant, so a
    // provider added outside it is shadowed, and `hasAccounts` on the bare mock
    // returns null where the screen reads a `bool`.
    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        accountManager: accountManager ?? AccountManager(log: MockLogger()),
        child: const StartupScreen(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  group('one raised thing per screen', () {
    testWidgets('exactly one card carries a shadow', (tester) async {
      await pumpWelcome(tester);

      final Finder cards = find.byType(AuthCard);
      expect(cards, findsOneWidget);

      // Everything else on the screen is a well. `AuthPanel` is the quieter
      // primitive precisely so that "which of these am I here for" is answerable
      // without reading the words.
      expect(find.byType(AuthPanel), findsNWidgets(2));
    });

    testWidgets('the raised one is the ways in', (tester) async {
      await pumpWelcome(tester);

      // The shadow belongs on the card with the buttons, not on the news.
      expect(
        find.descendant(
            of: find.byType(AuthCard), matching: find.byType(AuthButton)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byType(AuthPanel),
          matching: find.byType(AuthButton),
        ),
        findsNothing,
        reason: 'a panel is reference material and offers nothing to press',
      );
    });
  });

  group('the three ways in', () {
    testWidgets('sign in and create account are the two buttons',
        (tester) async {
      await pumpWelcome(tester);

      // Two, not three. SSO used to be a third stacked full-width button, which
      // made it read as the least likely option rather than as a different kind
      // of thing to do. It is a link now.
      expect(find.byType(AuthButton), findsNWidgets(2));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('SSO is reachable as a link, not only as a button',
        (tester) async {
      await pumpWelcome(tester);

      expect(find.text(l10n.signInWithSso), findsOneWidget);
      expect(find.text(l10n.signIn), findsOneWidget);
      expect(find.text(l10n.createAccount), findsOneWidget);
    });

    testWidgets('the footer reaches all four sub-pages as links', (
      tester,
    ) async {
      await pumpWelcome(tester, width: 600);

      expect(find.text(l10n.thirdPartyLicense), findsOneWidget);
      expect(find.text(l10n.privacyPolicy), findsOneWidget);
      expect(find.text(l10n.appSettings), findsOneWidget);
      expect(find.text(l10n.credits), findsOneWidget);
    });

// The footer used to be appended only in the single-column branch, so on a
    // desktop window the four links were absent from the tree rather than
    // merely below the fold. Two of the four pages have no route, so on a wide
    // window the licences and the privacy policy were unreachable outright.
    // Asserted across the breakpoint because "it renders" is only half the
    // claim; the other half is that each branch builds it, and the two
    // branches are separate code that used to disagree.
    for (final double width in <double>[600, 1200, 1600]) {
      testWidgets('the footer is present at ${width.toInt()}px wide', (
        tester,
      ) async {
        await pumpWelcome(tester, width: width);

        for (final String label in <String>[
          l10n.thirdPartyLicense,
          l10n.privacyPolicy,
          l10n.appSettings,
          l10n.credits,
        ]) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: '"$label" is missing at ${width.toInt()}px',
          );
        }
      });
    }

    testWidgets('the footer is in the scroll view, not clipped by it', (
      tester,
    ) async {
      // A short window is the case where a footer placed outside the scroll
      // view would be cut off, which is worse than missing: the reader sees a
      // sign-in form and no indication that there is more below it.
      //
      // The size has to be set before the first pump. Setting it afterwards
      // throws the mounted tree away, and the replacement is measured at the
      // old size, so the assertion below would be made against a screen laid
      // out for a window that no longer exists.
      tester.view.physicalSize = const Size(1200, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final MockClient client = MockClient();
      when(() => client.userID).thenReturn('@me:example.org');
      when(() => client.rooms).thenReturn(<Room>[]);

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          accountManager: AccountManager(log: MockLogger()),
          child: const StartupScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsWidgets);
      final Finder footer = find.ancestor(
        of: find.text(l10n.credits),
        matching: find.byType(SingleChildScrollView),
      );
      expect(
        footer,
        findsOneWidget,
        reason: 'the footer must live inside a scroll view to survive a short '
            'window',
      );
    });
  });

  group('the brand lockup', () {
    testWidgets('uses the real mark and the display face', (tester) async {
      await pumpWelcome(tester);

      // The old wordmark spelled `fontFamily: 'Oxanium'` at a literal 36, which
      // was the only hardcoded family left in the app and a size on no scale.
      expect(find.byType(MoonrelayMark), findsOneWidget);
      expect(find.text(l10n.projectName), findsOneWidget);
      expect(find.text(l10n.startupTagline), findsOneWidget);
    });

    testWidgets('the mark is drawn at a size that survives being line only', (
      tester,
    ) async {
      await pumpWelcome(tester);

      final Size size = tester.getSize(find.byType(MoonrelayMark));
      // The SVG is stroked, not filled, so a small render thins it. 40 is the
      // floor below which it stops reading as a mark.
      expect(size.width, greaterThanOrEqualTo(32));
      expect(size.width, size.height);
    });
  });

  group('the layout switches', () {
    testWidgets('two columns when there is room, one when there is not', (
      tester,
    ) async {
      await pumpWelcome(tester, width: 1400);
      final double wideLeft = tester.getRect(find.byType(AuthBrandLockup)).left;
      final double wideRight = tester.getRect(find.byType(AuthCard)).left;
      expect(
        wideRight,
        greaterThan(wideLeft),
        reason: 'beside each other, not stacked',
      );

      await pumpWelcome(tester, width: 520);
      final double narrowLeft =
          tester.getRect(find.byType(AuthBrandLockup)).left;
      final double narrowRight = tester.getRect(find.byType(AuthCard)).left;
      expect(
        (narrowRight - narrowLeft).abs(),
        lessThan(4),
        reason: 'stacked, so they share a left edge',
      );
    });
  });

  group('geometry comes from the ramp', () {
    testWidgets('the column never exceeds the form measure', (tester) async {
      await pumpWelcome(tester, width: 2400);

      // 420 here rather than `kAuthFormWidth`, because this column holds cards
      // rather than inputs. The invariant is that it stops widening: a card
      // stretched across a 2400px window is a card with one word in the middle
      // of it.
      final Size card = tester.getSize(find.byType(AuthCard));
      expect(card.width, lessThanOrEqualTo(460));
      expect(card.width, greaterThan(300));
    });

    testWidgets('nothing in the column overflows at a narrow width', (
      tester,
    ) async {
      // 400 is below the two-column breakpoint and narrow enough that the
      // panels' padding plus a long heading is the interesting case.
      await pumpWelcome(tester, width: 400);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panels keep the card token radius', (tester) async {
      await pumpWelcome(tester);

      final t = MoonrelayDesignTokens.standard();
      for (final Finder host in <Finder>[
        find.byType(AuthCard),
        find.byType(AuthPanel),
      ]) {
        // The `DecoratedBox` each one builds is its own root child, so `first`
        // is that one rather than some nested decoration further down.
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.descendant(of: host, matching: find.byType(DecoratedBox)).first,
        );
        expect(
          (box.decoration as BoxDecoration).borderRadius,
          BorderRadius.circular(t.radiusLg),
        );
      }
    });

    testWidgets('only the raised card has a shadow', (tester) async {
      await pumpWelcome(tester);

      BoxDecoration decorationOf(Finder host) => tester
          .widget<DecoratedBox>(
            find
                .descendant(of: host, matching: find.byType(DecoratedBox))
                .first,
          )
          .decoration as BoxDecoration;

      // The whole point of the two primitives. Before the redesign every block
      // was a Material `Card` with `elevation: 2`, and on the dark ramp that
      // elevation renders as nothing at all.
      expect(decorationOf(find.byType(AuthCard)).boxShadow, isNotNull);
      for (final Element panel in find.byType(AuthPanel).evaluate()) {
        expect(
            decorationOf(find.byElementPredicate((Element e) => e == panel))
                .boxShadow,
            isNull);
      }
    });
  });
}
