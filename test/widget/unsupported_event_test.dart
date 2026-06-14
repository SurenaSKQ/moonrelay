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
import 'package:moonrelay/src/chat/events/unsupported_event.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  group('UnsupportedEventType', () {
    testWidgets('displays event type and message type', (tester) async {
      final event = MockEvent();
      final sender = MockUser();

      when(() => event.type).thenReturn('m.room.member');
      when(() => event.messageType).thenReturn('');
      when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
      when(() => event.content).thenReturn({});
      when(() => sender.calcDisplayname()).thenReturn('TestUser');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnsupportedEventType(event: event),
          ),
        ),
      );

      expect(find.textContaining('TestUser'), findsOneWidget);
      expect(find.textContaining('m.room.member'), findsOneWidget);
    });
  });
}
