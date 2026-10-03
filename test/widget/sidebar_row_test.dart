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

import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/widgets/sidebar_row.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    required Widget child,
    LayoutDensity density = LayoutDensity.comfortable,
    double width = 320,
  }) async {
    final settings = createTestSettingsController();
    settings.updateDensity(density);
    await tester.pumpWidget(
      SizedBox(
        width: width,
        child: wrapWithProviders(
          settingsController: settings,
          child: Center(child: child),
        ),
      ),
    );
    await tester.pump();
  }

  group('SidebarRowMetrics', () {
    test('the default is large enough to read without leaning in', () {
      // A floor, not a description. 13pt was the first number tried here and
      // it read small against the window's own chrome, and the setting only
      // moved the type by one point, which is a rounding error rather than a
      // density choice. Both are easy to shrink again by accident, so both
      // are asserted.
      final c = SidebarRowMetrics.forDensity(LayoutDensity.comfortable);
      expect(c.titleSize, greaterThanOrEqualTo(15));
      expect(c.subtitleSize, greaterThanOrEqualTo(12));
    });

    test('the two densities are far enough apart to be a choice', () {
      // A one point range means the user cannot tell which they picked, and
      // the control looks broken.
      final c = SidebarRowMetrics.forDensity(LayoutDensity.comfortable);
      final k = SidebarRowMetrics.forDensity(LayoutDensity.compact);
      expect(c.titleSize - k.titleSize, greaterThanOrEqualTo(2));
    });

    // The reason this type exists. Four row types each carried their own
    // padding, two of them with a corner radius and two without, so the
    // pane read as four widgets stacked rather than as one list.
    test('the compact density is strictly tighter than comfortable', () {
      final c = SidebarRowMetrics.forDensity(LayoutDensity.comfortable);
      final k = SidebarRowMetrics.forDensity(LayoutDensity.compact);
      expect(k.minHeight, lessThan(c.minHeight));
      expect(k.padV, lessThan(c.padV));
      expect(k.leadingSize, lessThan(c.leadingSize));
      expect(k.titleSize, lessThan(c.titleSize));
      expect(k.subtitleSize, lessThan(c.subtitleSize));
    });

    test('the preview line is always smaller than the name', () {
      // The room row used to render 18pt and 16pt: a two point difference
      // between a label and the line supporting it.
      for (final d in LayoutDensity.values) {
        final m = SidebarRowMetrics.forDensity(d);
        expect(m.subtitleSize, lessThan(m.titleSize), reason: '$d');
      }
    });

test('a title and its preview line fit inside the row height', () {
      // Otherwise a two-line row silently overflows at the compact
      // density, where the floor is only 40px.
      for (final d in LayoutDensity.values) {
        final m = SidebarRowMetrics.forDensity(d);
        final needed = m.padV * 2 + m.titleSize * 1.2 + m.subtitleSize * 1.2;
        expect(needed, lessThan(m.minHeight + m.padV * 2), reason: '$d');
      }
    });

    test('every row is followed by a gap', () {
      // Nothing else in the pane says where one room ends and the next
      // begins: the pane's background is one step from the row's own fill, and
      // the fill only appears on hover and on selection. With the fills flush, a
      // selected row is one tall block with a rounded top and a square bottom,
      // which reads as a band rather than as a row.
      for (final d in LayoutDensity.values) {
        expect(SidebarRowMetrics.forDensity(d).rowGap, greaterThan(0));
      }
    });

    test('the gap survives a density change', () {
      // It is not a comfortable-only luxury. Compact still has to tell two
      // rooms apart, and compact is exactly where there are the most of them.
      expect(
        SidebarRowMetrics.forDensity(LayoutDensity.compact).rowGap,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('SidebarRow', () {
    testWidgets('renders a title, and a subtitle only when given one',
        (tester) async {
      await pump(tester, child: const SidebarRow(title: 'Only a title'));
      expect(find.text('Only a title'), findsOneWidget);

      await pump(
        tester,
        child: const SidebarRow(title: 'Name', subtitle: 'Last message'),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Last message'), findsOneWidget);
    });

    testWidgets('a two-line row and a one-line row share the same floor',
        (tester) async {
      // Otherwise a room row and a space row in the same list do not line
      // up, which is the specific thing that made the pane look assembled.
      await pump(tester, child: const SidebarRow(title: 'One line'));
      // The filled box, not the widget. `SidebarRow` also carries the gap to
      // its neighbour, and the floor this test is about is the height of the
      // thing that fills.
      final oneLine = tester.getSize(find.byType(Material)).height;

      await pump(
        tester,
        child: const SidebarRow(title: 'Name', subtitle: 'Last message'),
      );
      final twoLine = tester.getSize(find.byType(SidebarRow)).height;

      expect(twoLine, greaterThanOrEqualTo(oneLine));
      expect(oneLine,
          SidebarRowMetrics.forDensity(LayoutDensity.comfortable).minHeight);
    });

    testWidgets('the leading slot is sized from the shared metrics',
        (tester) async {
      // An icon and an avatar have to sit on the same axis, and the avatar
      // used to be a hard-coded radius 14 while everything else was
      // derived, so the two drifted apart the moment density changed.
      await pump(
        tester,
        density: LayoutDensity.compact,
        child: const SidebarRow(
          title: 'Row',
          leading: SizedBox.expand(),
        ),
      );
      final compact = tester.getSize(find.byType(Material)).height;
      expect(compact, SidebarRowMetrics.forDensity(LayoutDensity.compact).minHeight);
    });

    testWidgets('selection is carried by the container, not colour alone',
        (tester) async {
      await pump(tester, child: const SidebarRow(title: 'Unselected'));
      final unselected = tester.widget<Material>(
        find.descendant(
          of: find.byType(SidebarRow),
          matching: find.byType(Material),
        ),
      );

      await pump(tester, child: const SidebarRow(title: 'Selected', selected: true));
      final selected = tester.widget<Material>(
        find.descendant(
          of: find.byType(SidebarRow),
          matching: find.byType(Material),
        ),
      );

      expect(unselected.color, Colors.transparent);
      expect(selected.color, isNot(Colors.transparent));
      // Both keep the same corner radius, which is what stops a selected
      // row reading as a different widget from an unselected one.
      expect(unselected.borderRadius, selected.borderRadius);
    });

    testWidgets('titleSuffix sits between the name and the trailing slot',
        (tester) async {
      // The encryption badge is a property of the room's name, so it
      // belongs on the title line where the ellipsis can consume it.
      // Pinning it opposite the unread count would put the two things a
      // user scans for on opposite sides of the row.
      await pump(
        tester,
        child: const SidebarRow(
          title: 'Room',
          titleSuffix: Icon(Icons.shield, size: 12),
          trailing: Icon(Icons.circle, size: 12),
        ),
      );
      final name = tester.getCenter(find.text('Room'));
      final suffix = tester.getCenter(find.byIcon(Icons.shield));
      final trailing = tester.getCenter(find.byIcon(Icons.circle));
      expect(name.dx, lessThan(suffix.dx));
      expect(suffix.dx, lessThan(trailing.dx));
    });

    testWidgets('indent pushes the row contents in from the leading edge',
        (tester) async {
      await pump(tester, child: const SidebarRow(title: 'Flat'));
      // The left edge, not the centre: the label sits in an `Expanded`, so
      // the box is full width and its centre moves by half the inset.
      final flat = tester.getTopLeft(find.text('Flat')).dx;

      await pump(tester, child: const SidebarRow(title: 'Nested', indent: 16));
      final nested = tester.getTopLeft(find.text('Nested')).dx;

      expect(nested - flat, 16);
    });

    testWidgets('a selected row is marked by a bar, not only by its tint',
        (tester) async {
      // The tint alone is not enough to find the current room in a list of
      // two hundred: a row that is merely near the tint, or hovered, or
      // mid-transition, all read the same. A bar on the leading edge is a
      // position rather than a colour.
      //
      // Asked via the key rather than by counting opaque Containers in the
      // subtree, which is what this first tried. That cannot work: the tint
      // is on the Material wrapping the bar, so the count was already 1 for
      // an unselected row, and it kept the key it found from the previous
      // pump, so it reported a bar on a row that had just been switched off.
      await pump(
        tester,
        child: const SidebarRow(title: 'Current room', selected: true),
      );
      expect(find.byKey(sidebarRowAccentBarKey), findsOneWidget);

      await pump(tester, child: const SidebarRow(title: 'Other room'));
      expect(find.byKey(sidebarRowAccentBarKey), findsNothing);
    });

    testWidgets('the bar does not move the label or the leading slot',
        (tester) async {
      // The bar is positioned over the row's leading gutter, so it costs the
      // label nothing. This test used to assert the opposite, that the label
      // moved by exactly 3px, which is the width of the bar: the padding did
      // once account for it, and moving the selection shifted every selected
      // row's label and avatar 3px right, reflowing the list under the
      // pointer.
      //
      // Asserting an exact 3 was the real problem. It pins the one number
      // that is wrong, and it would still pass if the bar grew to 30px and
      // shoved the label across the row. Zero is the invariant; the bar's
      // existence is covered by the test above, so this is not asserting a
      // no-op that would also pass with the bar deleted.
      await pump(
        tester,
        child: const SidebarRow(
          title: 'Plain',
          leading: ColoredBox(key: ValueKey('lead'), color: Colors.red),
        ),
      );
      final plainLabel = tester.getTopLeft(find.text('Plain')).dx;
      final plainLeading =
          tester.getTopLeft(find.byKey(const ValueKey('lead'))).dx;

      await pump(
        tester,
        child: const SidebarRow(
          title: 'Plain',
          leading: ColoredBox(key: ValueKey('lead'), color: Colors.red),
          selected: true,
        ),
      );
      final selectedLabel = tester.getTopLeft(find.text('Plain')).dx;
      final selectedLeading =
          tester.getTopLeft(find.byKey(const ValueKey('lead'))).dx;

      expect(find.byKey(sidebarRowAccentBarKey), findsOneWidget);
      expect(selectedLabel - plainLabel, 0);
      expect(selectedLeading - plainLeading, 0);
    });

    testWidgets('the bar stays inside the leading gutter', (tester) async {
      // The invariant that lets the row ignore the bar entirely. If the bar
      // ever grew past padH, it would reach the label and the padding would
      // have to start accounting for it again, so this is the guard on that
      // decision rather than a restatement of the numbers above.
      await pump(
        tester,
        child: const SidebarRow(title: 'Selected', selected: true),
      );
final row = tester.getRect(find.byType(Material));
      final bar = tester.getRect(find.byKey(sidebarRowAccentBarKey));
      final padH =
          SidebarRowMetrics.forDensity(LayoutDensity.comfortable).padH;

      expect(bar.left, row.left);
      expect(bar.right, lessThanOrEqualTo(row.left + padH));
      // Full height of the filled box, so it reads as a position rather than a
      // dot. Measured against the Material, not against `SidebarRow`: the row
      // widget also carries the gap to its neighbour, and a bar that ran to the
      // bottom of that gap would hang one pixel into the space between rows.
      expect(bar.top, row.top);
      expect(bar.bottom, row.bottom);
    });

    testWidgets('taps and long presses reach their callbacks', (tester) async {
      var taps = 0;
      var longs = 0;
      await pump(
        tester,
        child: SidebarRow(
          title: 'Row',
          onTap: () => taps++,
          onLongPress: () => longs++,
        ),
      );
      await tester.tap(find.text('Row'));
      await tester.pump();
      await tester.longPress(find.text('Row'));
      await tester.pump();
      expect(taps, 1);
      expect(longs, 1);
    });
  });
}

