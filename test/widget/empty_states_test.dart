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
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/profile_view.dart';
import 'package:moonrelay/src/widgets/room_resolver.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  group('EmptyState', () {
    const title = 'Something went wrong';
    const msg = 'No room to show here.';

    testWidgets('renders icon, title and message without an action',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: title,
              message: msg,
            ),
          ),
        ),
      );

      expect(find.text(title), findsOneWidget);
      expect(find.text(msg), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders an action button when onAction is provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: title,
              message: msg,
              actionLabel: 'Back',
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('Back'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('ProfileView error states', () {
    testWidgets('malformed userid shows the invalid-id error state',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const ProfileView(userId: 'not-a-user')),
      );

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('valid userid does not short-circuit into the error state',
        (tester) async {
      // No network is needed: we only assert the view did NOT short-circuit
      // into the error state.
      await tester.pumpWidget(
        wrapWithProviders(child: const ProfileView(userId: '@alice:example.org')),
      );

      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('an empty userid is an error state, not a blank pane',
        (tester) async {
      // `/main/myprofile` used to reach this widget with a null id and get
      // an error card on the user's own profile. The router now resolves
      // the signed-in id, so an empty value can only mean a broken route.
      await tester.pumpWidget(
        wrapWithProviders(child: const ProfileView(userId: '')),
      );

      expect(find.byType(EmptyState), findsOneWidget);
    });
  });

  group('RoomResolver empty/error states', () {
    testWidgets('empty room id shows the not-found message', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const RoomResolver(roomId: '')),
      );
      // Flush the post-frame SyncPulse lookup (no-ops without a SyncPulse).
      await tester.pump();

      expect(find.text('Room not found'), findsOneWidget);
    });

    // The "room is in the sync cache" branch is a single `room != null`
    // check and is exercised for real by test/widget/router_test.dart, which
    // drives the whole route table. Stubbing RoomPage's subtree here would
    // be brittle mock scaffolding for no extra signal.

    testWidgets('not-joined room hands off to the room preview screen',
        (tester) async {
      final client = MockClient();
      when(() => client.rooms).thenReturn([MockRoom()]);
      when(() => client.getRoomById('!missing:example.org')).thenReturn(null);
      // Preview screen will try to resolve the room; force the summary
      // fetch to fail so it renders its own error card instead of crashing
      // on a null summary.
      when(() => client.getRoomSummary('!missing:example.org', via: null))
          .thenThrow(Exception('preview unavailable'));

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomResolver(roomId: '!missing:example.org'),
        ),
      );
      await tester.pump();

      // The content is the existing preview screen (not a blank splash).
      expect(find.byType(RoomPreviewScreen), findsOneWidget);
    });

    testWidgets('an empty sync cache waits rather than claiming not-found',
        (tester) async {
      // This is the cold deep-link case: the room may simply not have
      // arrived yet, so the resolver must not tell the user it is missing.
      final client = MockClient();
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.getRoomById('!cold:example.org')).thenReturn(null);

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomResolver(roomId: '!cold:example.org'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(RoomPreviewScreen), findsNothing);
    });
  });
}
