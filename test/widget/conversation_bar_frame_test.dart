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

// The conversation's two frames, measured rather than assumed.
//
// `paneBarHeight`'s own doc claims the room header and the composer are the same
// height so the message list reads as framed. They were not. The header read the
// token as a hard `height` with horizontal-only padding, so it was exactly 52.
// The composer read the same token as a `minHeight` on an interior pill and
// then added `spaceSm` above and `spaceMd` below around itself, so its band was
// 72, twenty pixels taller than the bar framing it. Its controls were also
// bottom-aligned, putting them four pixels below the header's.
//
// The test that claimed to cover this pair, `pane_bar_consistency_test.dart`,
// built two `SizedBox(height: h)` and compared them. That is `h == h`, so it
// passed no matter what either widget rendered, and the twenty pixels went
// unnoticed. These mount the real widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/room_info_card.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

class _HeaderClient extends Mock implements Client {
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final double bar = MoonrelayDesignTokens.standard().paneBarHeight;

  MockRoom stubRoom(Client client) {
    final MockRoom room = MockRoom();
    when(() => room.id).thenReturn('!r:example.org');
    when(() => room.client).thenReturn(client);
    when(() => room.getLocalizedDisplayname()).thenReturn('General');
    when(() => room.topic).thenReturn('Anything at all');
    when(() => room.avatar).thenReturn(null);
    when(() => room.canonicalAlias).thenReturn('');
    when(() => room.encrypted).thenReturn(false);
    when(() => room.isDirectChat).thenReturn(false);
    when(() => room.isSpace).thenReturn(false);
    when(() => room.joinRules).thenReturn(JoinRules.public);
    when(() => room.summary).thenReturn(
      RoomSummary.fromJson(const <String, Object?>{
        'm.joined_member_count': 2,
      }),
    );
    return room;
  }

  /// The composer's decorated pill, found by its radius.
  ///
  /// The reply preview and the formatting toolbar are also decorated containers
  /// in the same region, so a bare "descendant of ChatBox that is an
  /// AnimatedContainer" would find whichever happens to come first.
  Finder thePill() => find.descendant(
        of: find.byType(ChatBox),
        matching: find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(9999),
        ),
      );

  /// The two bars stacked the way `RoomPage` stacks them, over a filler
  /// conversation.
  Future<void> pumpConversation(
    WidgetTester tester, {
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _HeaderClient client = _HeaderClient();
    when(() => client.getRoomById(any())).thenReturn(null);
    final Room room = stubRoom(client);

    // `wrapWithProviders` supplies the theme, the delegates and the providers.
    // No `MaterialApp` of its own here: nesting one would replace the
    // localizations scope and `ChatBox` resolves `AppLocalizations.of(context)!`
    // during build, which throws and leaves both bars laid out at no height.
    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: 900,
            child: Column(
              children: <Widget>[
                ChatRoomHeader(room: room),
                const Expanded(child: ColoredBox(color: Colors.black)),
                ChatBox(room: room),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  group('the two bars that frame the conversation', () {
    testWidgets('are the same height', (tester) async {
      await pumpConversation(tester);

      final double header = tester.getSize(find.byType(ChatRoomHeader)).height;
      final double composer = tester.getSize(find.byType(ChatBox)).height;

      expect(
        header,
        composer,
        reason: 'a message list between two different-height strips does not '
            'read as framed',
      );
      expect(header, bar);
      expect(composer, bar);
    });

    testWidgets('and still are at a width that used to shrink the header', (
      tester,
    ) async {
      // Below 400px the header used to drop to `paneBarHeight - 4` while the
      // composer had no idea how wide the room was, so the frame came apart in
      // exactly the panes where there was least room for it. `tight` is for the
      // horizontal padding and the topic, both of which are free.
      await pumpConversation(tester, width: 340);

      expect(tester.getSize(find.byType(ChatRoomHeader)).height, bar);
      expect(tester.getSize(find.byType(ChatBox)).height, bar);
    });

    testWidgets('and the composer keeps its pill off the window edge', (
      tester,
    ) async {
      // The band is the bar now, which is only safe because the pill is inset
      // inside it. A pill flush to the bottom of the window would clip its own
      // rounded corners on a compositor with rounded window corners.
      await pumpConversation(tester);

      final double composer = tester.getSize(find.byType(ChatBox)).height;
      final double pill = tester.getSize(thePill()).height;

      expect(pill, lessThan(composer), reason: 'there must be an inset');
      // Exactly the two 4px insets, so the band and the pill cannot drift apart
      // again by one of them changing.
      expect(composer - pill, closeTo(8, 0.01));
    });

    testWidgets('and their controls sit at the same height', (tester) async {
      // Matching heights is not the same as aligning the icons inside them. The
      // composer's row was `CrossAxisAlignment.end`, which put every control
      // four pixels below where the header's sit, and that is the part the eye
      // reads when it says the two bars disagree.
      //
      // Measured relative to each bar's own top edge, not to the window. The two
      // controls are hundreds of pixels apart vertically by design, one at each
      // end of the conversation, so comparing their screen positions would only
      // be measuring how tall the test surface is.
      await pumpConversation(tester);

      final Rect header = tester.getRect(find.byType(ChatRoomHeader));
      final Rect composer = tester.getRect(find.byType(ChatBox));
      final double headerGear =
          tester.getCenter(find.byIcon(LucideIcons.settings).last).dy;
      final double send =
          tester.getCenter(find.byIcon(LucideIcons.send).last).dy;

      // Both land within half a pixel of the middle of their own bar: the gear
      // at 25.5 and the send button at 26, against a 52-tall bar.
      expect(headerGear - header.top, closeTo(bar / 2, 1));
      expect(send - composer.top, closeTo(bar / 2, 1));

      // Tolerance is 1px on purpose. `CrossAxisAlignment.end` on a 44px pill
      // holding a 36px control puts it 4px lower, which is visible as the two
      // bars disagreeing even though their heights match, and a loose tolerance
      // of 4 would have waved it through. Checked by mutation.
      expect(
        (send - composer.top) - (headerGear - header.top),
        closeTo(0, 1),
      );

      // Both a little above centre rather than exactly on it: the composer sits
      // 4px below the top of its band because of the inset, and the gear sits
      // above centre because the header's text block is two lines. What matters
      // is that they agree, so the assertion is the difference between them.
      expect(
        (send - composer.top) - (headerGear - header.top),
        closeTo(0, 4),
        reason: 'a control in the lower bar should sit as far into its bar as '
            'a control in the upper one',
      );
    });
  });

  group('what this replaced', () {
    testWidgets('the token alone was never enough', (tester) async {
      // Both widgets read `paneBarHeight` before this change and still came out
      // twenty pixels apart, because one used it as a height and the other as a
      // minimum for an interior box with its own padding around it. Recorded as
      // a test so the token is not mistaken for the guarantee.
      await pumpConversation(tester);

      final double composer = tester.getSize(find.byType(ChatBox)).height;
      expect(composer, isNot(bar + 20));
      expect(composer, bar);
    });
  });
}

/// `SharedPreferences` is only touched by the settings providers inside
/// `wrapWithProviders`, which need an in-memory backing store.
class SharedPreferencesMock {
  static void ensure() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
}
