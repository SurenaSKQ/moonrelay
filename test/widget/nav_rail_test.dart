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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/space_child.dart'
    show SpaceChild, SpaceParent;
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_rail.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/rail_group_header.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/room_search_field.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/space_context_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// Every accessible label the rail produced.
///
/// Asserted against the [Semantics] widgets rather than through
/// `find.bySemanticsLabel`, because that finder reads the composed semantics
/// tree and merges a [Tooltip]'s own node with the label below it. What
/// matters is the label the widget was told to publish.
/// The tile publishing [label].
///
/// Matches the [Semantics] *widget* rather than using
/// `find.bySemanticsLabel`, which reads the composed tree and misses a node
/// that has merged upward. Same reason as [_labelsOf].
Finder _tileLabelled(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

/// The tile's filled box, found by walking out from its label.
///
/// Descendant, not ancestor: the label's [Semantics] wraps the `InkResponse`
/// that wraps the animated box, so the box is below it.
Finder _tileBox(String label) => find
    .descendant(of: _tileLabelled(label), matching: find.byType(AnimatedContainer))
    .first;

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

/// Drives the real composition: [SpacesRailHost] over a [MockClient] and a
/// real [SpacePreferences].
///
/// The host rather than [SpacesRail] directly, because the thing worth
/// testing is that grouping *reacts*. The rail receives an already-built item
/// list, so a test that hands it one has frozen the grouping and cannot see
/// the collapse, the ungroup, or the reorder do anything. Going through the
/// host is also the only way to catch a host that stopped watching
/// [SpacePreferences], which is how grouping became invisible once already.
  /// The rail's accent fill, for asserting that a state is lit.
Color _railActive(WidgetTester tester) =>
  Theme.of(tester.element(find.byType(SpacesRail).first))
      .moonrelay
      .layers
      .railActive;

/// The fill of the tile carrying [label].
///
/// Reads the nearest enclosing `AnimatedContainer`'s decoration, which is
/// where the fill lives, rather than asserting on pixels. The tile is
/// private, so this is the closest a test can get without exporting it.
Color _tileFill(WidgetTester tester, String label) {
    final box = tester.widget<AnimatedContainer>(_tileBox(label));
    return (box.decoration! as BoxDecoration).color!;
  }
Client _clientWith(List<Room> spaces) {
  final client = MockClient();
  when(() => client.rooms).thenReturn(spaces);
  return client;
}

Widget _rail({
  required List<Room> spaces,
  String? selectedId,
  bool isSpaceSelected = false,
  SpacePreferences? spacePreferences,
  Client? client,
}) {
  final activeClient = client ?? _clientWith(spaces);
  final nav = NavigationState();
  if (isSpaceSelected && selectedId != null) nav.selectSpace(selectedId);
  return wrapWithProviders(
    client: activeClient,
    child: const Scaffold(body: SpacesRailHost()),
    navigationState: nav,
    spacePreferences: spacePreferences ?? SpacePreferences(SettingsService()),
  );
}

void main() {
  // `SpacePreferences` writes through `SharedPreferences` on every mutation,
  // and without a mock the plugin channel never answers, so an `await` on a
  // collapse hangs the test rather than failing it.
  SharedPreferences.setMockInitialValues({});
  setUp(RoomSearchQuery.clear);

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
      //
      // Asserted against the space's own name rather than against "nothing is
      // selected". The rail now carries the two built-in destinations above a
      // divider, and one of them is always selected, so the old form of this
      // assertion passed only because the rail did not exist yet.
      await tester.pumpWidget(
        _rail(
          spaces: [_space('!s1:matrix.org')],
          selectedId: '!room:matrix.org',
          isSpaceSelected: false,
        ),
      );
      await tester.pump();

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .map((s) => s.properties.label)
          .toList();
      expect(selected, isNot(contains('Test Space')));
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

    testWidgets('a space avatar goes through the shared authenticated widget',
        (tester) async {
      // The rail used to load space avatars with a bare `Image.network`, which
      // sends no Authorization header. Every homeserver that does not serve
      // media publicly answered 401 and the rail fell back to its letter, so
      // moving spaces out of the sidebar quietly turned a column of avatars
      // into a column of initials.
      //
      // The header itself is not observable from a widget test: Flutter's
      // `NetworkImage` opens its own HTTP connection rather than going
      // through the Matrix client's, and `flutter_test` replaces it wholesale.
      // `test/unit/authenticated_media_test.dart` guards the header as a
      // source invariant instead; this asserts that the rail is using the
      // widget that carries it, rather than re-implementing the load.
      final uri = Uri.parse('mxc://matrix.org/spaceavatar');
      final space = _space('!s1:matrix.org');
      when(() => space.avatar).thenReturn(uri);

      await tester.pumpWidget(_rail(spaces: [space]));
      await tester.pump();

      final avatar = tester.widget<AvatarFromUriOrFallbackImage>(
        find.byType(AvatarFromUriOrFallbackImage),
      );
      expect(avatar.avatarUri, uri);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a space with no avatar falls back to its letter',
        (tester) async {
      await tester.pumpWidget(_rail(spaces: [_space('!s1:matrix.org')]));
      await tester.pump();

      // The letter is the placeholder now, not the person silhouette the
      // shared widget defaults to: a grey person in a column of space icons
      // is a picture of nothing.
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

    testWidgets('a grouped space still renders, inside its group',
        (tester) async {
      final prefs = SpacePreferences(SettingsService());
      await prefs.createGroup('_grp_!root:matrix.org', [
        '!a:matrix.org',
        '!b:matrix.org',
      ]);

      await tester.pumpWidget(_rail(
        spaces: [
          _space('!a:matrix.org', name: 'Inside'),
          _space('!b:matrix.org', name: 'Also inside'),
        ],
        spacePreferences: prefs,
      ));
      await tester.pump();

      // The regression this guards is the one that shipped: flattening
      // groups left the icons but dropped everything else, so a user's
      // grouping became invisible with no way to undo it.
      expect(_labelsOf(tester), contains('Inside'));
      expect(_labelsOf(tester), contains('Also inside'));
    });

    testWidgets('a group header is drawn, with its count', (tester) async {
      final prefs = SpacePreferences(SettingsService());
      await prefs.createGroup('_grp_!root:matrix.org', [
        '!a:matrix.org',
        '!b:matrix.org',
      ]);

      await tester.pumpWidget(_rail(
        spaces: [_space('!a:matrix.org'), _space('!b:matrix.org')],
        spacePreferences: prefs,
      ));
      await tester.pump();

      // The count is the header's whole job: at 72px there is no room for
      // the group's name, so "how much is behind this" has to be visible or
      // the header is just an unexplained bar.
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(RailGroupHeader), findsOneWidget);
    });

    testWidgets('a collapsed group hides its children', (tester) async {
      final prefs = SpacePreferences(SettingsService());
      await prefs.createGroup('_grp_!root:matrix.org', [
        '!a:matrix.org',
        '!b:matrix.org',
      ]);
      await prefs.toggleGroupCollapsed('_grp_!root:matrix.org');

      await tester.pumpWidget(_rail(
        spaces: [
          _space('!a:matrix.org', name: 'Hidden'),
          _space('!b:matrix.org', name: 'Also hidden'),
        ],
        spacePreferences: prefs,
      ));
      await tester.pump();

      expect(find.byType(RailGroupHeader), findsOneWidget);
      expect(_labelsOf(tester), isNot(contains('Hidden')));
      expect(_labelsOf(tester), isNot(contains('Also hidden')));
      // The count survives the collapse. A collapsed group that hides its
      // count is indistinguishable from an empty one.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tapping the header collapses and expands the group',
        (tester) async {
      final prefs = SpacePreferences(SettingsService());
      await prefs.createGroup('_grp_!root:matrix.org', ['!a:matrix.org']);

      await tester.pumpWidget(_rail(
        spaces: [_space('!a:matrix.org', name: 'Visible')],
        spacePreferences: prefs,
      ));
      await tester.pump();
      expect(_labelsOf(tester), contains('Visible'));

      await tester.tap(find.byType(RailGroupHeader));
      await tester.pumpAndSettle();
      expect(_labelsOf(tester), isNot(contains('Visible')));

      await tester.tap(find.byType(RailGroupHeader));
      await tester.pumpAndSettle();
      expect(_labelsOf(tester), contains('Visible'));
    });

    testWidgets('grouped and ungrouped icons share one column',
        (tester) async {
      // The geometry claim in the rail's doc comment: a group block's
      // padding is chosen so its children land on the same pixels as a
      // standalone icon. If this drifts, the rail looks like it has two
      // different widths of icon in it.
      final prefs = SpacePreferences(SettingsService());
      await prefs.createGroup('_grp_!root:matrix.org', ['!a:matrix.org']);

      await tester.pumpWidget(_rail(
        spaces: [
          _space('!a:matrix.org', name: 'Grouped'),
          _space('!z:matrix.org', name: 'Loose'),
        ],
        spacePreferences: prefs,
      ));
      await tester.pump();

      final grouped = tester.getTopLeft(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Grouped',
        ),
      );
      final loose = tester.getTopLeft(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Loose',
        ),
      );
      expect(grouped.dx, closeTo(loose.dx, 0.5));
    });

    testWidgets('a group header is reachable as a right-click target',
        (tester) async {
      // The menu is how "ungroup all" and "sort into groups" are reached, and
      // for a while it had no call site at all. Asserting the gesture exists
      // is what stops it becoming dead code again.
      final prefs = SpacePreferences(SettingsService());
      await prefs.createGroup('_grp_!root:matrix.org', ['!a:matrix.org']);

      await tester.pumpWidget(_rail(
        spaces: [_space('!a:matrix.org')],
        spacePreferences: prefs,
      ));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RailGroupHeader),
          matching: find.byType(SpaceContextMenu),
        ),
        findsOneWidget,
      );
    });
  });

  group('the built-in destinations', () {
    testWidgets('Home and All Rooms are in the rail and named', (tester) async {
      await tester.pumpWidget(_rail(spaces: [_space('!s1:matrix.org')]));
      await tester.pump();

      // They used to be reachable only from a two-way toggle inside the room
      // pane. They are the two things a user opens the app to choose between,
      // and a rail that lists spaces without them makes both of them feel like
      // settings.
      final labels = _labelsOf(tester);
      expect(labels, contains('Friends'));
      expect(labels, contains('Rooms'));
    });

    testWidgets('they sit above the spaces, not among them', (tester) async {
      // A destination below the user's own spaces reads as another space, and
      // scrolls away with them.
      await tester.pumpWidget(_rail(spaces: [_space('!s1:matrix.org')]));
      await tester.pump();

      final friends = tester.getTopLeft(_tileLabelled('Friends')).dy;
      final space = tester.getTopLeft(_tileLabelled('Test Space')).dy;
      expect(friends, lessThan(space));
    });

    testWidgets('exactly one destination is lit at a time', (tester) async {
      await tester.pumpWidget(
        _rail(
          spaces: [_space('!s1:matrix.org')],
          selectedId: '!s1:matrix.org',
          isSpaceSelected: true,
        ),
      );
      await tester.pump();

      // Picking a space has to clear the built-in destinations. If it did not,
      // the rail would show three selected tiles and mean nothing.
      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .map((s) => s.properties.label)
          .toList();
      expect(selected, ['Test Space']);
    });

    testWidgets('the default destination is All Rooms, and it is lit',
        (tester) async {
      await tester.pumpWidget(_rail(spaces: [_space('!s1:matrix.org')]));
      await tester.pump();

      // `NavigationState` opens on "every room", so the rail has to say so. A
      // rail that showed nothing lit on a cold start left the user unable to
      // tell which of the three lists they were looking at.
      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .map((s) => s.properties.label)
          .toList();
      expect(selected, ['Rooms']);
    });

    testWidgets('tapping Home switches the destination and leaves any space',
        (tester) async {
      final nav = NavigationState();

      // A real router, because the tile navigates as well as switching. It has
      // to: switching the destination while a space home page is on screen
      // would change the filter behind a page the user cannot see.
      final router = GoRouter(
        initialLocation: '/main/rooms',
        routes: [
          GoRoute(
            path: '/main/rooms',
            builder: (_, __) => const Scaffold(body: SpacesRailHost()),
          ),
          GoRoute(
            path: '/main/space/:id',
            builder: (_, __) => const Scaffold(body: SpacesRailHost()),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => wrapWithProviders(
            client: _clientWith([_space('!s1:matrix.org')]),
            child: child!,
            navigationState: nav,
            spacePreferences: SpacePreferences(SettingsService()),
          ),
        ),
      );
      await tester.pump();
      expect(nav.isAll, isTrue);

      await tester.tap(_tileLabelled('Friends'));
      await tester.pump();

      expect(nav.isHome, isTrue);
      expect(nav.isAll, isFalse);
    });
  });

  group('hover is the accent, not a grey wash', () {
    testWidgets('a hovered tile fills with the rail accent', (tester) async {
      await tester.pumpWidget(_rail(spaces: [_space('!s1:matrix.org')]));
      await tester.pump();

      final rail = _railActive(tester);
      expect(_tileFill(tester, 'Test Space'), isNot(rail));

      // A mouse gesture rather than a bare event: a `PointerHoverEvent` sent to
      // the binding is never hit-tested, so nothing dispatches an enter to the
      // `MouseRegion` and the test would pass against a widget that does not
      // react to hover at all.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(_tileLabelled('Test Space')),
      );
      await tester.pump();
      await tester.pump(MoonrelayDesignTokens.standard().durationFast);

      // The old behaviour was a neutral wash one step off the resting fill, so
      // hovering told the user nothing about whether the tile was reachable.
      expect(_tileFill(tester, 'Test Space'), rail);
      await mouse.removePointer();
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



