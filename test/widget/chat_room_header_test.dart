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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A client that answers the two stream subscriptions the header makes on
/// mount. An unstubbed mock hands a null where a stream controller is expected
/// and the widget throws before it lays anything out.
class _HeaderClient extends Mock implements Client {
  @override
  String get accessToken => 'token';

  @override
  bool get encryptionEnabled => false;

  @override
  String get deviceID => 'DEVICE';

  @override
  CachedStreamController<({String roomId, StrippedStateEvent state})>
      get onRoomState => CachedStreamController(null);

  @override
  CachedStreamController<SyncStatusUpdate> get onSyncStatus =>
      CachedStreamController(null);
}

MockRoom _room(
  Client client, {
  String name = 'General',
  String topic = 'Anything',
}) {
  final room = MockRoom();
  when(() => room.id).thenReturn('!r:matrix.org');
  // The header reaches for `room.client` in its own build, to subscribe to room
  // state. An unstubbed client throws a cast error there, which leaves the bar
  // unbuilt and would make every assertion below it pass for the wrong reason.
  when(() => room.client).thenReturn(client);
  when(() => room.getLocalizedDisplayname()).thenReturn(name);
  when(() => room.topic).thenReturn(topic);
  when(() => room.avatar).thenReturn(null);
  // The header adds joined and invited to decide whether to show a member
  // count, and reads `summary` unguarded in `initState`.
  when(() => room.summary).thenReturn(
    RoomSummary.fromJson(const {
      'm.joined_member_count': 2,
      'm.invited_member_count': 0,
    }),
  );
  return room;
}

Future<void> pumpHeader(
  WidgetTester tester,
  Room Function(Client client) build, {
  double width = 1400,
}) async {
  final client = _HeaderClient();
  when(() => client.getRoomById(any())).thenReturn(null);
  final room = build(client);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<LayoutShellController>(
          create: (_) => LayoutShellController()
            ..resolve(rawWidth: width, layoutMode: LayoutMode.auto),
        ),
      ],
      child: wrapWithProviders(
        client: client,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // The header adapts to its own LayoutBuilder, so the pane has to be
          // actually narrow for the narrow path to run. Feeding the shell
          // controller a small width is not the same thing.
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: ChatRoomHeader(room: room),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // A build that throws is reported as a failure here rather than as a run of
  // assertions that quietly pass against an empty tree.
  expect(tester.takeException(), isNull);
}

/// The bar itself, rather than the widget around it.
///
/// `ChatRoomHeader` fills the Scaffold body, so its own size is the pane's and
/// says nothing. The bar is the container that draws the bottom hairline,
/// which is the one piece of this header that is unambiguously "the bar":
/// several other containers in the subtree are decorated boxes.
Finder _theBar(WidgetTester tester) => find.descendant(
      of: find.byType(ChatRoomHeader),
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final decoration = w.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        return border is Border && border.bottom.style != BorderStyle.none;
      }),
    );

void main() {
  group('ChatRoomHeader', () {
    testWidgets('is one pane bar tall whether or not the room has a topic',
        (tester) async {
      // The invariant the one-line layout exists to protect. A header that
      // grows when a topic appears moves the top of the conversation, which is
      // the one place in a chat client where content must not shift under the
      // reader.
      await pumpHeader(tester, (c) => _room(c));
      final withTopic = tester.getSize(_theBar(tester)).height;

      await pumpHeader(tester, (c) => _room(c, topic: ''));
      final withoutTopic = tester.getSize(_theBar(tester)).height;

      expect(withTopic, withoutTopic);
      // The same token the composer at the other end of this pane reads. It was
      // a bare 48 against the composer's 52, which is what stopped the
      // conversation reading as framed.
      expect(withTopic, MoonrelayDesignTokens.standard().paneBarHeight);
    });

    testWidgets('the topic shares the line with the name, after a rule',
        (tester) async {
      await pumpHeader(
        tester,
        (c) => _room(c, name: 'General', topic: 'Welcome in'),
      );

      // Both on one line: the topic's centre sits within a few pixels of the
      // name's, which it could not do while it was stacked underneath.
      final name = tester.getCenter(find.text('General'));
      final topic = tester.getCenter(find.text('Welcome in'));
      expect((name.dy - topic.dy).abs(), lessThan(4));

      // And the rule between them is what says they are two fields rather than
      // one run-on label.
      expect(
          find.descendant(
            of: find.byType(ChatRoomHeader),
            matching: find.byType(VerticalDivider),
          ),
          findsOneWidget);
    });

    testWidgets('a narrow pane drops the topic and its rule together',
        (tester) async {
      // The header adapts to the *pane's* width, not the window's, and the
      // topic is the thing that gives way: the name is the only label that has
      // to be there. Below 480 the topic slot and the rule go together, so a
      // rule is never left standing on its own between the name and the
      // actions, which reads as a rendering fault.
      await pumpHeader(tester, (c) => _room(c), width: 420);

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Anything'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ChatRoomHeader),
          matching: find.byType(VerticalDivider),
        ),
        findsNothing,
      );
    });

    testWidgets('a room with no topic keeps the pane bar height',
        (tester) async {
      // The header shows a placeholder rather than an empty slot, because a
      // gap between the name and the actions reads as a half-rendered bar.
      await pumpHeader(tester, (c) => _room(c, topic: ''));

      expect(find.text('General'), findsOneWidget);
      expect(
        tester.getSize(_theBar(tester)).height,
        MoonrelayDesignTokens.standard().paneBarHeight,
      );
    });

    testWidgets('a long topic does not push the actions off the bar',
        (tester) async {
      await pumpHeader(
        tester,
        (c) => _room(c, topic: 'A topic long enough to overflow the bar'),
      );

      // The topic is the only elastic thing in the bar. Laid out at its
      // intrinsic width it would push the search and settings buttons past the
      // end of the window, and those are the header's only routes out. So the
      // assertion is about the actions' position rather than about the topic's
      // width: a topic that happens to fit is not evidence of anything.
      final bar = tester.getRect(_theBar(tester));
      for (final icon in [
        LucideIcons.search,
        LucideIcons.settings,
      ]) {
        final button = find.descendant(
          of: find.byType(ChatRoomHeader),
          matching: find.byIcon(icon),
        );
        expect(button, findsOneWidget, reason: '$icon missing from the header');
        expect(
          tester.getRect(button).right,
          lessThanOrEqualTo(bar.right),
          reason: '$icon is outside the bar',
        );
      }

      // And the topic really is sharing space rather than getting everything.
      expect(
        tester
            .getRect(
              find
                  .descendant(
                    of: find.byType(ChatRoomHeader),
                    matching: find.text(
                      'A topic long enough to overflow the bar',
                    ),
                  )
                  .first,
            )
            .right,
        lessThan(bar.right),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('there is no live blur behind the bar', (tester) async {
      // It was there to sell the translucency and cost a per-frame readback of
      // the whole pane on a bar that repaints on every sync. The jank showed up
      // as scroll stutter in the timeline rather than as a slow header.
      await pumpHeader(tester, (c) => _room(c));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('the bar is opaque and on the conversation step',
        (tester) async {
      await pumpHeader(tester, (c) => _room(c));
      final scheme = Theme.of(
        tester.element(find.byType(ChatRoomHeader)),
      ).colorScheme;

      final fills = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.color)
          .whereType<Color>()
          .toList();

      expect(fills, contains(scheme.surfaceContainerHigh));
      // Opaque, so nothing moving behind the bar can show through the room
      // name and read as a rendering fault.
      expect(
        fills.where((c) => c.a < 1),
        isEmpty,
        reason: 'a translucent fill over a scrolling timeline',
      );
    });
  });
}
