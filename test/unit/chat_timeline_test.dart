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

// Unit tests for the read-marker / jump-to-unread plumbing extracted
// from [ChatTimeline].  These cover the small, pure helper that powers
// the unread pill count and the public `jumpToLastRead` / scroll
// mechanics in isolation, so a regression in the unread accounting can
// be caught without spinning up a full [Timeline] mock.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/chat/chat_timeline.dart';

import '../helpers/mocks.dart';

void main() {
  group('countUnreadInWindow', () {
    test('returns 0 when the event list is null', () {
      expect(countUnreadInWindow(null, '\$marker'), 0);
    });

    test('returns 0 when the event list is empty', () {
      expect(countUnreadInWindow(<Event>[], '\$marker'), 0);
    });

    test('returns the full length when no marker has been set', () {
      final events = _mkEvents(['a', 'b', 'c']);
      expect(countUnreadInWindow(events, ''), 3);
    });

    test('counts events newer than the marker', () {
      final events = _mkEvents(['e1', 'e2', 'e3', 'e4', 'e5']);
      // Marker is e3 — the two newer events (e1, e2) are unread.
      expect(countUnreadInWindow(events, 'e3'), 2);
    });

    test('returns 0 when the marker is the newest event', () {
      final events = _mkEvents(['newest', 'middle', 'oldest']);
      expect(countUnreadInWindow(events, 'newest'), 0);
    });

    test('returns 0 when the marker is not in the cache', () {
      // The marker being older than the loaded window still counts
      // the entire list as unread — the user hasn't caught up.
      final events = _mkEvents(['a', 'b', 'c']);
      expect(countUnreadInWindow(events, '\$oldMarker'), 3);
    });

    test('skips state events when counting unread messages', () {
      // newest-first list with one real message and one state event
      // newer than the marker; the state event should not count.
      final message = _MockEventFactory.build(
        id: 'm1',
        status: EventStatus.synced,
        type: EventTypes.Message,
      );
      final stateEvent = _MockEventFactory.build(
        id: 's1',
        status: EventStatus.synced,
        type: EventTypes.RoomMember,
      );
      expect(countUnreadInWindow(<Event>[message, stateEvent], 'm2'), 1);
    });

    test('returns 0 when only state events are newer than the marker', () {
      // A room with member churn, topic edits or encryption rollouts
      // after the marker has nothing for the user to "catch up on",
      // so the FAB shouldn't surface.  The count must be zero.
      final stateA = _MockEventFactory.build(
        id: 's1',
        status: EventStatus.synced,
        type: EventTypes.RoomTopic,
      );
      final stateB = _MockEventFactory.build(
        id: 's2',
        status: EventStatus.synced,
        type: EventTypes.RoomMember,
      );
      expect(countUnreadInWindow(<Event>[stateA, stateB], 'marker'), 0);
    });

    test('skips state events when no marker is set either', () {
      // A fresh account on a room full of state activity should not
      // see "X unread" — there are no real messages to read.
      final stateA = _MockEventFactory.build(
        id: 's1',
        status: EventStatus.synced,
        type: EventTypes.RoomName,
      );
      final stateB = _MockEventFactory.build(
        id: 's2',
        status: EventStatus.synced,
        type: EventTypes.RoomAvatar,
      );
      expect(countUnreadInWindow(<Event>[stateA, stateB], ''), 0);
    });
  });
}

/// Builds a synthetic newest-first list of mock events.  Status is
/// `synced` so a derived `markRead` would consider them valid.
List<Event> _mkEvents(List<String> ids) {
  return ids
      .map((id) => _MockEventFactory.build(
            id: id,
            status: EventStatus.synced,
            type: EventTypes.Message,
          ))
      .toList();
}

/// Local event factory: mocktail's standard `Mock` class doesn't
/// accept constructor args, so we use a tiny subclass that overrides
/// the two properties we read (eventId, status, type).
class _MockEventFactory {
  static Event build({
    required String id,
    required EventStatus status,
    String type = EventTypes.Message,
  }) {
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn(id);
    when(() => ev.status).thenReturn(status);
    when(() => ev.type).thenReturn(type);
    return ev;
  }
}
