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

// The room settings page's Danger Zone, which had a permission gate that made
// the mildest action in the app the hardest to reach.
//
// "Leave room" was nested inside `if (_isAdmin || ...)`, where `_isAdmin` is
// `canChangeStateEvent('m.room.power_levels')`, which is power level 50 against
// a stock room. The row's own `membership == Membership.join` check was correct
// and unreachable: leaving is `POST /rooms/{id}/leave`, a self-targeted member
// event with no power requirement in the spec, so the gate hid the one
// destructive action every member is entitled to take from exactly the members
// who most often want it. The panel is now gated on whether it has a row to
// show, and each row carries its own capability check.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/screens/room_settings/room_settings_page.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  late AppLocalizations l10n;

  // The page's notification tile reads this, and a missing provider throws
  // during `build`, which takes the whole subtree down. Without it every
  // assertion below would fail on an unrelated error rather than on the
  // permission gate it exists to test. Built once because its constructor is
  // private and `init` is the only way in.
  late NotificationService notifications;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    notifications = await NotificationService.init(
      client: MockClient(),
      settings: createTestSettingsController(),
      currentRoom: CurrentRoom(),
      log: MockLogger(),
    );
  });

  Future<void> pumpSettings(WidgetTester tester, Room room) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<NotificationService>.value(value: notifications),
        ],
        child: wrapWithProviders(child: RoomSettingsPage(room: room)),
      ),
    );
    await tester.pump();

    // Scroll to the bottom, because the Danger Zone is the last section on a
    // long page and is below the fold in the default 800x600 test surface.
    //
    // This matters for the negative assertions as much as the positive ones.
    // Asserting `findsNothing` on a row that has not been laid out yet would
    // pass for the wrong reason, and the whole file is about a row that was
    // wrongly absent. So every test here looks at a page that has been
    // scrolled to where the row would be.
    final Scrollable scrollable = tester.widget<Scrollable>(
      find.byType(Scrollable),
    );
    scrollable.controller
        ?.jumpTo(scrollable.controller!.position.maxScrollExtent);
    await tester.pump();
  }

  /// A room at a given power level and membership.
  ///
  /// [ownPower] is what decides `_isAdmin`, and the defaults are the two states
  /// that matter: an ordinary member at 0, and a moderator at 50.
  MockRoom stubRoom({
    Membership membership = Membership.join,
    int ownPower = 0,
    bool hasPowerLevelsState = true,
  }) {
    final MockRoom room = MockRoom();
    when(() => room.id).thenReturn('!r:matrix.org');
    when(() => room.client).thenReturn(MockClient());
    when(() => room.getLocalizedDisplayname()).thenReturn('General');
    when(() => room.topic).thenReturn('Anything');
    when(() => room.avatar).thenReturn(null);
    when(() => room.canonicalAlias).thenReturn('');
    when(() => room.encrypted).thenReturn(false);
    when(() => room.isDirectChat).thenReturn(false);
    when(() => room.isSpace).thenReturn(false);
    when(() => room.joinRules).thenReturn(JoinRules.public);
    when(() => room.roomVersion).thenReturn('10');
    when(() => room.membership).thenReturn(membership);
    when(() => room.ownPowerLevel).thenReturn(PowerLevel(ownPower));
    // `roomCreatedAt` reads `m.room.create` state, so the create event is
    // answered by type rather than by "any state exists": one catch-all stub
    // would hand the page a power_levels event where it asked for a create one.
    when(() => room.getState(any())).thenAnswer((Invocation invocation) {
      final String type = invocation.positionalArguments.first as String;
      if (!hasPowerLevelsState && type == 'm.room.power_levels') return null;
      if (type == 'm.room.create') {
        return Event(
          room: room,
          eventId: 'evt-create',
          senderId: '@creator:matrix.org',
          type: 'm.room.create',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(0),
          content: <String, Object?>{
            'created_at': DateTime.utc(2026, 1, 2).toIso8601String(),
          },
        );
      }
      return Event(
        room: room,
        eventId: 'evt-state',
        senderId: '@someone:matrix.org',
        type: type,
        originServerTs: DateTime.fromMillisecondsSinceEpoch(0),
        content: <String, Object?>{},
      );
    });
    // Every capability the page probes is answered from the power level, so a
    // test that changes `ownPower` moves all of them together the way a real
    // power level event would.
    when(() => room.canChangeStateEvent(any())).thenAnswer(
      (Invocation invocation) {
        final String eventType = invocation.positionalArguments.first as String;
        // Stock `m.room.power_levels`: changing power levels needs 50, anything
        // else needs the `state_default` of 50 too. Both gates therefore land
        // on the same number, which is why the bug hid behind an ordinary
        // member's power level.
        final int needed = eventType == 'm.room.power_levels' ? 50 : 50;
        return membership == Membership.join && ownPower >= needed;
      },
    );
    when(() => room.summary).thenReturn(
      RoomSummary.fromJson(const <String, Object?>{
        'm.joined_member_count': 3,
        'm.invited_member_count': 0,
      }),
    );
    return room;
  }

  group('leaving a room', () {
    testWidgets('is offered to an ordinary member at power level zero',
        (tester) async {
      // The regression. A member with no power at all is the whole case:
      // before the fix this panel was not built, so there was nothing to tap
      // and no error either. Silence was the only symptom.
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.join, ownPower: 0),
      );

      expect(find.text(l10n.leaveRoom), findsOneWidget);
      expect(find.text(l10n.leaveRoomDescription), findsOneWidget);
    });

    testWidgets('is offered to a plain member even with no power level state',
        (tester) async {
      // A room whose `m.room.power_levels` never arrived. `space_settings_page`
      // refuses to offer delete in exactly this case, and correctly so, because
      // delete is a server-side admin call. Leave is not, and must not inherit
      // the caution: the server will refuse leave if it should, and the client
      // has nothing to add by guessing.
      //
      // The description row is asserted alongside the label, because `l10n
      // .leaveRoom` and `l10n.leaveRoomTitle` are both "Leave Room" in English.
      // A test that only looked for the string could be satisfied by anything
      // else on the page rendering that same text, which is how a version of
      // this test passed against the original bug.
      await pumpSettings(
        tester,
        stubRoom(
          membership: Membership.join,
          ownPower: 0,
          hasPowerLevelsState: false,
        ),
      );

      expect(find.text(l10n.leaveRoom), findsOneWidget);
      expect(find.text(l10n.leaveRoomDescription), findsOneWidget);
    });

    testWidgets('asks before doing it', (tester) async {
      await pumpSettings(tester, stubRoom());

      await tester.tap(find.text(l10n.leaveRoom));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text(l10n.leaveRoomConfirm('General')),
        findsOneWidget,
        reason: 'leaving is not reversible from the room itself',
      );
    });

    testWidgets('is not offered to somebody who has already left',
        (tester) async {
      // Nothing to leave. Offering it would POST a leave for a room whose
      // membership is already `leave`, which the server rejects.
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.leave, ownPower: 0),
      );

      expect(find.text(l10n.leaveRoom), findsNothing);
    });

    testWidgets('is not offered to somebody banned from the room',
        (tester) async {
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.ban, ownPower: 0),
      );

      expect(find.text(l10n.leaveRoom), findsNothing);
    });
  });

  group('deleting a room', () {
    testWidgets('stays admin only', (tester) async {
      // The fix must not overshoot. Delete is `POST /_synapse/admin/v2/rooms/
      // {id}/delete` on the homeserver, so it is genuinely privileged and
      // ungating it would be a different bug in the same shape.
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.join, ownPower: 0),
      );

      expect(find.text(l10n.deleteRoom), findsNothing);
    });

    testWidgets('is offered to an admin', (tester) async {
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.join, ownPower: 100),
      );

      expect(find.text(l10n.deleteRoom), findsOneWidget);
    });
  });

  group('forgetting a room', () {
    testWidgets('is offered once you have left', (tester) async {
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.leave, ownPower: 0),
      );

      expect(find.text(l10n.forgetRoom), findsOneWidget);
      expect(find.text(l10n.leaveRoom), findsNothing);
    });

    testWidgets('is not offered to somebody still in the room', (tester) async {
      // Forget purges local state and asks the server to drop the room, which
      // the spec only allows after leaving.
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.join, ownPower: 0),
      );

      expect(find.text(l10n.forgetRoom), findsNothing);
    });
  });

  group('the panel as a whole', () {
    testWidgets('is absent when there is nothing in it to show',
        (tester) async {
      // A banned user: cannot leave, has not left, is not an admin. An empty
      // "Danger Zone" heading above nothing is worse than no heading.
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.ban, ownPower: 0),
      );

      expect(find.text(l10n.actionsDeleteSection), findsNothing);
      expect(find.text(l10n.leaveRoom), findsNothing);
      expect(find.text(l10n.deleteRoom), findsNothing);
      expect(find.text(l10n.forgetRoom), findsNothing);
    });

    testWidgets('is present for an ordinary member, which is the point',
        (tester) async {
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.join, ownPower: 0),
      );

      expect(find.text(l10n.actionsDeleteSection), findsOneWidget);
    });

    testWidgets('still gates each row separately inside one panel',
        (tester) async {
      // An admin who has already left: forget is theirs, leave is not, delete
      // is not, because `canChangeStateEvent` folds membership in and they are
      // no longer joined. One panel, three independent answers.
      await pumpSettings(
        tester,
        stubRoom(membership: Membership.leave, ownPower: 100),
      );

      expect(find.text(l10n.actionsDeleteSection), findsOneWidget);
      expect(find.text(l10n.forgetRoom), findsOneWidget);
      expect(find.text(l10n.leaveRoom), findsNothing);
      expect(find.text(l10n.deleteRoom), findsNothing);
    });
  });
}
