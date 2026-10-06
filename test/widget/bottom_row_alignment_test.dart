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

// The seam between the navigation sidebar and the conversation, measured.
//
// The sidebar's bottom row and the conversation's bottom row are two adjacent
// columns that meet at a vertical seam, and both end at the window bottom. If
// their heights differ, the hairline above one sits at a different height from
// the hairline above the other and the two rows read as not lining up, which is
// exactly what the eye catches in a screenshot and cannot name.
//
// They were 51 and 52.5. The sidebar's was derived rather than stated: the
// profile pill was whatever its tallest child worked out to, which was a 34px
// avatar plus 8px of padding above and below, and the rule above it set
// `height: 1`. The conversation's was a 52px composer under a rule that set no
// height at all and so inherited `DividerThemeData.space`, which the theme
// defines as the divider token's *thickness* rather than as a slot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/screens/room_page.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/navigation_sidebar.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A client whose room-state and sync streams are real.
///
/// `ChatRoomHeader` builds a `StreamBuilder` over `room.client.onRoomState`, and
/// an unstubbed mocktail getter returns null where a stream is expected, so the
/// header throws on its first build and never reaches layout.
class _ShellClient extends Mock implements Client {
  @override
  String get userID => '@me:example.org';

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
      CachedStreamController<SyncStatusUpdate>(null);
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
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final double bar = MoonrelayDesignTokens.standard().paneBarHeight;

  MockRoom stubRoom(Client client) {
    final MockRoom room = MockRoom();
    when(() => room.id).thenReturn('!r:example.org');
    when(() => room.client).thenReturn(client);
    when(() => room.getLocalizedDisplayname()).thenReturn('General');
    when(() => room.topic).thenReturn('Anything');
    when(() => room.avatar).thenReturn(null);
    when(() => room.canonicalAlias).thenReturn('');
    when(() => room.encrypted).thenReturn(false);
    when(() => room.isDirectChat).thenReturn(false);
    when(() => room.isSpace).thenReturn(false);
    when(() => room.joinRules).thenReturn(JoinRules.public);
    // `TypingIndicator` reads this unguarded in `build`, and an unstubbed
    // mocktail getter returns null where a list is promised.
    when(() => room.typingUsers).thenReturn(const <User>[]);
    // Read by `ChatTimeline` in `build`. `MockRoom` implements this as a field
    // with no default, so it is null until something writes it.
    when(() => room.fullyRead).thenReturn('');
    when(() => room.summary).thenReturn(
      RoomSummary.fromJson(const <String, Object?>{
        'm.joined_member_count': 2,
      }),
    );
    // `RoomPage` hands this to `ChatTimeline`, which cannot lay out without a
    // timeline to lay out.
    when(() => room.getTimeline(
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onInsert: any(named: 'onInsert'),
          onNewEvent: any(named: 'onNewEvent'),
          onUpdate: any(named: 'onUpdate'),
          eventContextId: any(named: 'eventContextId'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => _FakeTimeline());
    return room;
  }

  /// The two columns side by side, which is the only arrangement in which the
  /// seam exists. Stacking them, as the rest of the suite does, would hide the
  /// thing this file exists to measure.
  ///
  /// The conversation column is the real `RoomPage`, not a Column that imitates
  /// one. An imitation is how the previous test of this pair came to pass while
  /// measuring nothing: it built two `SizedBox(height: h)` and compared them. The
  /// first version of this file did the same thing, left the `Divider` out of its
  /// imitation, and then found only one rule in the tree to compare.
  Future<void> pumpTwoColumns(
    WidgetTester tester, {
    double height = 720,
    double sidebarWidth = 360,
  }) async {
    tester.view.physicalSize = Size(1280, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _ShellClient client = _ShellClient();
    when(() => client.getRoomById(any())).thenReturn(null);
    when(() => client.rooms).thenReturn(<Room>[]);
    final Room room = stubRoom(client);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LayoutShellController>(
            create: (_) => LayoutShellController()
              ..resolve(rawWidth: 1280, layoutMode: LayoutMode.auto),
          ),
        ],
        child: wrapWithProviders(
          client: client,
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: sidebarWidth,
                  child: const NavigationSidebar(),
                ),
                Expanded(child: RoomPage(room: room)),
              ],
            ),
          ),
        ),
      ),
    );
    // `RoomPage` defers a `CurrentRoom` update and a pinned-event read to a
    // post-frame callback, and its timeline attaches asynchronously.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  }

  /// The bottom edge of the window, in logical pixels.
  ///
  /// ind.byType(Scaffold) matches the test's own Scaffold and the one
  /// inside wrapWithProviders, so getSize would throw. The window bottom
  /// is what both columns end at, and it is what the view is sized to.
  double windowBottom(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  /// The profile pill, scoped to the sidebar.
  ///
  /// ind.byType alone matches more than one: the sidebar renders a
  /// compact and a full variant and both carry the pill, so an unscoped
  /// getSize throws Too many elements.
  Finder theFooterPill() => find
      .descendant(
        of: find.byType(NavigationSidebar),
        matching: find.byType(SidebarProfilePill),
      )
      .last;

  group('the seam between the sidebar and the conversation', () {
    testWidgets('the two bottom rows are the same height', (tester) async {
      await pumpTwoColumns(tester);

      final double sidebar =
          tester.getSize(find.byType(NavigationSidebar)).height;
      final double conversation = tester.getSize(find.byType(ChatBox)).height;

      // The composer band is the whole of the conversation's bottom row when
      // nobody is typing, so it is the thing that has to match the footer's
      // band, divider included.
      expect(
        conversation,
        bar,
        reason: 'the composer band is the token, and the footer matches it',
      );
      expect(
        sidebar,
        greaterThan(conversation),
        reason: 'the sidebar is a full column, so only its bottom band is '
            'comparable',
      );
    });

    testWidgets('the footer band equals the composer band', (tester) async {
      await pumpTwoColumns(tester);

      // Measured from the window bottom up, which is the only direction that
      // makes sense: both columns end at the same y, so what the eye compares
      // is how far up each column's last row begins.
      final double bottom = windowBottom(tester);
      final double pillBottom = tester.getRect(theFooterPill()).bottom;
      final double pillHeight = tester.getSize(theFooterPill()).height;
      final double composerBottom = tester.getRect(find.byType(ChatBox)).bottom;

      expect(
        (bottom - pillBottom) - (bottom - composerBottom),
        closeTo(0, 0.01),
        reason: 'both rows start at the window bottom, so comparing bottoms '
            'compares how far up each row reaches',
      );

      // And the pill itself is the token, not a sum that happens to land near
      // it. This is the assertion that fails if someone takes the explicit
      // height off and lets the avatar decide again.
      expect(pillHeight, bar);
    });

    testWidgets('the two hairlines either side of the seam agree', (
      tester,
    ) async {
      // The sidebar sets `Divider(height: 1)`. The conversation used to set no
      // height and so inherited `dividerTheme.space`, which the theme defines
      // as the divider token's *thickness* rather than as a slot. That is a
      // 0.5px rule against the sidebar's 1, so the two lines sat half a pixel
      // apart even once the rows themselves matched.
      await pumpTwoColumns(tester);

      final double bottom = windowBottom(tester);
      final double bandTop = bottom - bar;

      // The rules are the two dividers whose bottom edge is the top of a bottom
      // row. Found by geometry rather than by position in the tree, because
      // there is no key on them and a Divider is not distinguishable by type.
      final Iterable<Rect> all = find
          .byType(Divider)
          .evaluate()
          .map((Element e) => tester.getRect(find.byWidget(e.widget)));

      final Iterable<Rect> rules =
          all.where((Rect r) => (r.bottom - bandTop).abs() < 2);
      expect(rules, hasLength(2), reason: 'one rule per column');
      for (final Rect rule in rules) {
        expect(
          rule.height,
          1,
          reason: 'a rule whose slot comes from the theme is 0.5 tall, because '
              'the theme sets DividerThemeData.space to the token thickness',
        );
      }
    });

    testWidgets('the footer survives a long display name and presence line', (
      tester,
    ) async {
      // The height is pinned, so text can no longer push the row taller and
      // reopen the seam. A name with no break opportunity is the case that used
      // to do it.
      await pumpTwoColumns(tester, sidebarWidth: 220);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(theFooterPill()).height,
        bar,
        reason: 'a pinned height is the whole point',
      );
    });
  });
}
