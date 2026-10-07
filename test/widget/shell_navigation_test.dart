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

// Drives the real navigation seam against a minimal route table.
//
// The defect this pins is a lifecycle one, not a rendering one: the room
// list used to be destroyed by `pushReplacement` on every room switch, so
// the single-pane shell's back button could only ever be a route reset.
// "The list is still on the stack afterwards" is therefore the assertion
// that matters, and it can only be made by inspecting the router's own
// `canPop` rather than by looking at pixels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:provider/provider.dart';

const String _roomId = '!abc:example.org';

/// Mounts a two-page router standing in for the room list and the room
/// chat, with the shell controller already committed to the shell that
/// [width] resolves to.
Future<GoRouter> pumpShell(
  WidgetTester tester, {
  required double width,
  bool provideShell = true,
}) async {
  final controller = LayoutShellController()
    ..resolve(rawWidth: width, layoutMode: LayoutMode.auto);

  final router = GoRouter(
    initialLocation: '/main/rooms',
    routes: <RouteBase>[
      GoRoute(
        path: '/main/rooms',
        builder: (_, __) => const Text('list'),
      ),
      GoRoute(
        path: '/main/rooms/:roomid',
        builder: (_, GoRouterState state) => Text(
          'room ${state.pathParameters['roomid']}',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  Widget app = MaterialApp.router(routerConfig: router);
  if (provideShell) {
    app = Provider<LayoutShellController>.value(
      value: controller,
      child: app,
    );
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('openRoom', () {
    testWidgets('keeps the room list on the stack in the single-pane shell',
        (tester) async {
      final router = await pumpShell(tester, width: 500);
      final context = tester.element(find.text('list'));

      openRoom(context, _roomId);
      await tester.pumpAndSettle();

      expect(find.text('room $_roomId'), findsOneWidget);
      // The load-bearing assertion. `push` leaves the list underneath, so
      // back is a real history step and the list keeps its scroll position
      // and any search text on it.
      expect(router.canPop(), isTrue);
    });

    testWidgets('replaces rather than stacking on the dashboard',
        (tester) async {
      final router = await pumpShell(tester, width: 1400);
      final context = tester.element(find.text('list'));

      openRoom(context, _roomId);
      await tester.pumpAndSettle();

      expect(find.text('room $_roomId'), findsOneWidget);
      // The dashboard always shows the list beside the room, so there is no
      // back affordance to offer and no history worth keeping.
      expect(router.canPop(), isFalse);
    });

    testWidgets('round-trips a room id that contains a percent sign',
        (tester) async {
      // A literal `%` is legal in a Matrix room id. GoRouter decodes path
      // parameters on the way out, so an unencoded id in the path would be
      // mangled or would throw.
      const String awkward = '!50%25:example.org';
      await pumpShell(tester, width: 500);
      final context = tester.element(find.text('list'));

      openRoom(context, awkward);
      await tester.pumpAndSettle();

      expect(find.text('room $awkward'), findsOneWidget);
    });

    testWidgets('falls back to replacing when no shell provider is present',
        (tester) async {
      // Widget tests and storybooks mount widgets without the shell
      // providers. The fallback has to be the pre-seam behaviour, so a
      // missing provider cannot change where the user lands.
      final router = await pumpShell(tester, width: 500, provideShell: false);
      final context = tester.element(find.text('list'));

      openRoom(context, _roomId);
      await tester.pumpAndSettle();

      expect(find.text('room $_roomId'), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets('switching rooms does not stack the second on the first',
        (tester) async {
      // The behaviour change, stated as a navigator's fact.
      //
      // Room A then room B leaves exactly one thing under B: the list. If
      // it left A as well, then Back from B would land on A, which is
      // strictly correct and is not what anyone means by Back in a chat
      // client. Switching conversation is a lateral move, not a step into
      // a new place, and walking back through rooms the user has already
      // read is what makes a list-backed shell feel like a trapdoor.
      final router = await pumpShell(tester, width: 500);
      const other = '!xyz:example.org';

      var context = tester.element(find.text('list'));
      openRoom(context, _roomId);
      await tester.pumpAndSettle();

      context = tester.element(find.text('room $_roomId'));
      openRoom(context, other);
      await tester.pumpAndSettle();

      expect(find.text('room $other'), findsOneWidget);
      // One step back, and it is the list rather than the room we were in.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('list'), findsOneWidget);
      expect(find.text('room $_roomId'), findsNothing);
    });

    testWidgets('a room sub-page still pushes over the chat it belongs to',
        (tester) async {
      // The narrowing must not reach sub-pages. "Already inside a room"
      // is the test for replacing a chat, and a room's settings, thread
      // and room-info pages are all inside the room flow. Replacing those
      // would make the chat's own back arrow skip past the sub-page, which
      // is the behaviour the user explicitly asked to keep.
      final router = await pumpShell(tester, width: 500);

      var context = tester.element(find.text('list'));
      openRoom(context, _roomId);
      await tester.pumpAndSettle();

      openRoomSubpage(context, _roomId, 'settings');
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('room $_roomId'), findsOneWidget);
    });
  });

  group('openRoomSubpage', () {
    testWidgets('pushes, so a back button is correct in both shells',
        (tester) async {
      for (final width in const [500.0, 1400.0]) {
        final router = await pumpShell(tester, width: width);
        final context = tester.element(find.text('list'));

        openRoomSubpage(context, _roomId, 'settings');
        await tester.pumpAndSettle();

        expect(router.canPop(), isTrue,
            reason: 'a sub-page is a drill-down at $width px');
      }
    });
  });

  group('backToRoomList', () {
    testWidgets('pops back to the list when there is history',
        (tester) async {
      final router = await pumpShell(tester, width: 500);
      final context = tester.element(find.text('list'));

      openRoom(context, _roomId);
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      // A fresh context under the current page, as a tap handler would have.
      backToRoomList(tester.element(find.textContaining('room')));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('falls back to the list on a cold deep link with no history',
        (tester) async {
      // A deep link into a room starts with nothing to pop. Reaching the
      // list has to work, and it is a route reset by necessity.
      final router = GoRouter(
        initialLocation: '/main/rooms/$_roomId',
        routes: <RouteBase>[
          GoRoute(
            path: '/main/rooms',
            builder: (_, __) => const Text('list'),
          ),
          GoRoute(
            path: '/main/rooms/:roomid',
            builder: (_, GoRouterState state) =>
                Text('room ${state.pathParameters['roomid']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      backToRoomList(tester.element(find.textContaining('room')));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
    });
  });

  group('closeToRoomList', () {
    testWidgets('discards the stack rather than walking it', (tester) async {
      // The deliberate opposite of `backToRoomList`. Back is one history
      // step; Close is an exit. The hub needs both, and the difference is
      // only visible if the stack is more than one deep, so this builds
      // one: list, room, sub-page.
      final router = await pumpShell(tester, width: 500);
      var context = tester.element(find.text('list'));

      openRoom(context, _roomId);
      await tester.pumpAndSettle();
      openRoomSubpage(context, _roomId, 'settings');
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      closeToRoomList(context);
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      // Nothing left to walk back into. If this were a pop the stack would
      // still hold the room.
      expect(router.canPop(), isFalse);
    });

    testWidgets('works from a cold deep link with no history', (tester) async {
      // Same reason `backToRoomList` needs its fallback: a deep link into a
      // room has nothing behind it, and Close still has to go somewhere.
      final router = GoRouter(
        initialLocation: '/main/rooms/$_roomId',
        routes: <RouteBase>[
          GoRoute(
            path: '/main/rooms',
            builder: (_, __) => const Text('list'),
          ),
          GoRoute(
            path: '/main/rooms/:roomid',
            builder: (_, GoRouterState state) =>
                Text('room ${state.pathParameters['roomid']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      closeToRoomList(tester.element(find.textContaining('room')));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
    });
  });
}
