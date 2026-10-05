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
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:moonrelay/src/screens/room_page.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';

import '../helpers/widget_test_utils.dart';

/// A [Room] with the surface [RoomPage] and its children read.
///
/// Follows the shape of the fake in `chat_timeline_read_marker_test.dart`:
/// override the accessors that would otherwise hit a real SDK call rather
/// than stubbing a dozen getters, because a stub list here goes stale
/// silently the next time the header reads one more field.
class _FakeRoom extends Mock implements Room {
  @override
  String get id => '!room:example.com';

  @override
  String get name => 'Test Room';

  @override
  String get topic => '';

  @override
  Uri? get avatar => null;

  @override
  bool get encrypted => false;

  // Read by the pane's info tab, which now mounts inside `RoomPage` and so
  // inside this test. An unstubbed `bool` getter on a mocktail mock returns
  // null, and the tab throws on its first build.
  @override
  bool get isDirectChat => false;

  @override
  bool get isSpace => false;

  @override
  JoinRules? get joinRules => JoinRules.public;

  @override
  String get canonicalAlias => '';

  @override
  Membership get membership => Membership.join;

  @override
  String get fullyRead => '';

  @override
  List<String> get pinnedEventIds => const <String>[];

  @override
  RoomSummary get summary => _FakeSummary();

  @override
  List<User> get typingUsers => const <User>[];

  @override
  Client get client => _FakeClient();

  @override
  String getLocalizedDisplayname([MatrixLocalizations? localizations]) =>
      'Test Room';

  @override
  Future<Timeline> getTimeline({
    void Function(int index)? onChange,
    void Function(int index)? onRemove,
    void Function(int insertID)? onInsert,
    void Function()? onNewEvent,
    void Function()? onUpdate,
    String? eventContextId,
    int? limit,
  }) async =>
      _FakeTimeline();

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {}
}

class _FakeSummary extends Mock implements RoomSummary {}

class _FakeClient extends Mock implements Client {
  @override
  String get userID => '@me:example.com';

  @override
  String get accessToken => 'token';

  @override
  bool get encryptionEnabled => false;

  @override
  String get deviceID => 'DEVICE';

  // `ChatRoomHeader` subscribes to this on mount, so an unstubbed mock
  // hands a null where a stream controller is expected.
  @override
  CachedStreamController<({String roomId, StrippedStateEvent state})>
      get onRoomState => CachedStreamController(null);

  // The status bar in the room header subscribes to this too.
  @override
  CachedStreamController<SyncStatusUpdate> get onSyncStatus =>
      CachedStreamController(null);
}

class _FakeTimeline extends Mock implements Timeline {
  @override
  List<Event> get events => const <Event>[];

  @override
  bool get isRequestingHistory => false;

  @override
  bool get isRequestingFuture => false;

  @override
  bool get allowNewEvent => true;

  @override
  bool get canRequestFuture => false;

  @override
  bool get canRequestHistory => true;

  @override
  Future<void> requestHistory({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {}

  @override
  Future<void> requestFuture({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {}

  @override
  void cancelSubscriptions() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// [openPane] decides whether the room's side pane is showing.
  ///
  /// It defaults to closed, so the width assertions below mean what they say.
  /// With the pane open the conversation is 288 pixels narrower, which is
  /// correct and is a different measurement; the open case has its own group.
  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    bool openPane = false,
  }) async {
    // The default test surface is 800x600, so a `SizedBox` wider than that
    // is silently clamped and every width assertion in this file would be a
    // lie about the number it names. The surface is set, not assumed.
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = _FakeClient();
    when(() => client.getRoomById(any())).thenReturn(null);

    // The pane's tab is a preference now, so a test that wants no pane has
    // to say so. The default is the info tab, which is why every width
    // assertion in this file would otherwise be 288 pixels out.
    final settings = createTestSettingsController();
    await settings.setRoomPaneTab(
      openPane ? RoomPaneTab.info : RoomPaneTab.none,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          // `ChatRoomHeader` reads this to decide its own arrangement, the
          // same one-parameter question the dashboard asks.
          Provider<LayoutShellController>(
            create: (_) => LayoutShellController()
              ..resolve(rawWidth: width, layoutMode: LayoutMode.auto),
          ),
        ],
        child: wrapWithProviders(
          client: client,
          settingsController: settings,
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
                height: 900,
                child: RoomPage(room: _FakeRoom()),
              ),
            ),
          ),
        ),
      ),
    );
    // Several frames: the room page sets CurrentRoom in a post-frame
    // callback, the timeline attaches to the room, and the header resolves
    // the client.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('RoomPage fills its pane', () {
    // The room surface is not capped and not centred. It briefly was: a
    // 760px centred column, on the reasoning that a 480px bubble in a
    // full-width list leaves a lot of empty surface on a wide monitor. That
    // is a reading-page argument, and this is not a reading page. A chat
    // client is a window onto a live conversation, the window is what the
    // user sized deliberately, and an empty band beside the conversation
    // reads as a layout that ran out of ideas rather than as breathing
    // room.
    //
    // These assert the room spans its pane at every width, so a cap cannot
    // come back without a test failing.
    for (final width in const [420.0, 900.0, 1600.0, 2400.0]) {
      testWidgets('the room spans the full pane at ${width.toInt()}px',
          (tester) async {
        await pumpAt(tester, width);

        for (final finder in <Finder>[
          find.byType(ChatTimeline),
          find.byType(ChatBox),
          find.byType(ChatRoomHeader),
        ]) {
          expect(
            tester.getSize(finder).width,
            width,
            reason: 'at ${width.toInt()}px',
          );
        }
      });
    }

    testWidgets('the room is flush to the left, with no centred gutter',
        (tester) async {
      // The visible symptom of the cap: a band of empty surface on both
      // sides of the conversation, which is what "looks wrong" was about.
      await pumpAt(tester, 1600);
      expect(tester.getRect(find.byType(ChatBox)).left, 0);
      expect(tester.getRect(find.byType(ChatTimeline)).left, 0);
    });

    testWidgets('the composer spans the pane, not the bubble column',
        (tester) async {
      // The composer is the widest thing in the room and it used to be
      // capped to 760 alongside the messages. It is the one control the
      // user reaches for most, so it should have the whole width.
      await pumpAt(tester, 1600);
      final composer = tester.getRect(find.byType(ChatBox));
      final timeline = tester.getRect(find.byType(ChatTimeline));
      expect(composer.width, timeline.width);
      expect(composer.width, 1600);
    });
  });

  group('the pane belongs to the room', () {
    // It used to be the dashboard's fourth row child, which meant the pane
    // describing a room was a sibling of the route content and had to find the
    // room from a global. These are the assertions that say otherwise.

    testWidgets('it renders inside RoomPage, and nowhere else', (tester) async {
      await pumpAt(tester, 1600, openPane: true);

      expect(find.byType(RoomPage), findsOneWidget);
      expect(find.byType(RoomPane), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it takes its width off the conversation', (tester) async {
      await pumpAt(tester, 1600, openPane: true);

      final double pane = tester.getSize(find.byType(RoomPane)).width;
      final double timeline = tester.getSize(find.byType(ChatTimeline)).width;

      // 1600, less the pane, less the 8px resize handle between them. The pane
      // does not invent a width: 280 is the persisted default.
      expect(pane, 280);
      expect(timeline, closeTo(1600 - pane - 8, 1));
    });

    testWidgets('and the conversation is still uncapped and still flush left',
        (tester) async {
      // The point of the previous group, under the new arrangement: losing 288
      // pixels to a pane must not bring the old 760px cap back with it.
      await pumpAt(tester, 2400, openPane: true);

      expect(tester.getRect(find.byType(ChatTimeline)).left, 0);
      expect(tester.getRect(find.byType(ChatBox)).left, 0);
      expect(
        tester.getSize(find.byType(ChatTimeline)).width,
        closeTo(2400 - 280 - 8, 1),
      );
    });

    testWidgets('a closed pane gives the conversation everything', (
      tester,
    ) async {
      await pumpAt(tester, 1600);
      expect(find.byType(RoomPane), findsNothing);
      expect(tester.getSize(find.byType(ChatTimeline)).width, 1600);
    });
  });
}
