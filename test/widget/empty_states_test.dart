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
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/profile_delegate.dart';
import 'package:moonrelay/src/helpers/room_delegate.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';

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

  group('ProfileDelegate error states', () {
    testWidgets('null userid shows an error state instead of a blank pane',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const ProfileDelegate(userid: null)),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      // The localized error heading is rendered.
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('malformed userid shows the invalid-id error state',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const ProfileDelegate(userid: 'not-a-user')),
      );

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('valid userid does not short-circuit into the error state',
        (tester) async {
      // No network is needed: we only assert the delegate did NOT
      // short-circuit into the error state.
      await tester.pumpWidget(
        wrapWithProviders(child: const ProfileDelegate(userid: '@alice:example.org')),
      );

      expect(find.byType(EmptyState), findsNothing);
    });
  });

  group('RoomDelegate empty/error states', () {
    testWidgets('null room id shows an error state', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const RoomDelegate(roomID: null)),
      );
      // Flush the post-frame SyncPulse lookup (no-ops without a SyncPulse).
      await tester.pump();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });

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
          child: const RoomDelegate(roomID: '!missing:example.org'),
        ),
      );
      await tester.pump();

      // The content is the existing preview screen (not a blank splash).
      expect(find.byType(RoomPreviewScreen), findsOneWidget);
    });
  });
}
