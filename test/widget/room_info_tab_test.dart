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
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/room_info_tab.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A client whose room-state stream the test drives.
///
/// `RoomStateBus` fans out from `Client.onRoomState` and offers no public way
/// to push an event into it, so a bus test has to publish a real one. This is
/// the same shape `chat_room_header_test.dart` uses for the same reason.
class _StateClient extends Mock implements Client {
  final CachedStreamController<({String roomId, StrippedStateEvent state})>
      roomStates =
      CachedStreamController<({String roomId, StrippedStateEvent state})>(null);

  @override
  CachedStreamController<({String roomId, StrippedStateEvent state})>
      get onRoomState => roomStates;

  @override
  String get userID => '@me:matrix.org';

  @override
  String get accessToken => 'token';

  @override
  bool get encryptionEnabled => false;

  @override
  String get deviceID => 'DEVICE';

  @override
  CachedStreamController<SyncStatusUpdate> get onSyncStatus =>
      CachedStreamController<SyncStatusUpdate>(null);
}

void main() {
  // A room with every field the tab derives, overridable per test. The tab
  // caches these into its own fields and only re-reads them on a bus tick, so
  // "the tab showed X" and "the tab noticed X changed" are separate tests.
  MockRoom stubRoom({
    String name = 'General',
    String topic = 'Anything at all',
    int joined = 2,
    int invited = 0,
    bool encrypted = false,
    JoinRules joinRules = JoinRules.public,
    bool isSpace = false,
    bool isDirect = false,
    String? canonicalAlias = '',
    Client? client,
  }) {
    final MockRoom room = MockRoom();
    when(() => room.id).thenReturn('!r:matrix.org');
    // The tab hands `room.client` to the avatar widget. An unstubbed mocktail
    // getter returns null where a non-null client is expected, which fails
    // inside the avatar rather than anywhere near an assertion.
    when(() => room.client).thenReturn(client ?? MockClient());
    when(() => room.getLocalizedDisplayname()).thenReturn(name);
    when(() => room.topic).thenReturn(topic);
    when(() => room.avatar).thenReturn(null);
    when(() => room.canonicalAlias).thenReturn(canonicalAlias ?? '');
    when(() => room.encrypted).thenReturn(encrypted);
    when(() => room.joinRules).thenReturn(joinRules);
    when(() => room.isSpace).thenReturn(isSpace);
    when(() => room.isDirectChat).thenReturn(isDirect);
    when(() => room.summary).thenReturn(
      RoomSummary.fromJson(<String, Object?>{
        'm.joined_member_count': joined,
        'm.invited_member_count': invited,
      }),
    );
    return room;
  }

  Future<void> pumpInfo(
    WidgetTester tester, {
    required Room room,
    List<String> pinnedEventIds = const <String>[],
    bool pinnedFilterActive = false,
    VoidCallback? onTogglePinnedFilter,
    VoidCallback? onOpenPinnedTab,
    double width = 320,
    RoomStateBus? bus,
    Client? client,
  }) async {
    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        roomStateBus: bus,
        child: Scaffold(
          body: LayoutScope(
            size: LayoutSize.expanded,
            availableWidth: width,
            child: RoomInfoTab(
              room: room,
              pinnedEventIds: pinnedEventIds,
              pinnedFilterActive: pinnedFilterActive,
              onTogglePinnedFilter: onTogglePinnedFilter,
              onOpenPinnedTab: onOpenPinnedTab,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('the fields it derives from the room', () {
    testWidgets('shows name, topic, type, id and joined plus invited members',
        (tester) async {
      await pumpInfo(
        tester,
        room: stubRoom(
          name: 'Design',
          topic: 'Pixels and spacing',
          joined: 3,
          invited: 2,
        ),
      );

      expect(find.text('Design'), findsOneWidget);
      expect(find.text('Pixels and spacing'), findsOneWidget);
      expect(find.text('Public Room'), findsOneWidget);
      expect(find.text('!r:matrix.org'), findsOneWidget);
      // Joined plus invited, not joined alone. The member count that matters to
      // a user is everyone in the room, and a room you were invited to but have
      // not joined still has members you cannot see.
      expect(find.text('Members (5)'), findsOneWidget);
    });

    testWidgets('an empty topic says so instead of rendering nothing',
        (tester) async {
      await pumpInfo(tester, room: stubRoom(topic: ''));

      expect(find.text('No topic set'), findsOneWidget);
    });

    testWidgets('a null member summary counts as zero rather than throwing',
        (tester) async {
      final MockRoom room = MockRoom();
      when(() => room.id).thenReturn('!r:matrix.org');
      when(() => room.client).thenReturn(MockClient());
      when(() => room.getLocalizedDisplayname()).thenReturn('General');
      when(() => room.topic).thenReturn('');
      when(() => room.avatar).thenReturn(null);
      when(() => room.canonicalAlias).thenReturn('');
      when(() => room.encrypted).thenReturn(false);
      when(() => room.joinRules).thenReturn(JoinRules.invite);
      when(() => room.isSpace).thenReturn(false);
      when(() => room.isDirectChat).thenReturn(false);
      when(() => room.summary).thenReturn(
        RoomSummary.fromJson(const <String, Object?>{}),
      );

      await pumpInfo(tester, room: room);

      expect(find.text('Members (0)'), findsOneWidget);
    });

    testWidgets('the canonical alias row only appears when there is one',
        (tester) async {
      await pumpInfo(tester, room: stubRoom(canonicalAlias: null));
      expect(find.text('#design:matrix.org'), findsNothing);

      // A different room id, because `didUpdateWidget` keys its refresh on the
      // id rather than on object identity: in production one id is one room, so
      // reusing the id here would assert on a path the code deliberately does
      // not take.
      final MockRoom aliased = stubRoom(
        canonicalAlias: '#design:matrix.org',
      );
      when(() => aliased.id).thenReturn('!aliased:matrix.org');
      await pumpInfo(tester, room: aliased);
      expect(find.text('#design:matrix.org'), findsOneWidget);
    });
  });

  group('the room type it infers from join rules', () {
    testWidgets('invite only is the fallback', (tester) async {
      await pumpInfo(tester, room: stubRoom(joinRules: JoinRules.invite));
      expect(find.text('Invite only'), findsOneWidget);
      expect(find.text('Public Room'), findsNothing);
    });

    testWidgets('knock and knock restricted are their own label',
        (tester) async {
      await pumpInfo(
        tester,
        room: stubRoom(joinRules: JoinRules.knock),
      );
      expect(find.text('Knock-based room'), findsOneWidget);

      await pumpInfo(
        tester,
        room: stubRoom(joinRules: JoinRules.knockRestricted),
      );
      expect(find.text('Knock-based room'), findsOneWidget);
    });

    testWidgets('restricted is distinct from knock', (tester) async {
      await pumpInfo(
        tester,
        room: stubRoom(joinRules: JoinRules.restricted),
      );
      expect(find.text('Restricted room'), findsOneWidget);
      expect(find.text('Knock-based room'), findsNothing);
    });

    testWidgets('a direct message is not described by its join rules',
        (tester) async {
      // Join rules say who may join. A DM's rules are usually invite, which
      // would label a one-to-one conversation "Invite only" and hide the only
      // fact the reader actually cares about.
      await pumpInfo(
        tester,
        room: stubRoom(joinRules: JoinRules.invite, isDirect: true),
      );
      expect(find.text('Direct Message'), findsOneWidget);
      expect(find.text('Invite only'), findsNothing);
    });

    testWidgets('a space is not described by its join rules either',
        (tester) async {
      await pumpInfo(
        tester,
        room: stubRoom(joinRules: JoinRules.public, isSpace: true),
      );
      expect(find.text('Space'), findsOneWidget);
      expect(find.text('Public Room'), findsNothing);
    });
  });

  group('encryption status', () {
    testWidgets('says encrypted for an encrypted room', (tester) async {
      await pumpInfo(tester, room: stubRoom(encrypted: true));

      expect(find.text('End-to-end encrypted'), findsOneWidget);
      expect(find.text('Not encrypted'), findsNothing);
    });

    testWidgets('says not encrypted, and does not claim otherwise',
        (tester) async {
      await pumpInfo(tester, room: stubRoom(encrypted: false));

      expect(find.text('Not encrypted'), findsOneWidget);
      expect(find.text('End-to-end encrypted'), findsNothing);
    });
  });

  group('the pinned summary', () {
    testWidgets('counts what RoomPage resolved', (tester) async {
      await pumpInfo(
        tester,
        room: stubRoom(),
        pinnedEventIds: const <String>['pin-1', 'pin-2', 'pin-3'],
      );

      expect(find.text('3 pinned'), findsOneWidget);
    });

    testWidgets('says zero rather than hiding the row', (tester) async {
      // Hiding it would leave the reader unable to tell "no pins" from "this
      // build has no pin support", and would remove the way back to the tab.
      await pumpInfo(tester,
          room: stubRoom(), pinnedEventIds: const <String>[]);

      expect(find.text('0 pinned'), findsOneWidget);
    });

    testWidgets('hands off to the pane tab that owns the pins', (tester) async {
      int opened = 0;
      await pumpInfo(
        tester,
        room: stubRoom(),
        pinnedEventIds: const <String>['pin-1'],
        onOpenPinnedTab: () => opened++,
      );

      await tester.tap(find.text('1 pinned'));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('survives being mounted with no way to switch tabs',
        (tester) async {
      // `onOpenPinnedTab` is nullable precisely because tests and any future
      // read-only host mount this without one. A null callback must not become
      // a row that throws on tap or disappears.
      await pumpInfo(
        tester,
        room: stubRoom(),
        pinnedEventIds: const <String>['pin-1'],
        onOpenPinnedTab: null,
      );

      expect(find.text('1 pinned'), findsOneWidget);
      await tester.tap(find.text('1 pinned'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the room-state bus', () {
    // Publishes a state event the way the SDK would, which is the only way in.
    //
    // Synchronous on purpose: `testWidgets` runs in a fake-async zone where a
    // real timer only fires when the test pumps with a duration, so awaiting
    // `Future.delayed` here hangs the test outright. `CachedStreamController.add`
    // is void and delivers through the broadcast controller, and `pump()` drains
    // that.
    void emitState(_StateClient client, String roomId) {
      client.roomStates.add((
        roomId: roomId,
        state: StrippedStateEvent(
          type: 'm.room.name',
          senderId: '@someone:matrix.org',
          content: <String, Object?>{},
          stateKey: '',
        ),
      ));
    }

    testWidgets('picks up a renamed room when its room ticks', (tester) async {
      final _StateClient client = _StateClient();
      final RoomStateBus bus = RoomStateBus()..bind(client);
      final MockRoom room = stubRoom(name: 'Before', client: client);

      await pumpInfo(
        tester,
        room: room,
        bus: bus,
        client: client,
      );
      expect(find.text('Before'), findsOneWidget);

      when(() => room.getLocalizedDisplayname()).thenReturn('After');
      emitState(client, '!r:matrix.org');
      // Two pumps: the first delivers the broadcast stream event and sets the
      // notifier, the second builds the frame that reads the refreshed fields.
      await tester.pump();
      await tester.pump();

      expect(find.text('After'), findsOneWidget);
      expect(find.text('Before'), findsNothing);
    });

    testWidgets('ignores a tick for a different room', (tester) async {
      // The bus fans out per room id. Honouring another room's tick would
      // rebuild this tab with fields it never asked for, and on a busy account
      // every room would tick every other room's info tab.
      final _StateClient client = _StateClient();
      final RoomStateBus bus = RoomStateBus()..bind(client);
      final MockRoom room = stubRoom(name: 'Mine', client: client);

      await pumpInfo(tester, room: room, bus: bus, client: client);
      when(() => room.getLocalizedDisplayname()).thenReturn('Changed');
      emitState(client, '!other:matrix.org');
      await tester.pump();
      await tester.pump();

      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Changed'), findsNothing);
    });

    testWidgets('does not go blank when a tick carries nothing new',
        (tester) async {
      // The refresh compares every derived field and returns false when they
      // all match, which is what keeps a chatty room from rebuilding on every
      // presence or typing event.
      final _StateClient client = _StateClient();
      final RoomStateBus bus = RoomStateBus()..bind(client);

      await pumpInfo(
        tester,
        room: stubRoom(name: 'Stable', client: client),
        bus: bus,
        client: client,
      );

      emitState(client, '!r:matrix.org');
      await tester.pump();
      await tester.pump();

      expect(find.text('Stable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('re-reads the room when the widget is given another one',
        (tester) async {
      // Switching rooms reuses this widget, so `didUpdateWidget` is the only
      // thing standing between the user and the previous room's name, topic
      // and member count. The refresh keys on the room id, which in production
      // is one-to-one with a room, so the second room gets its own id.
      final MockRoom first = stubRoom(name: 'First', topic: 'One');
      final MockRoom second = stubRoom(name: 'Second', topic: 'Two');
      when(() => second.id).thenReturn('!second:matrix.org');

      await pumpInfo(tester, room: first);
      expect(find.text('First'), findsOneWidget);

      await pumpInfo(tester, room: second);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('One'), findsNothing);
    });
  });

  group('narrow panes', () {
    testWidgets('render at a narrow width without overflowing', (tester) async {
      // 320 is a real pane width, and the tab swaps padding, avatar radius and
      // name size below 240. A long unbroken room id and a long room name are
      // what break it.
      await pumpInfo(
        tester,
        room: stubRoom(
          name: 'A room with a name far longer than any narrow pane could fit',
          topic: 'And a topic that runs on for a while as well, to be sure',
          canonicalAlias: '#a-very-long-canonical-alias:matrix.org',
        ),
        width: 210,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(
            'A room with a name far longer than any narrow pane could fit'),
        findsOneWidget,
      );
    });

    testWidgets('the long name is allowed to ellipsize', (tester) async {
      await pumpInfo(
        tester,
        room: stubRoom(
          name: 'A room with a name far longer than any narrow pane could fit',
        ),
        width: 210,
      );

      final Text name = tester.widget<Text>(
        find.text(
            'A room with a name far longer than any narrow pane could fit'),
      );
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
    });
  });

  group('the type label is never guessed', () {
    testWidgets('renders with every optional callback absent', (tester) async {
      // Guards the all-null constructor: the production default for a host
      // that cannot switch tabs or toggle the filter.
      await pumpInfo(tester, room: stubRoom());
      expect(tester.takeException(), isNull);
    });
  });
}
