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
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Mock extensions for the SDK types RoomPreviewScreen depends on
// ---------------------------------------------------------------------------

class MockGoRouter extends Mock implements GoRouter {}

class MockGoRouterState extends Mock implements GoRouterState {}

class MockGetRoomSummaryResponse extends Mock
    implements GetRoomSummaryResponse$3 {}

class MockGetRoomEventsResponse extends Mock implements GetRoomEventsResponse {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget wrapWithProviders(
    {required Widget child, Client? client, GoRouter? router}) {
  final effectiveRouter = router ??
      GoRouter(
        initialLocation: '/',
        routes: [GoRoute(path: '/', builder: (_, __) => child)],
      );
  return MultiProvider(
    providers: [
      Provider<Client>.value(value: client ?? MockClient()),
      Provider<Logger>.value(value: MockLogger()),
    ],
    child: MaterialApp.router(
      routerConfig: effectiveRouter,
      theme: testMoonrelayTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget wrapWithRouter({required Widget child, Client? client}) {
  return wrapWithProviders(child: child, client: client);
}

Future<void> main() async {
  // Ensure l10n is loaded.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Direction.b);
  });

  group('RoomPreviewScreen', () {
    late MockClient client;
    late MockGetRoomSummaryResponse mockSummary;

    setUp(() {
      client = MockClient();
      mockSummary = MockGetRoomSummaryResponse();
    });

    testWidgets('shows loading state initially', (tester) async {
      when(() => client.getRoomSummary(
                any(),
                via: any(named: 'via'),
              ))
          .thenAnswer(
              (_) => Future<GetRoomSummaryResponse$3>.value(mockSummary));

      when(() => client.getRoomEvents(
            any(),
            any(),
            limit: any(named: 'limit'),
          )).thenAnswer((_) => Future.value(MockGetRoomEventsResponse()));

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomPreviewScreen(roomId: '!test:example.org'),
        ),
      );

      // Should show the loading state immediately.
      expect(find.text('Loading room info…'), findsOneWidget);
    });

    testWidgets('shows room identity after summary loads', (tester) async {
      when(() => client.getRoomSummary(
            any(),
            via: any(named: 'via'),
          )).thenAnswer((_) async => mockSummary);

      when(() => client.getRoomEvents(
            any(),
            any(),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => MockGetRoomEventsResponse());

      when(() => mockSummary.roomId).thenReturn('!test:example.org');
      when(() => mockSummary.name).thenReturn('Test Room');
      when(() => mockSummary.topic).thenReturn('A room for testing');
      when(() => mockSummary.numJoinedMembers).thenReturn(42);
      when(() => mockSummary.joinRule).thenReturn('public');
      when(() => mockSummary.canonicalAlias).thenReturn('#test:example.org');
      when(() => mockSummary.avatarUrl).thenReturn(null);

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomPreviewScreen(roomId: '!test:example.org'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Room'), findsOneWidget);
      expect(find.text('!test:example.org'), findsOneWidget);
      expect(find.text('A room for testing'), findsOneWidget);
      expect(find.text('Public Room'), findsOneWidget);
      expect(find.textContaining('42'), findsWidgets);
      expect(find.text('You have not joined this room'), findsOneWidget);
      expect(find.text('Join Room'), findsOneWidget);
    });

    testWidgets('shows error card when summary fails', (tester) async {
      when(() => client.getRoomSummary(
            any(),
            via: any(named: 'via'),
          )).thenThrow(Exception('Server error'));

      when(() => client.getRoomEvents(
            any(),
            any(),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => MockGetRoomEventsResponse());

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomPreviewScreen(roomId: '!test:example.org'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Could not load room information'), findsOneWidget);
    });

    testWidgets('shows join button that joins', (tester) async {
      when(() => client.getRoomSummary(
            any(),
            via: any(named: 'via'),
          )).thenAnswer((_) async => mockSummary);

      when(() => mockSummary.roomId).thenReturn('!test:example.org');
      when(() => mockSummary.name).thenReturn('Test Room');
      when(() => mockSummary.numJoinedMembers).thenReturn(42);
      when(() => mockSummary.joinRule).thenReturn('public');
      when(() => mockSummary.avatarUrl).thenReturn(null);

      when(() => client.getRoomEvents(
            any(),
            any(),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => MockGetRoomEventsResponse());

      when(() => client.joinRoom(
            any(),
            via: any(named: 'via'),
          )).thenAnswer((_) async => '!test:example.org');

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomPreviewScreen(roomId: '!test:example.org'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Join Room'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => client.joinRoom(
            '!test:example.org',
            via: any(named: 'via'),
          )).called(1);
    });

    testWidgets('shows no messages section when events are empty',
        (tester) async {
      when(() => client.getRoomSummary(
            any(),
            via: any(named: 'via'),
          )).thenAnswer((_) async => mockSummary);

      when(() => mockSummary.roomId).thenReturn('!test:example.org');
      when(() => mockSummary.name).thenReturn('Test Room');
      when(() => mockSummary.numJoinedMembers).thenReturn(42);
      when(() => mockSummary.joinRule).thenReturn('public');
      when(() => mockSummary.avatarUrl).thenReturn(null);

      final mockEventsResponse = MockGetRoomEventsResponse();
      when(() => mockEventsResponse.chunk).thenReturn([]);
      when(() => client.getRoomEvents(
            any(),
            any(),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => mockEventsResponse);

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomPreviewScreen(roomId: '!test:example.org'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No recent messages to display'), findsOneWidget);
    });

    testWidgets('shows knock room label for knock rooms', (tester) async {
      when(() => client.getRoomSummary(
            any(),
            via: any(named: 'via'),
          )).thenAnswer((_) async => mockSummary);

      when(() => mockSummary.roomId).thenReturn('!test:example.org');
      when(() => mockSummary.name).thenReturn('Knock Room');
      when(() => mockSummary.numJoinedMembers).thenReturn(5);
      when(() => mockSummary.joinRule).thenReturn('knock');
      when(() => mockSummary.avatarUrl).thenReturn(null);

      when(() => client.getRoomEvents(
            any(),
            any(),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => MockGetRoomEventsResponse());

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: const RoomPreviewScreen(roomId: '!test:example.org'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Knock-based room'), findsOneWidget);
    });
  });
}
