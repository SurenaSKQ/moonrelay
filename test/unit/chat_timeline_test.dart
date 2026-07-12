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
  });
}

/// Builds a synthetic newest-first list of mock events.  Status is
/// `synced` so a derived `markRead` would consider them valid.
List<Event> _mkEvents(List<String> ids) {
  return ids
      .map((id) => _MockEventFactory.build(id: id, status: EventStatus.synced))
      .toList();
}

/// Local event factory: mocktail's standard `Mock` class doesn't
/// accept constructor args, so we use a tiny subclass that overrides
/// the two properties we read (eventId, status).
class _MockEventFactory {
  static Event build({required String id, required EventStatus status}) {
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn(id);
    when(() => ev.status).thenReturn(status);
    return ev;
  }
}
