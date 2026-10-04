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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/fullscreen_video_player.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/theme/surface_layers.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../helpers/fake_video_player_platform.dart';

late VideoPlayerPlatform _originalPlatform;

/// Builds a controller the fake platform is happy with, and a widget tree that
/// has the app's theme, because the player reads its colours and its spacing
/// from `MoonrelayThemeExtension` rather than from `Theme.of` alone.
Future<VideoPlayerController> _controller(
  FakeVideoPlayerPlatform platform,
) async {
  final controller = VideoPlayerController.networkUrl(
    Uri.parse('https://example.test/clip.mp4'),
  );
  // `initialize` subscribes to the platform event stream before it returns, so
  // the initialized event has to be sent once the subscription exists rather
  // than once the future is built.
  final ready = controller.initialize();
  await pumpEventQueue();
  platform.emitInitialized();
  await ready;
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  VideoPlayerController controller, {
  bool behind = false,
  bool settleChrome = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MoonrelayTheme.dark(
        const Color(0xFF7C5DFA),
        density: LayoutDensity.comfortable,
        fontFamily: 'Rubik',
        displayFontFamily: 'SpaceGrotesk',
        monoFontFamily: 'FiraCode',
        enableAnimations: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: behind
          ? const Scaffold(body: Center(child: Text('behind')))
          : FullscreenVideoPlayer(controller: controller),
    ),
  );
  await tester.pump();
  if (settleChrome) await _settleChrome(tester);
}

/// Sends a key and settles the chrome the keypress just rescheduled.
///
/// Every interaction here calls `_showChrome`, so a test that acts after
/// mounting has to settle a second time or it ends on a pending timer.
Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await _settleChrome(tester);
}

/// Lets the three second chrome auto-hide fire and finish reversing.
/// Not optional in practice: the widget schedules a real `Timer` on mount, and
/// `flutter_test` asserts that no timer outlives the tree. A test that leaves it
/// pending does not fail on its own expectation, it fails on the leak check, and
/// the message says nothing about which test was wrong.
Future<void> _settleChrome(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
}

/// Pushes the player over a route, so `Navigator.pop` has somewhere to go and
/// the escape key can be tested for what it is for.
Future<void> _pushOver(
  WidgetTester tester,
  VideoPlayerController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MoonrelayTheme.dark(
        const Color(0xFF7C5DFA),
        density: LayoutDensity.comfortable,
        fontFamily: 'Rubik',
        displayFontFamily: 'SpaceGrotesk',
        monoFontFamily: 'FiraCode',
        enableAnimations: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Center(child: Text('behind'))),
    ),
  );
  Navigator.of(tester.element(find.text('behind'))).push(
    MaterialPageRoute<void>(
      builder: (_) => FullscreenVideoPlayer(controller: controller),
    ),
  );
  // Settled, not a single pump: a route transition takes several frames, and
  // until it finishes the route underneath is still in the tree.
  await tester.pumpAndSettle();
  await _settleChrome(tester);
}

void main() {
  setUp(() => _originalPlatform = VideoPlayerPlatform.instance);

  group('FullscreenVideoPlayer', () {
    late FakeVideoPlayerPlatform platform;
    late VideoPlayerController controller;

    setUp(() async {
      platform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = platform;
      controller = await _controller(platform);
    });

    tearDown(() async {
      // Disposed before the instance is restored: the controller holds the
      // platform it was built with, and handing its teardown to the real
      // platform is how a test starts throwing UnimplementedError at itself.
      await controller.dispose();
      VideoPlayerPlatform.instance = _originalPlatform;
      await platform.close();
    });

    testWidgets('the surface is the app media backdrop', (tester) async {
      // The image viewer and this player used to disagree on what "behind the
      // picture" was, which showed as a seam when a user moved between a
      // video and a still in the same conversation.
      await _pump(tester, controller);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        MoonrelaySurfaceLayers.forBrightness(Brightness.dark).mediaBackdrop,
      );
    });

    testWidgets('system icons are light, because this surface is',
        (tester) async {
      // The screen is near-black in both brightnesses, so the theme's own
      // overlay style would put dark system icons on a black surface in light
      // mode.
      await _pump(tester, controller);

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('the space bar pauses a playing video', (tester) async {
      // The operation people reach for most, and the one this player could not
      // do from the keyboard at all.
      await _pump(tester, controller);
      platform.emitPlayingState(true);
      await tester.pump();

      await _press(tester, LogicalKeyboardKey.space);

      expect(platform.calls, contains('pause'));
    });

    testWidgets('the space bar starts a paused video', (tester) async {
      await _pump(tester, controller);

      await _press(tester, LogicalKeyboardKey.space);

      expect(platform.calls, contains('play'));

      // Pressed again so the video is left paused. `play` starts a 100ms
      // position poller inside the controller, and `flutter_test` fails the
      // test for any timer still running when the tree goes away, which has
      // nothing to do with what is being asserted here.
      await _press(tester, LogicalKeyboardKey.space);
    });

    testWidgets('the arrow keys seek', (tester) async {
      await _pump(tester, controller);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(platform.position, const Duration(seconds: 5));

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(platform.position, Duration.zero);
    });

    testWidgets('escape leaves the player', (tester) async {
      await _pushOver(tester, controller);
      expect(find.text('behind'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('behind'), findsOneWidget);
    });

    testWidgets('the m key mutes, and the control says so', (tester) async {
      // A keyboard-only mute with no visible state would be a trap: the video
      // goes silent and nothing says why.
      await _pump(tester, controller, settleChrome: false);
      final unmute = find.byTooltip('Unmute');

      await _press(tester, LogicalKeyboardKey.keyM);

      expect(platform.volume, 0);
      expect(unmute, findsOneWidget);
    });

    testWidgets('the control labels come from the app locale', (tester) async {
      // These were hardcoded English: '-10s', '+5s', 'Play', 'Pause'.
      await _pump(tester, controller);

      expect(find.byTooltip('Back 10s'), findsOneWidget);
      expect(find.byTooltip('Forward 5s'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('the chrome timer does not outlive the player', (tester) async {
      // The auto-hide was a bare `Future.delayed`, so opening and closing a
      // video left a live three second timer on the event loop every time.
      // Pumping without settling is deliberate: the timer really is pending
      // here, which is the condition this test exists to cover.
      await _pump(tester, controller, settleChrome: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  });
}
