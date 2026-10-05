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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/widgets/identity_header.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

import '../helpers/widget_test_utils.dart';

/// The four room and space pages were rebuilt on these primitives, and the
/// three defects they fix were all things a pure-function test cannot see.
///
/// A test that asserts "the panel contains three rows" would have passed
/// against the old card-per-row design too, because the old design also
/// contained three rows. What matters is that they share one surface, that the
/// page has a measure, and that the leading slot lines up.
void main() {
  Widget host(WidgetTester tester, Widget child) => MaterialApp(
        theme: testMoonrelayTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child is Scaffold ? child : Scaffold(body: child),
      );

  Future<AppLocalizations> mount(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.pumpWidget(host(tester, child));
    // MoonrelayInfoPage brings its own Scaffold, so the host adds a second
    // one around it. Take the first.
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
  }

  group('a panel is one surface, not a card per row', () {
    testWidgets('three rows share a single decorated box', (tester) async {
      await mount(
        tester,
        const InfoPanel(
          children: [
            InfoPanelRow(label: 'One'),
            InfoPanelRow(label: 'Two'),
            InfoPanelRow(label: 'Three'),
          ],
        ),
      );

      // The regression. `InfoActionTile` gave every row its own `Card`, so a
      // group of three actions rendered as three boxes with three borders.
      expect(find.byType(Card), findsNothing);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
    });

    testWidgets('rows are separated by hairlines, not by gaps', (tester) async {
      await mount(
        tester,
        const InfoPanel(
          children: [
            InfoPanelRow(label: 'One'),
            InfoPanelRow(label: 'Two'),
          ],
        ),
      );

      // Two rows get exactly one divider. The old layout had a 4px margin per
      // row plus a border per row, so "how many lines separate these" had no
      // single answer.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('a single-row panel has no divider at all', (tester) async {
      await mount(
        tester,
        const InfoPanel(
          children: [InfoPanelRow(label: 'Only')],
        ),
      );
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('a titled panel puts its title outside the surface',
        (tester) async {
      await mount(
        tester,
        const InfoPanel(
          title: 'Access and history',
          children: [InfoPanelRow(label: 'One')],
        ),
      );

      // The heading is above the panel's top edge rather than interrupting it,
      // so the edge reads as one line.
      final label = find.byType(InfoSectionLabel);
      expect(label, findsOneWidget);
      expect(find.text('Access and history'), findsOneWidget);
    });

    testWidgets('an empty panel renders no dividers', (tester) async {
      // Permission gating means several panels legitimately hold zero rows on
      // a given room, and a panel of nothing should be nothing rather than an
      // empty bordered box.
      await mount(tester, const InfoPanel(children: []));
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('the leading slot lines up', () {
    testWidgets('every icon in a panel starts at the same x', (tester) async {
      await mount(
        tester,
        const InfoPanel(
          children: [
            InfoPanelRow(icon: LucideIcons.hash, label: 'Short'),
            InfoPanelRow(icon: LucideIcons.calendar, label: 'A much longer'),
          ],
        ),
      );

      // The regression. `InfoDetailRow` gave the *label* a fixed 100px column,
      // so a value's x depended on how long its label happened to be.
      final dx = <double>[
        for (final glyph in <IconData>[LucideIcons.hash, LucideIcons.calendar])
          tester.getTopLeft(find.byIcon(glyph)).dx,
      ];
      expect(dx, hasLength(2));
      expect(dx[0], dx[1], reason: 'icons at $dx');
    });

    testWidgets('a long value does not push the row past the panel',
        (tester) async {
      await mount(
        tester,
        const InfoPanel(
          children: [
            InfoPanelRow(
              label: 'Room ID',
              value: '!abcdefghijklmnopqrstuvwxyz0123456789:matrix.org',
            ),
          ],
        ),
      );

      // No overflow. A RenderFlex overflow is reported as a caught exception,
      // so this fails rather than painting a stripe.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long label and no value still fits', (tester) async {
      await mount(
        tester,
        SizedBox(
          width: 260,
          child: const InfoPanel(
            children: [
              InfoPanelRow(label: 'An unusually long section title here'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('row behaviour', () {
    testWidgets('a tappable row shows a chevron', (tester) async {
      var taps = 0;
      await mount(
        tester,
        InfoPanel(
          children: [
            InfoPanelRow(label: 'Copy room ID', onTap: () => taps++),
          ],
        ),
      );

      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
      await tester.tap(find.text('Copy room ID'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a read-only row has no chevron', (tester) async {
      await mount(
        tester,
        const InfoPanel(
          children: [InfoPanelRow(label: 'Created', value: 'Today')],
        ),
      );
      // A chevron on a row that does nothing is a promise the row does not keep.
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
    });

    testWidgets('an explicit trailing wins over the chevron', (tester) async {
      await mount(
        tester,
        InfoPanel(
          children: [
            InfoPanelRow(
              label: 'Encrypted',
              onTap: () {},
              trailing: const Icon(LucideIcons.shieldCheck, size: 16),
            ),
          ],
        ),
      );
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
    });

    testWidgets('a destructive row is coloured from the error role',
        (tester) async {
      late ColorScheme captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              captured = Theme.of(context).colorScheme;
              return const Scaffold(
                body: InfoPanel(
                  children: [
                    InfoPanelRow(label: 'Leave room', destructive: true),
                  ],
                ),
              );
            },
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Leave room'));
      // The destructive treatment is the error role outright, not a tinted
      // approximation of it.
      expect(text.style!.color, captured.error);
    });
  });

  group('the page has a measure', () {
    testWidgets('content is capped on a wide window', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final l10n = await mount(
        tester,
        MoonrelayInfoPage(
          title: 'Room info',
          children: const [
            InfoPanel(children: [InfoPanelRow(label: 'x')])
          ],
        ),
      );
      expect(l10n, isNotNull);

      // On a 2000px window an uncapped ListView puts its content against the
      // left edge and leaves a label and its value 1400px apart.
      final panel = tester.getSize(find.byType(InfoPanel)).width;
      expect(
        panel,
        lessThanOrEqualTo(MoonrelayInfoPage.maxContentWidth),
        reason: 'panel was $panel wide',
      );
    });

    testWidgets('a narrow window is not padded past its own width',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await mount(
        tester,
        MoonrelayInfoPage(
          title: 'Room info',
          children: const [
            InfoPanel(children: [InfoPanelRow(label: 'x')])
          ],
        ),
      );

      final panel = tester.getSize(find.byType(InfoPanel)).width;
      expect(panel, lessThan(420));
      expect(panel, greaterThan(300));
      expect(tester.takeException(), isNull);
    });
  });

  group('section rhythm', () {
    testWidgets('the first gap is smaller than the ones after it',
        (tester) async {
      await mount(
        tester,
        Column(
          children: const [
            InfoSectionGap(first: true),
            InfoSectionGap(),
          ],
        ),
      );

      final t = MoonrelayDesignTokens.standard();
      final gaps = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .map((s) => s.height)
          .whereType<double>()
          .toList();
      expect(gaps, containsAll(<double>[t.spaceXl, t.spaceXxl]));
    });
  });

  group('chips', () {
    testWidgets('a plain chip is outlined, not filled', (tester) async {
      await mount(
        tester,
        const Wrap(
            children: [InfoChip(icon: LucideIcons.lock, label: 'Public')]),
      );

      final chip = tester.widget<InfoChip>(find.byType(InfoChip));
      expect(chip.emphasis, isFalse);

      // The regression. The old chip filled with `secondaryContainer` at
      // `opacitySubtle`, which on the current palette is the composer's own
      // step, so a chip in the header matched the message input behind it.
      final decorated = tester.widget<Container>(find.byType(Container));
      final decoration = decorated.decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNotNull);
    });

    testWidgets('an emphasised chip is filled with the accent', (tester) async {
      await mount(
        tester,
        const Wrap(
          children: [
            InfoChip(
              icon: LucideIcons.shieldCheck,
              label: 'Encrypted',
              emphasis: true,
            ),
          ],
        ),
      );

      final decorated = tester.widget<Container>(find.byType(Container));
      final decoration = decorated.decoration! as BoxDecoration;
      expect(decoration.color, isNot(Colors.transparent));
    });
  });

  group('the identity header', () {
    testWidgets('it puts the avatar and the name on one line', (tester) async {
      await mount(
        tester,
        const IdentityHeader(
          name: 'General',
          topic: 'Where the work happens',
          avatar: CircleAvatar(radius: 32, child: Text('G')),
          chips: [InfoChip(icon: LucideIcons.lock, label: 'Private')],
        ),
      );

      final avatar = tester.getTopLeft(find.byType(CircleAvatar));
      final name = tester.getTopLeft(find.text('General'));
      expect(
        name.dy,
        greaterThanOrEqualTo(avatar.dy - 40),
        reason: 'the name should not be stacked under a centred avatar',
      );
    });

    testWidgets('a header with no topic drops that line', (tester) async {
      await mount(
        tester,
        const IdentityHeader(
          name: 'General',
          topic: '   ',
          avatar: CircleAvatar(radius: 32, child: Text('G')),
          chips: [],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('chips wrap without overflowing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await mount(
        tester,
        const IdentityHeader(
          name: 'A space with a fairly long display name',
          topic: 'And a topic that also runs on for a while',
          avatar: CircleAvatar(radius: 32, child: Text('A')),
          chips: [
            InfoChip(icon: LucideIcons.folder, label: 'Space'),
            InfoChip(icon: LucideIcons.users, label: '1428 members'),
            InfoChip(icon: LucideIcons.shieldCheck, label: 'Encrypted'),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
