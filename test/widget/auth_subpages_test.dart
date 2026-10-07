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

// The three sub-pages the welcome screen's footer reaches.
//
// Each one had its own `Scaffold`, its own measure and its own card. The
// licences screen was 16/12, the privacy policy 20/16 and the settings screen
// `spaceXl` on all sides, so a person tapping along the footer moved between
// three layouts. All three are `MoonrelayInfoPage` now, which is the app's page
// shell, and that is the whole of the visual change to their chrome.
//
// The settings page had its own copy of the hub's settings section. That copy
// had drifted: it coloured its section headings with the accent, which is the
// single loudest thing the hub pass removed from thirteen pages, and it used
// `theme.dividerColor`, which was the app's second grey. It uses
// `HubSettingsSection` now, which has no provider dependency and is purely
// presentational.
//
// A note on what these tests do and do not count. `MoonrelayInfoPage` hands an
// explicit child list to a `ListView`, which is still a `SliverList` and still
// builds lazily, so a section below the fold is not in the tree at all. An
// earlier version of this file asserted "four panels" and got three, twice, and
// spent a while treating that as a missing section when it was a section nobody
// had scrolled to. So: the counts below are of what is on screen, and the
// per-section facts are asserted by finding each section's own title.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/screens/licenses.dart';
import 'package:moonrelay/src/screens/privacy_policy.dart';
import 'package:moonrelay/src/screens/startup_screen/credits_screen.dart';
import 'package:moonrelay/src/screens/startup_screen/welcome_settings.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/widgets/moonrelay_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(wrapWithProviders(child: screen));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  /// Scrolls [target] into view, building it if the lazy list had not yet.
  ///
  /// Used only for the handful of assertions about content that starts below the
  /// fold. The bulk of this file asserts on what is on screen, because "this
  /// page has four panels" is a statement about lazy-build plumbing as much as
  /// about design and it fails for reasons nobody can act on.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  /// The accent swatches, found by their shape rather than by their type, which
  /// is private to the screen that draws them.
  Finder theSwatches() => find.byWidgetPredicate(
        (Widget w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );

  group('every footer sub-page is the same page shell', () {
    testWidgets('the settings page', (tester) async {
      await pumpScreen(tester, const WelcomeSettingsScreen());

      expect(find.byType(MoonrelayInfoPage), findsOneWidget);
      // The hub's section widget, not a private copy. Thirteen hub pages share
      // one because thirteen pages each drawing their own is thirteen chances
      // to drift; this was a fourteenth, and it had already drifted: it put the
      // accent on its headings and used `theme.dividerColor`.
      expect(find.byType(HubSettingsSection), findsWidgets);
      expect(find.text(l10n.themeMode), findsOneWidget);
      expect(find.text(l10n.appearance), findsOneWidget);
    });

    testWidgets('the credits page', (tester) async {
      await pumpScreen(tester, const CreditsScreen());

      expect(find.byType(MoonrelayInfoPage), findsOneWidget);
      expect(find.byType(InfoPanel), findsWidgets);
      expect(find.text(l10n.projectName), findsOneWidget);
      expect(find.text(l10n.creditsLicenseTitle), findsOneWidget);
    });

    testWidgets('the licences page', (tester) async {
      await pumpScreen(tester, const LicensesScreen());

      expect(find.byType(MoonrelayInfoPage), findsOneWidget);
    });

    testWidgets('the privacy page', (tester) async {
      await pumpScreen(tester, const PrivacyPolicyPopupScreen());

      expect(find.byType(MoonrelayInfoPage), findsOneWidget);
      expect(find.byType(InfoPanel), findsWidgets);
      // It was seven Material `Card`s with the default shape and 20px of
      // padding on each.
      expect(find.byType(Card), findsNothing);
    });
  });

  group('the credits page', () {
    testWidgets('its title is a string, not the literal Credits', (
      tester,
    ) async {
      await pumpScreen(tester, const CreditsScreen());

      // The page's own title was `const Text('Credits')` while every other
      // screen in the segment read `l10n`.
      expect(find.text(l10n.credits), findsOneWidget);
    });

    testWidgets('its version comes from AppVersion, not a literal', (
      tester,
    ) async {
      await pumpScreen(tester, const CreditsScreen());

      // It reported `0.2.0+1`, hardcoded, while pubspec was at `0.6.0`, and
      // there is an `AppVersion` helper whose entire reason to exist is to be
      // the one place a version comes from. A credits page that understates
      // which build you are running is worse than none, because it is where a
      // person goes to find out.
      expect(find.text(l10n.creditsVersion('0.0.0+0')), findsOneWidget);
    });

    testWidgets('the visible sections are localized', (tester) async {
      await pumpScreen(tester, const CreditsScreen());

      // The whole page was hardcoded English except the app name and one
      // licence notice, including the page's own title.
      expect(find.text(l10n.creditsLicenseBody), findsOneWidget);
      expect(find.text(l10n.appLicenseNotice), findsOneWidget);
    });

    testWidgets('the repository link is a focusable button', (tester) async {
      await pumpScreen(tester, const CreditsScreen());
      await reveal(tester, find.byType(TextButton));

      // It was a `TapGestureRecognizer` inside a `Text.rich`. A recogniser
      // cannot be tabbed to, cannot be focused, and is not announced as a
      // link.
      expect(find.byType(TextButton), findsWidgets);
      expect(
        find.byType(RichText),
        findsWidgets,
      );
    });

    testWidgets('the brand mark is the real one', (tester) async {
      await pumpScreen(tester, const CreditsScreen());

      // A moon glyph from the icon set, which is what the splash used before it
      // grew the real mark and this page never followed.
      expect(find.byType(MoonrelayMark), findsOneWidget);
    });
  });

  group('the privacy policy', () {
    testWidgets('its revision date is a key', (tester) async {
      await pumpScreen(tester, const PrivacyPolicyPopupScreen());
      await reveal(tester, find.text(l10n.privacyPolicyLastUpdated));

      // `'Last updated: June 2025'` was a string literal, which is a claim
      // about a document that quietly stops being true.
      expect(find.text(l10n.privacyPolicyLastUpdated), findsOneWidget);
    });

    testWidgets('its summary is a notice, not the loudest text on the page', (
      tester,
    ) async {
      await pumpScreen(tester, const PrivacyPolicyPopupScreen());

      final Text summary =
          tester.widget<Text>(find.text(l10n.privacyPolicyText));
      // It was 15pt inside a `secondaryContainer` card, and the only thing on
      // the page set that large. The body prose is 13.
      expect(summary.style!.fontSize, 13);
      expect(summary.style!.fontWeight, isNot(FontWeight.bold));
    });
  });

  group('the settings page', () {
    testWidgets('offers the three choices', (tester) async {
      await pumpScreen(tester, const WelcomeSettingsScreen());

      expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
      expect(find.text(l10n.accentColor), findsOneWidget);
      await reveal(tester, find.text(l10n.language));
      expect(find.text(l10n.language), findsOneWidget);
    });

    testWidgets('an accent swatch is the app icon size, not a bare 20', (
      tester,
    ) async {
      await pumpScreen(tester, const WelcomeSettingsScreen());

      // Nine swatches, each 20px because 20 happened to be the number that
      // matched `iconSizeMedium` rather than because that is the token.
      expect(theSwatches(), findsWidgets);
      final Size swatch = tester.getSize(theSwatches().first);
      expect(swatch.width, MoonrelayDesignTokens.standard().iconSizeMedium);
      expect(swatch.width, swatch.height);
    });

    testWidgets('and it carries a ring, so it reads on the card', (
      tester,
    ) async {
      await pumpScreen(tester, const WelcomeSettingsScreen());

      // A flat circle against a card disappears entirely in one of the nine
      // accents, and the swatch is the only thing naming which colour it is.
      final Container swatch = tester.widget<Container>(theSwatches().first);
      final BoxDecoration decoration = swatch.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });
}
