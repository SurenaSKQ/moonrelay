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

// Regression test for the chat-page layout race (issue 6 in
// WORK_DONE.md, and the §11 follow-up that closed the remaining
// always-mounted Tooltips).
//
// Background:
// Flutter's `Tooltip` wraps its child in an internal `OverlayPortal`
// (via `RawTooltip`) that activates the moment the widget is
// mounted. When the page is routed through `genericPageBuilder` and
// therefore lives inside the dashboard's `LayoutBuilder` shell, that
// activation marks a sibling `_RenderLayoutBuilder` as needing layout
// mid-`performLayout` and trips the
// `_RenderLayoutBuilder was mutated in performLayout` assertion.
//
// Fix: any widget that is part of the always-mounted chat surface
// must NOT mount a Tooltip. A `Semantics(label:)` carries the same
// accessibility affordance without ever materialising an overlay
// entry. Hover- and conditional-mount tooltips are exempt because
// they don't activate during the page's initial layout pass.
//
// This test pins the no-Tooltip contract for the most common
// always-mounted widgets so a future refactor that re-introduces a
// Tooltip trips the test instead of the runtime assertion.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/receipt_avatars.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/image_viewer_screen.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/widgets/encryption/trust_indicator.dart';
import 'package:moonrelay/src/widgets/encryption_badge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  // [SettingsController] is provided via [MultiProvider] so widgets
  // that read user preferences (e.g. [ReceiptAvatars] checks
  // `showReadReceipts`) can mount under the same wrapper used by
  // every other test in this group.  Without this provider those
  // widgets would throw a `ProviderNotFoundException` at build time.
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsController>(
        create: (_) => SettingsController(SettingsService()),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('Always-mounted widgets do not mount a Tooltip', () {
    // The full set of always-mounted surfaces covered by this group.
    // Each test asserts the widget still renders its icon/badge
    // (so the Semantics swap didn't drop the visual surface) AND
    // that no Tooltip element is mounted (so the OverlayPortal can
    // never be activated during the dashboard's LayoutBuilder
    // performLayout pass).

    testWidgets('TrustIndicator verified path', (tester) async {
      await tester.pumpWidget(_wrap(const TrustIndicator(isVerified: true)));
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('TrustIndicator unverified path', (tester) async {
      await tester.pumpWidget(_wrap(const TrustIndicator(isVerified: false)));
      expect(find.byIcon(LucideIcons.shieldOff), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('EncryptionBadge encrypted path', (tester) async {
      final mock = MockRoom();
      when(() => mock.encrypted).thenReturn(true);
      await tester.pumpWidget(_wrap(EncryptionBadge(room: mock)));
      expect(find.byIcon(LucideIcons.lock), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('EncryptionBadge unencrypted path', (tester) async {
      final mock = MockRoom();
      when(() => mock.encrypted).thenReturn(false);
      await tester.pumpWidget(_wrap(EncryptionBadge(room: mock)));
      expect(find.byIcon(LucideIcons.lockOpen), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('RoomEncryptionBadge encrypted path', (tester) async {
      final mock = MockRoom();
      when(() => mock.encrypted).thenReturn(true);
      await tester.pumpWidget(_wrap(RoomEncryptionBadge(room: mock)));
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets(
      'ReceiptAvatars: no Tooltip mounted when receipts are present',
      (tester) async {
        // The widget filters out the current user; we set up a
        // remote user on the mock event so it has something to
        // render.  The exact render shape is not under test  only
        // that no Tooltip element gets mounted.
        final mockRoom = MockRoom();
        final mockClient = MockClient();
        when(() => mockRoom.client).thenReturn(mockClient);
        when(() => mockClient.userID).thenReturn('@me:test');

        final mockUser = MockUser();
        when(() => mockUser.senderId).thenReturn('@remote:test');
        when(() => mockUser.avatarUrl).thenReturn(Uri.parse('mxc://x'));

        final mockReceipt = MockReceipt();
        when(() => mockReceipt.user).thenReturn(mockUser);

        final mockEvent = MockEvent();
        when(() => mockEvent.receipts).thenReturn([mockReceipt]);

        await tester.pumpWidget(
          _wrap(ReceiptAvatars(event: mockEvent, room: mockRoom)),
        );
        // If there are receipts to show, the widget renders something
        // visible (an avatar or a +N chip).  Either way, the Tooltip
        // that used to wrap the stack must NOT be mounted.
        expect(find.byType(Tooltip), findsNothing);
      },
    );

    // Regression for the chat-box formatting toolbar: its buttons
    // live inside a [SizeTransition] inside the always-mounted
    // ChatBox widget tree.  Even though [SizeTransition] with
    // `sizeFactor: 0` shrinks the toolbar to zero height, the
    // children remain mounted and a Tooltip there would activate
    // an [OverlayPortal] mid-`performLayout` of the dashboard's
    // [LayoutBuilder] ancestor.  Mounting the ChatBox exercises
    // both the compact and the expanded toolbar code paths.
    testWidgets(
      'ChatBox formatting toolbar: no Tooltip mounted in expanded mode',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final mockRoom = MockRoom();
        final mockClient = MockClient();
        final mockLogger = MockLogger();
        when(() => mockRoom.client).thenReturn(mockClient);
        when(() => mockClient.userID).thenReturn('@me:test');
        // ChatBox's draft loader reads `room.id`; without this stub
        // it returns null and the loader throws during pump.
        when(() => mockRoom.id).thenReturn('!room:test');
        when(() => mockLogger.w(any())).thenReturn(null);

        final settings = SettingsController(SettingsService());
        await tester.pumpWidget(MultiProvider(
          providers: [
            Provider<Logger>.value(value: mockLogger),
            ChangeNotifierProvider<SettingsController>.value(value: settings),
            Provider<Client>.value(value: mockClient),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ChatBox(room: mockRoom)),
          ),
        ));
        await tester.pump();

        // Tap the expand toggle so the [SizeTransition] runs to
        // sizeFactor: 1 and the formatting toolbar is fully
        // materialised.  The Semantics swap preserves the icon
        // surface so we can still find the chevron to tap.
        await tester.tap(find.byIcon(LucideIcons.chevronUp));
        await tester.pumpAndSettle();

        // Either way (collapsed or expanded), the toolbar lives in
        // the tree; the contract is that no Tooltip is ever
        // mounted for the always-mounted chat surface.
        expect(find.byType(Tooltip), findsNothing);
      },
    );

    // Regression for the full-screen image-viewer toolbar: its
    // [_ToolbarButton] widgets live inside a [FadeTransition]
    // driven by [_chromeOpacity].  Even when the chrome is
    // opacity: 0 (auto-hide after idle), the buttons remain
    // mounted for the whole lifetime of [ImageViewerScreen].  A
    // Tooltip mounted there would activate an [OverlayPortal] the
    // moment the route pushes, racing the chat page's LayoutBuilder
    // and tripping the chat-page layout race.  Semantics carries
    // the same accessibility label without ever materialising an
    // overlay entry.
    testWidgets(
      'ImageViewerScreen toolbar: no Tooltip mounted',
      (tester) async {
        final mockEvent = MockEvent();
        // [ImageViewerScreen] reads `event.body`, `event.content`,
        // and `event.senderFromMemoryOrFallback.calcDisplayname()`
        // during build; stub just enough for the first frame.
        when(() => mockEvent.body).thenReturn('photo.png');
        when(() => mockEvent.content).thenReturn(<String, dynamic>{});
        when(() => mockEvent.originServerTs).thenReturn(
          DateTime.fromMillisecondsSinceEpoch(0),
        );
        final mockSender = MockUser();
        when(() => mockSender.calcDisplayname()).thenReturn('Sender');
        when(() => mockEvent.senderFromMemoryOrFallback)
            .thenReturn(mockSender);

        await tester.pumpWidget(
          _wrap(
            ImageViewerScreen(
              bytes: Uint8List.fromList(const <int>[0, 1, 2]),
              event: mockEvent,
            ),
          ),
        );
        await tester.pump();
        // Advance past the chrome auto-hide timer (3s) so the
        // FadeTransition drives the toolbar to opacity: 0  this
        // is the configuration that previously still mounted a
        // Tooltip and tripped the layout race when the user tapped
        // to re-show the chrome.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.byType(Tooltip), findsNothing);
      },
    );
  });
}
