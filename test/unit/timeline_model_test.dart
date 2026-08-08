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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/chat/timeline_model.dart';

// -- Test event builder --
// Provides concrete field values on a Mocktail Mock so we don't need
// 20 `when(() => ev.field).thenReturn(...)` calls per event.

class _TestEvent extends Mock implements Event {
  _TestEvent({
    required this.eventId,
    required this.type,
    required this.senderId,
    required this.originServerTs,
    this.messageType = MessageTypes.Text,
    this.relationshipEventId,
    this.relationshipType,
  });

  @override
  final String eventId;

  @override
  final String type;

  @override
  final String senderId;

  @override
  final DateTime originServerTs;

  @override
  String messageType;

  @override
  String? relationshipEventId;

  @override
  String? relationshipType;
}

class _StubTimeline extends Mock implements Timeline {
  _StubTimeline(this._events);
  final List<Event> _events;
  @override
  List<Event> get events => _events;
}

// -- isStateEvent --

void main() {
  group('isStateEvent', () {
    final now = DateTime(2024, 6, 15, 10, 0, 0);

    test('returns false for m.room.message', () {
      final ev = _TestEvent(
        eventId: 'msg',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: now,
      );
      expect(isStateEvent(ev), isFalse);
    });

    test('returns false for m.sticker', () {
      final ev = _TestEvent(
        eventId: 'sticker',
        type: EventTypes.Sticker,
        senderId: '@alice:dom',
        originServerTs: now,
        messageType: MessageTypes.Sticker,
      );
      expect(isStateEvent(ev), isFalse);
    });

    test('returns false for m.room.encrypted (the bug fix)', () {
      final ev = _TestEvent(
        eventId: 'enc',
        type: EventTypes.Encrypted,
        senderId: '@alice:dom',
        originServerTs: now,
      );
      expect(isStateEvent(ev), isFalse);
    });

    test('returns true for m.room.member', () {
      final ev = _TestEvent(
        eventId: 'member',
        type: EventTypes.RoomMember,
        senderId: '@alice:dom',
        originServerTs: now,
      );
      expect(isStateEvent(ev), isTrue);
    });

    test('returns true for m.room.name', () {
      final ev = _TestEvent(
        eventId: 'name',
        type: EventTypes.RoomName,
        senderId: '@alice:dom',
        originServerTs: now,
      );
      expect(isStateEvent(ev), isTrue);
    });

    test('returns true for m.room.topic', () {
      final ev = _TestEvent(
        eventId: 'topic',
        type: EventTypes.RoomTopic,
        senderId: '@alice:dom',
        originServerTs: now,
      );
      expect(isStateEvent(ev), isTrue);
    });

    test('returns true for m.room.encryption', () {
      final ev = _TestEvent(
        eventId: 'enc_setup',
        type: EventTypes.Encryption,
        senderId: '@alice:dom',
        originServerTs: now,
      );
      expect(isStateEvent(ev), isTrue);
    });
  });

  group('isContentEvent', () {
    test('is the inverse of isStateEvent', () {
      final stateEv = _TestEvent(
        eventId: 'name',
        type: EventTypes.RoomName,
        senderId: '@alice:dom',
        originServerTs: DateTime(2024, 1, 1),
      );
      final contentEv = _TestEvent(
        eventId: 'msg',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: DateTime(2024, 1, 1),
      );
      expect(isContentEvent(stateEv), !isStateEvent(stateEv));
      expect(isContentEvent(contentEv), !isStateEvent(contentEv));
    });
  });

  // -- isContinuation --

  group('isContinuation', () {
    final baseTime = DateTime(2024, 6, 15, 10, 0, 0);

    test('returns true for same sender within 10 minutes', () {
      final newer = _TestEvent(
        eventId: 'n1',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime,
      );
      final older = _TestEvent(
        eventId: 'o1',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime.add(const Duration(minutes: 5)),
      );
      expect(isContinuation(newer, older), isTrue);
    });

    test('returns false for different senders', () {
      final newer = _TestEvent(
        eventId: 'n2',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime,
      );
      final older = _TestEvent(
        eventId: 'o2',
        type: EventTypes.Message,
        senderId: '@bob:dom',
        originServerTs: baseTime.add(const Duration(minutes: 3)),
      );
      expect(isContinuation(newer, older), isFalse);
    });

    test('returns false when more than 10 minutes apart', () {
      final newer = _TestEvent(
        eventId: 'n3',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime.add(const Duration(minutes: 11)),
      );
      final older = _TestEvent(
        eventId: 'o3',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime,
      );
      expect(isContinuation(newer, older), isFalse);
    });

    test('returns false when either is a sticker', () {
      final newer = _TestEvent(
        eventId: 'n4',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime,
        messageType: MessageTypes.Sticker,
      );
      final older = _TestEvent(
        eventId: 'o4',
        type: EventTypes.Message,
        senderId: '@alice:dom',
        originServerTs: baseTime.add(const Duration(minutes: 3)),
      );
      expect(isContinuation(newer, older), isFalse);
    });
  });

  // -- visibleIndices --

  group('visibleIndices', () {
    test('includes standalone events with null relationshipEventId', () {
      final events = [
        _TestEvent(
          eventId: 'a',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
          relationshipEventId: null,
        ),
        _TestEvent(
          eventId: 'b',
          type: EventTypes.Message,
          senderId: '@b:dom',
          originServerTs: DateTime(2024, 1, 1),
          relationshipEventId: null,
        ),
      ];
      expect(visibleIndices(events, null), [0, 1]);
    });

    test('excludes thread replies (non-self relationship)', () {
      final events = [
        _TestEvent(
          eventId: 'thread_root',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
          relationshipEventId: 'thread_root',
          relationshipType: RelationshipTypes.thread,
        ),
        _TestEvent(
          eventId: 'thread_reply',
          type: EventTypes.Message,
          senderId: '@b:dom',
          originServerTs: DateTime(2024, 1, 1),
          relationshipEventId: 'thread_root',
          relationshipType: RelationshipTypes.thread,
        ),
      ];
      final result = visibleIndices(events, null);
      // Thread root is self-referencing -> visible
      // Thread reply references a different event -> not visible
      expect(result, [0]);
    });

    test('includes thread roots (self-referencing)', () {
      final events = [
        _TestEvent(
          eventId: 'root',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
          relationshipEventId: 'root',
          relationshipType: RelationshipTypes.thread,
        ),
      ];
      expect(visibleIndices(events, null), [0]);
    });

    test('applies custom filter when provided', () {
      final events = [
        _TestEvent(
          eventId: 'keep',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
        ),
        _TestEvent(
          eventId: 'drop',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
        ),
      ];
      expect(
        visibleIndices(events, (e) => e.eventId == 'keep'),
        [0],
      );
    });
  });

  // -- countUndecryptable --

  group('countUndecryptable', () {
    test('counts only visible encrypted events', () {
      final events = [
        _TestEvent(
          eventId: 'enc1',
          type: EventTypes.Encrypted,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
        ),
        _TestEvent(
          eventId: 'msg1',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
        ),
        _TestEvent(
          eventId: 'enc2',
          type: EventTypes.Encrypted,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
        ),
      ];
      expect(countUndecryptable(events, null), 2);
    });

    test('skips non-visible events when no filter', () {
      final events = [
        _TestEvent(
          eventId: 'reply',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
          relationshipEventId: 'parent',
        ),
        _TestEvent(
          eventId: 'enc',
          type: EventTypes.Encrypted,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 1, 1),
        ),
      ];
      expect(countUndecryptable(events, null), 1);
    });
  });

  // -- buildTimelineItems --

  group('buildTimelineItems', () {
    test('returns only the undecryptable banner for an empty timeline', () {
      final result = buildTimelineItems(_StubTimeline([]));
      expect(result.items.length, 1);
      expect(result.items[0].kind, TimelineItemKind.undecryptableBanner);
      expect(result.items[0].undecryptableCount, 0);
      expect(result.undecryptableCount, 0);
      expect(result.eventIdToItemIndex, isEmpty);
    });

    test('renders a single message event', () {
      final events = [
        _TestEvent(
          eventId: 'msg',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // [banner, event]
      expect(result.items.length, 2);
      expect(result.items[0].kind, TimelineItemKind.undecryptableBanner);
      expect(result.items[1].kind, TimelineItemKind.event);
      expect(result.items[1].event!.eventId, 'msg');
      expect(result.items[1].isGroupStart, isTrue);
      expect(result.items[1].isGroupContinuation, isFalse);
      expect(result.eventIdToItemIndex['msg'], 0);
    });

    test('groups consecutive same-sender events within 10 min', () {
      final events = [
        // newest first
        _TestEvent(
          eventId: 'newer',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 5, 0),
        ),
        _TestEvent(
          eventId: 'older',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // [banner, newer(continuation), older(groupStart)]
      expect(result.items.length, 3);
      final newerEntry = result.items[1];
      expect(newerEntry.kind, TimelineItemKind.event);
      expect(newerEntry.isGroupStart, isFalse);
      expect(newerEntry.isGroupContinuation, isTrue);
      final olderEntry = result.items[2];
      expect(olderEntry.kind, TimelineItemKind.event);
      expect(olderEntry.isGroupStart, isTrue);
      expect(olderEntry.isGroupContinuation, isFalse);
    });

    test('does not group across different senders', () {
      final events = [
        _TestEvent(
          eventId: 'alice_msg',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 5, 0),
        ),
        _TestEvent(
          eventId: 'bob_msg',
          type: EventTypes.Message,
          senderId: '@bob:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      expect(result.items[1].isGroupStart, isTrue);
      expect(result.items[1].isGroupContinuation, isFalse);
      expect(result.items[2].isGroupStart, isTrue);
      expect(result.items[2].isGroupContinuation, isFalse);
    });

    test('renders encrypted events as regular message items (not state batch)',
        () {
      final events = [
        _TestEvent(
          eventId: 'enc',
          type: EventTypes.Encrypted,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // banner + one event item
      expect(result.items.length, 2);
      expect(result.items[1].kind, TimelineItemKind.event);
      expect(result.items[0].undecryptableCount, 1);
      expect(result.undecryptableCount, 1);
    });

    test('groups consecutive state events into a single batch', () {
      final events = [
        _TestEvent(
          eventId: 'member1',
          type: EventTypes.RoomMember,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 5, 0),
        ),
        _TestEvent(
          eventId: 'name',
          type: EventTypes.RoomName,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // [banner, stateBatch]
      expect(result.items.length, 2);
      expect(result.items[1].kind, TimelineItemKind.stateEventBatch);
      expect(result.items[1].stateEvents, isNotEmpty);
      expect(result.items[1].stateEvents!.length, 2);
    });

    test('skips state events when showStateEvents is false', () {
      final events = [
        _TestEvent(
          eventId: 'msg',
          type: EventTypes.Message,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
        _TestEvent(
          eventId: 'name',
          type: EventTypes.RoomName,
          senderId: '@a:dom',
          originServerTs: DateTime(2024, 6, 15, 9, 0, 0),
        ),
      ];
      final result = buildTimelineItems(
        _StubTimeline(events),
        showStateEvents: false,
      );
      // banner + msg only (state event skipped)
      expect(result.items.length, 2);
      expect(result.items[1].kind, TimelineItemKind.event);
      expect(result.items[1].event!.eventId, 'msg');
    });

    test('inserts date separators on day boundaries', () {
      final events = [
        _TestEvent(
          eventId: 'day2_msg',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 16, 9, 0, 0),
        ),
        _TestEvent(
          eventId: 'day1_msg',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 9, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // [banner, day2_msg, dateSep, day1_msg]
      expect(result.items.length, 4);
      expect(result.items[2].kind, TimelineItemKind.dateSeparator);
      expect(result.items[2].date, DateTime(2024, 6, 15, 9, 0, 0));
    });

    test('no date separator when same day', () {
      final events = [
        _TestEvent(
          eventId: 'later',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
        _TestEvent(
          eventId: 'earlier',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 9, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      expect(result.items.length, 3); // banner + 2 events
      expect(
        result.items.any((e) => e.kind == TimelineItemKind.dateSeparator),
        isFalse,
      );
    });

    test('state events do not participate in sender grouping', () {
      final events = [
        _TestEvent(
          eventId: 'msg',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 5, 0),
        ),
        _TestEvent(
          eventId: 'member',
          type: EventTypes.RoomMember,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 2, 0),
        ),
        _TestEvent(
          eventId: 'older_msg',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // [banner, msg, stateBatch, older_msg]
      final msgEntry = result.items[1];
      expect(msgEntry.kind, TimelineItemKind.event);
      // msg and older_msg are 5 min apart, same sender -> should be grouped
      // But state event sits between them -- check continuation logic
      // uses _nextVisibleMessage which skips state events
      expect(msgEntry.isGroupContinuation, isTrue);
      final olderEntry = result.items[3];
      expect(olderEntry.isGroupStart, isTrue);
    });

    test('precomputes thread reply counts from timeline', () {
      final events = [
        _TestEvent(
          eventId: 'parent',
          type: EventTypes.Message,
          senderId: '@alice:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 0, 0),
          relationshipType: RelationshipTypes.thread,
          relationshipEventId: 'parent',
        ),
        _TestEvent(
          eventId: 'reply1',
          type: EventTypes.Message,
          senderId: '@bob:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 1, 0),
          relationshipType: RelationshipTypes.thread,
          relationshipEventId: 'parent',
        ),
        _TestEvent(
          eventId: 'reply2',
          type: EventTypes.Message,
          senderId: '@bob:dom',
          originServerTs: DateTime(2024, 6, 15, 10, 2, 0),
          relationshipType: RelationshipTypes.thread,
          relationshipEventId: 'parent',
        ),
      ];
      final result = buildTimelineItems(_StubTimeline(events));
      // Only thread root is visible; it should have replyCount = 2
      final parentEntry = result.items[1];
      expect(parentEntry.kind, TimelineItemKind.event);
      expect(parentEntry.replyCount, 2);
    });
  });
}
