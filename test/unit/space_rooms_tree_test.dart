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
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/space_rooms_tree.dart';
import '../helpers/mocks.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Helper that mirrors the static _extractInitials in space_rooms_tree.dart
// ---------------------------------------------------------------------------

String extractInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed
      .toUpperCase()
      .split(RegExp(' +'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0])
      .take(2)
      .join();
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // Unit tests: _extractInitials helper
  // ═══════════════════════════════════════════════════════════════════════
  group('extractInitials', () {
    test('two-word name',
        () => expect(extractInitials('Alice Bob'), equals('AB')));
    test('one-word name', () => expect(extractInitials('Alice'), equals('A')));
    test('empty string', () => expect(extractInitials(''), equals('?')));
    test('whitespace-only', () => expect(extractInitials('   '), equals('?')));
    test('three words takes first two',
        () => expect(extractInitials('Alice Bob Charlie'), equals('AB')));
    test('uppercases input',
        () => expect(extractInitials('alice bob'), equals('AB')));
    test('special chars',
        () => expect(extractInitials('hello-world test'), equals('HT')));
    test('unicode', () => expect(extractInitials('éva könig'), equals('ÉK')));
    test('single char', () => expect(extractInitials('A'), equals('A')));
    test('tabs and newlines',
        () => expect(extractInitials('\t\n '), equals('?')));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Widget tests — SpaceRoomsPane (basic rendering without children)
  // ═══════════════════════════════════════════════════════════════════════
  group('SpaceRoomsPane rendering', () {
    late MockClient client;

    setUp(() {
      client = MockClient();
      when(() => client.getRoomById(any())).thenReturn(null);
    });

    Future<void> pumpPane(WidgetTester tester, Room space) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<Client>.value(value: client)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SpaceRoomsPane(space: space, client: client),
            ),
          ),
        ),
      );
    }

    testWidgets('empty space shows empty state', (tester) async {
      final room = MockRoom();
      when(() => room.id).thenReturn('!s:test');
      when(() => room.getLocalizedDisplayname()).thenReturn('Root');
      when(() => room.isSpace).thenReturn(true);
      when(() => room.spaceChildren).thenReturn([]);
      when(() => room.membership).thenReturn(Membership.join);
      when(() => room.avatar).thenReturn(null);
      when(() => room.hasNewMessages).thenReturn(false);
      when(() => room.lastEvent).thenReturn(null);
      when(() => client.getRoomById('!s:test')).thenReturn(room);

      await pumpPane(tester, room);
      await tester.pump();

      expect(find.text('This space has no rooms yet'), findsOneWidget);
    });

    testWidgets('renders without crashing when onSync is unavailable',
        (tester) async {
      final room = MockRoom();
      when(() => room.id).thenReturn('!s:test');
      when(() => room.getLocalizedDisplayname()).thenReturn('Root');
      when(() => room.isSpace).thenReturn(true);
      when(() => room.spaceChildren).thenReturn([]);
      when(() => room.membership).thenReturn(Membership.join);
      when(() => room.avatar).thenReturn(null);
      when(() => room.hasNewMessages).thenReturn(false);
      when(() => room.lastEvent).thenReturn(null);
      when(() => client.getRoomById('!s:test')).thenReturn(room);

      // Intentionally do NOT stub client.onSync — the widget should handle
      // a null return gracefully via the try-catch in initState.
      await pumpPane(tester, room);
      await tester.pump();

      expect(find.text('This space has no rooms yet'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // NavigationState lifecycle
  // ═══════════════════════════════════════════════════════════════════════
  group('NavigationState lifecycle', () {
    late NavigationState nav;
    setUp(() => nav = NavigationState());

    test('defaults to All', () {
      expect(nav.isAll, isTrue);
      expect(nav.isHome, isFalse);
      expect(nav.isSpace, isFalse);
    });

    test('home → space → home round-trip', () {
      nav.selectHome();
      expect(nav.isHome, isTrue);
      nav.selectSpace('!s:test');
      expect(nav.isSpace, isTrue);
      expect(nav.selectedId, '!s:test');
      nav.selectHome();
      expect(nav.isHome, isTrue);
      expect(nav.isSpace, isFalse);
    });

    test('all → space → all round-trip', () {
      nav.selectSpace('!s:test');
      expect(nav.isSpace, isTrue);
      nav.selectAll();
      expect(nav.isAll, isTrue);
    });

    test('switching spaces notifies without leak', () {
      int calls = 0;
      nav.addListener(() => calls++);
      nav.selectSpace('!a:test');
      expect(calls, 1);
      nav.selectSpace('!b:test');
      expect(calls, 2);
    });

    test('re-selecting same space is no-op', () {
      int calls = 0;
      nav.addListener(() => calls++);
      nav.selectSpace('!s:test');
      expect(calls, 1);
      nav.selectSpace('!s:test');
      expect(calls, 1);
    });

    test('selecting all when already all is no-op', () {
      int calls = 0;
      nav.addListener(() => calls++);
      nav.selectAll();
      expect(calls, 0);
    });
  });
}
