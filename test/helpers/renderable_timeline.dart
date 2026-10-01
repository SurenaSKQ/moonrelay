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

// A `Room` and `Timeline` pair rich enough for `TimelineItem` to render
// real widgets in a widget test.  The timeline tests need this because
// the behaviour under test lives in the seam between the scroll
// position, the read receipt and the rendered event list; stubbing
// either side of that seam would let the original bugs through.
//
// Most timeline widget tests in this repo use an empty event list on
// purpose, which is fine for their subject but useless here.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import 'mocks.dart';
import 'widget_test_utils.dart';

/// Key on the jump-to-unread pill, for finders.
const String kUnreadPillKey = 'jump-to-unread';

/// A timeline whose event list the test controls, newest-first like
/// the real `Timeline.events`.
class RenderableTimeline extends Mock implements Timeline {
  RenderableTimeline({this.canPageOlder = true, this.prevToken = ''});

  final List<Event> _events = <Event>[];

  /// Mirrors the live timeline, where forward paging is impossible.
  /// A `/context` window sets this false while still carrying a
  /// `prevToken`, which is the case `HistoryPager` has to get right.
  bool canPageOlder;
  String prevToken;

  int historyRequests = 0;
  bool subscriptionsCancelled = false;

  @override
  List<Event> get events => List.unmodifiable(_events);

  /// `Event.hasAggregatedEvents` reads this directly.
  @override
  Map<String, Map<String, Set<Event>>> get aggregatedEvents => {};

  /// The pagination tokens.  `HistoryPager` reads `prevBatch` when the
  /// SDK's own `canRequestHistory` says no, which is the `/context`
  /// window case.
  @override
  TimelineChunk get chunk =>
      TimelineChunk(events: _events, prevBatch: prevToken);

  /// Inserts at the head, the way sync lands a new message.
  void insertNewest(Event e) => _events.insert(0, e);

  void setAll(List<Event> es) => _events
    ..clear()
    ..addAll(es);

  @override
  bool get isRequestingHistory => false;

  @override
  bool get isRequestingFuture => false;

  @override
  bool get allowNewEvent => true;

  @override
  bool get canRequestFuture => false;

  @override
  bool get canRequestHistory => canPageOlder;

  @override
  Future<void> requestHistory({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {
    historyRequests++;
  }

  @override
  Future<void> requestFuture({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {}

  @override
  void cancelSubscriptions() {
    subscriptionsCancelled = true;
  }
}

/// A room that hands out a live timeline, and a separate `/context`
/// window when `getTimeline` is asked for one.
class RenderableRoom extends Mock implements Room {
  RenderableRoom(this.live);

  final RenderableTimeline live;

  /// Timeline returned for a `getTimeline(eventContextId:)` call.
  RenderableTimeline? context;

  /// Every `eventContextId` this room was asked to build a window for.
  final List<String> contextRequests = [];

  /// Event ids passed to `setReadMarker`, in call order.
  final List<String?> posted = [];

  /// When set, [getTimeline] throws for a context request, simulating a
  /// purged or inaccessible event.
  bool failContextRequests = false;

  String fullyReadId = '';

  void Function()? _onUpdate;
  void Function(int)? _onInsert;

  @override
  String get id => '!room:example.com';

  @override
  String get fullyRead => fullyReadId;

  @override
  Client get client => _client;

  @override
  Membership get membership => Membership.join;

  @override
  // ignore: non_constant_identifier_names
  String? get prev_batch => null;

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {
    posted.add(eventId);
  }

  @override
  Future<Timeline> getTimeline({
    void Function(int index)? onChange,
    void Function(int index)? onRemove,
    void Function(int insertID)? onInsert,
    void Function()? onNewEvent,
    void Function()? onUpdate,
    String? eventContextId,
    int? limit,
  }) async {
    _onUpdate = onUpdate;
    _onInsert = onInsert;

    if (eventContextId == null) return live;
    contextRequests.add(eventContextId);
    if (failContextRequests) {
      throw Exception('no access to $eventContextId');
    }
    return context ?? live;
  }

  /// Simulates a sync landing a new message at the head of the room.
  void deliverNewEvent(Event e) {
    live.insertNewest(e);
    _onInsert?.call(0);
    _onUpdate?.call();
  }

  /// `Event.senderFromMemoryOrFallback` routes through this, and
  /// `TimelineItem` calls it for every sender-name row.
  @override
  User unsafeGetUserFromMemoryOrFallback(String userId) {
    final user = MockUser();
    when(() => user.calcDisplayname()).thenReturn(userId);
    when(() => user.avatarUrl).thenReturn(null);
    when(() => user.displayName).thenReturn(null);
    return user;
  }

  /// `Event.receipts` walks this; an empty state renders no avatars.
  @override
  LatestReceiptState get receiptState => LatestReceiptState.empty();

  late final Client _client = _makeClient();
}

Client _makeClient() {
  final client = MockClient();
  when(() => client.userID).thenReturn('@me:example.com');
  return client;
}

/// Builds a real `m.room.message` text event so the timeline renders
/// actual widgets rather than stand-ins.
Event makeMessageEvent(Room room, String id, int ts) {
  return Event.fromMatrixEvent(
    MatrixEvent(
      type: EventTypes.Message,
      eventId: '\$$id',
      roomId: room.id,
      senderId: '@alice:example.com',
      originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
      content: <String, Object?>{
        'msgtype': 'm.text',
        'body': 'message $id',
      },
    ),
    room,
    status: EventStatus.synced,
  );
}

/// A room plus the event ids it was seeded with, newest-first.
typedef SeededRoom = ({RenderableRoom room, List<String> ids});

/// Seeds [timeline] with [count] messages named `ev1` (oldest) through
/// `ev{count}` (newest), and points the room's read marker below the
/// whole batch so every message counts as unread.
SeededRoom seedTimeline(Room room, RenderableTimeline timeline,
    {int count = 60}) {
  final ordered = [
    for (var i = count; i >= 1; i--) 'ev$i',
  ];
  timeline.setAll([
    for (final id in ordered) makeMessageEvent(room, id, 1000000 + _seq(id)),
  ]);
  return (room: room as RenderableRoom, ids: ordered);
}

int _seq(String id) => int.parse(id.substring(2));

/// Wraps a [ChatTimeline] with the providers and localisations it needs.
/// The encryption service is stubbed because `MessageEventHandler` asks
/// it whether the sending device is verified.
Widget wrapChatTimeline(Room room, {double width = 400, double height = 600}) {
  final encryption = MockEncryptionService();
  when(() => encryption.isUserVerifiedById(any())).thenReturn(false);

  return wrapWithProviders(
    encryptionService: encryption,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: ChatTimeline(room: room),
        ),
      ),
    ),
  );
}
