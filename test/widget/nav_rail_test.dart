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
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/space_child.dart'
    show SpaceChild, SpaceParent;
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_rail.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/room_search_field.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// Every accessible label the rail produced.
///
/// Asserted against the [Semantics] widgets rather than through
/// `find.bySemanticsLabel`, because that finder reads the composed semantics
/// tree and merges a [Tooltip]'s own node with the label below it. What
/// matters is the label the widget was told to publish.
Set<String> _labelsOf(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((s) => s.properties.label)
    .whereType<String>()
    .toSet();

MockRoom _space(String id, {String name = 'Test Space'}) {
  final room = MockRoom();
  when(() => room.id).thenReturn(id);
  when(() => room.isSpace).thenReturn(true);
  when(() => room.getLocalizedDisplayname()).thenReturn(name);
  when(() => room.avatar).thenReturn(null);
  when(() => room.spaceParents).thenReturn(<SpaceParent>[]);
  when(() => room.spaceChildren).thenReturn(<SpaceChild>[]);
  return room;
}

MockRoom _chat(String id, {String name = 'Test Room'}) {
  final room = MockRoom();
  when(() => room.id).thenReturn(id);
  when(() => room.isSpace).thenReturn(false);
  when(() => room.getLocalizedDisplayname()).thenReturn(name);
  return room;
}

Widget _rail({
  required List<Room> spaces,
  String? selectedId,
  bool isSpaceSelected = false,
}) {
  return wrapWithProviders(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SpacesRail(
          spaces: spaces,
          selectedId: selectedId,
          isSpaceSelected: isSpaceSelected,
          onSelect: (_) {},
          onCreateSpace: () {},
        ),
      ),
    ),
    navigationState: NavigationState(),
  );
}

void main() {
  setUp(RoomSearchQuery.clear);

  group('buildSpaceOrder', () {
    test('respects the saved order', () {
      final ordered = buildSpaceOrder(
        [_space('!a:matrix.org'), _space('!b:matrix.org')],
        order: ['!b:matrix.org', '!a:matrix.org'],
      );
      expect(ordered.map((r) => r.id), ['!b:matrix.org', '!a:matrix.org']);
    });

    test('a space the user has not ordered lands at the end, not nowhere', () {
      // A newly joined space has no entry in the saved order yet. Dropping it
      // would make a space the user just joined silently absent from the
      // only control that can reach it.
      final ordered = buildSpaceOrder(
        [_space('!a:matrix.org'), _space('!b:matrix.org')],
        order: ['!b:matrix.org'],
      );
      expect(ordered.map((r) => r.id), ['!b:matrix.org', '!a:matrix.org']);
    });

    test('an order naming an unjoined space does not break the list', () {
      final ordered = buildSpaceOrder(
        [_space('!a:matrix.org')],
        order: ['!gone:matrix.org', '!a:matrix.org'],
      );
      expect(ordered.map((r) => r.id), ['!a:matrix.org']);
    });

    test('an empty order leaves the natural order alone', () {
      final ordered = buildSpaceOrder(
        [_space('!a:matrix.org'), _space('!b:matrix.org')],
        order: const [],
      );
      expect(ordered.map((r) => r.id), ['!a:matrix.org', '!b:matrix.org']);
    });

    test('non-space rooms are excluded', () {
      final ordered = buildSpaceOrder(
        [_chat('!room:matrix.org')],
        order: const [],
      );
      expect(ordered, isEmpty);
    });
  });

  group('SpacesRail', () {
    testWidgets('labels each icon for assistive technology', (tester) async {
      await tester.pumpWidget(
        _rail(spaces: [_space('!s1:matrix.org')]),
      );
      await tester.pump();

      // The rail is icon-only, so the name has to reach a screen reader and
      // the tooltip. A rail with no accessible name at all would be unusable
      // with a screen reader, which is the one case where "the icon is
      // obvious" stops being true.
      expect(_labelsOf(tester), contains('Test Space'));
    });

    testWidgets('marks the selected space as selected', (tester) async {
      await tester.pumpWidget(
        _rail(
          spaces: [_space('!s1:matrix.org')],
          selectedId: '!s1:matrix.org',
          isSpaceSelected: true,
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.selected == true),
        isNotEmpty,
      );
    });

    testWidgets('does not mark a space selected when a chat is selected',
        (tester) async {
      // `selectedId` and `isSpaceSelected` are separate on purpose: the id is
      // null both when nothing is selected and when the selection is a chat,
      // and the rail must not light up a space in the second case.
      await tester.pumpWidget(
        _rail(
          spaces: [_space('!s1:matrix.org')],
          selectedId: '!room:matrix.org',
          isSpaceSelected: false,
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.selected == true),
        isEmpty,
      );
    });

    testWidgets('renders one icon per space', (tester) async {
      await tester.pumpWidget(
        _rail(
          spaces: [
            _space('!s1:matrix.org', name: 'One'),
            _space('!s2:matrix.org', name: 'Two'),
            _space('!s3:matrix.org', name: 'Three'),
          ],
        ),
      );
      await tester.pump();

      final labels = _labelsOf(tester);
      expect(labels, contains('One'));
      expect(labels, contains('Two'));
      expect(labels, contains('Three'));
    });

    testWidgets('is the rail token width', (tester) async {
      await tester.pumpWidget(_rail(spaces: const []));
      await tester.pump();

      expect(
        tester.getSize(find.byType(SpacesRail)).width,
        MoonrelayDesignTokens.navRailWidth,
      );
    });

    testWidgets('a space avatar or its initial is shown', (tester) async {
      await tester.pumpWidget(_rail(spaces: [_space('!s1:matrix.org')]));
      await tester.pump();

      // No avatar on the mock, so the initial path is what runs. Asserted
      // because the rail has no label to fall back on: an empty 48px box is
      // the failure mode.
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('the create button is at the bottom, not the top',
        (tester) async {
      await tester.pumpWidget(_rail(spaces: const []));
      await tester.pump();

      final railHeight = tester.getSize(find.byType(SpacesRail)).height;
      final create = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Add Space',
      );
      expect(create, findsOneWidget);
      // The button's centre should be in the bottom third of the rail.
      final y = tester.getCenter(create).dy;
      expect(y, greaterThan(railHeight * 0.66));
    });
  });

  group('RoomSearchQuery', () {
    test('clear empties both the notifier and the controller', () {
      // The two have to agree. A field that still shows text while the list
      // is unfiltered is the worst version of this bug: the user clears the
      // list and the query still looks applied.
      RoomSearchQuery.query.value = 'design';
      RoomSearchQuery.controller.text = 'design';
      RoomSearchQuery.clear();
      expect(RoomSearchQuery.query.value, isEmpty);
      expect(RoomSearchQuery.controller.text, isEmpty);
    });
  });
}