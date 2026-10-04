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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/image_viewer_screen.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

import '../helpers/mocks.dart';

/// A valid 1x1 transparent PNG.
///
/// The structural assertions do not care what the picture looks like, and
/// generating a real one needs `runAsync`, which cannot be used from a plain
/// `pump` loop. One real, decodable image is enough for them.
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

MockEvent _event({String body = 'cat.png'}) {
  final event = MockEvent();
  when(() => event.body).thenReturn(body);
  when(() => event.eventId).thenReturn(r'$event');
  when(() => event.roomId).thenReturn('!room:matrix.org');
  when(() => event.originServerTs).thenReturn(
    DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
  when(() => event.content).thenReturn(<String, dynamic>{
    'info': <String, dynamic>{'mimetype': 'image/png'},
  });
// The viewer reads the sender's name for its top bar, so the mock has to
  // answer it: an unstubbed `calcDisplayname` returns null and the build throws
  // before a single widget is laid out.
  final sender = MockUser();
  when(() => sender.calcDisplayname()).thenReturn('Ada');
  when(() => event.senderFromMemoryOrFallback).thenAnswer((_) => sender);
  return event;
}

Future<void> _pump(
  WidgetTester tester,
  Uint8List bytes, {
  String body = '',
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? MoonrelayTheme.dark(
              const Color(0xFF7C5DFA),
              density: LayoutDensity.comfortable,
              fontFamily: 'Rubik',
              displayFontFamily: 'SpaceGrotesk',
              monoFontFamily: 'FiraCode',
              enableAnimations: true,
            )
          : MoonrelayTheme.light(
              const Color(0xFF7C5DFA),
              density: LayoutDensity.comfortable,
              fontFamily: 'Rubik',
              displayFontFamily: 'SpaceGrotesk',
              monoFontFamily: 'FiraCode',
              enableAnimations: true,
            ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ImageViewerScreen(bytes: bytes, event: _event(body: body)),
    ),
  );
  await tester.pump();
}

/// The percentage the zoom readout is showing.
String _readout(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .firstWhere((s) => s.contains('%'));

void main() {
  group('ImageViewerScreen', () {
    testWidgets('shows the whole picture, whatever the aspect ratio',
        (tester) async {
      // The regression this pass exists for. The image used to be laid out
      // with `BoxFit.cover` at viewport size, so a picture whose aspect ratio
      // disagreed with the window lost its edges: a portrait in a landscape
      // window was cropped top and bottom, silently, with nothing to say there
      // was more to see. That is wallpaper behaviour.
      await _pump(tester, _png1x1);

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        image.fit,
        BoxFit.contain,
        reason: 'a viewer that crops the picture is not a viewer',
      );
    });

    testWidgets('has zoom controls, not only a hint about them',
        (tester) async {
      await _pump(tester, _png1x1);

      // The old chrome said "pinch to zoom" in a permanent line of text and
      // offered nothing to click. On a desktop there is no pinch, so the hint
      // described a gesture the reader could not perform and the thing that
      // would have worked was undocumented.
      expect(find.bySemanticsLabel('Zoom in'), findsOneWidget);
      expect(find.bySemanticsLabel('Zoom out'), findsOneWidget);
    });

    testWidgets('the zoom readout reports a percentage', (tester) async {
      await _pump(tester, _png1x1);

      // Whatever it is relative to, it is a number, and that is what makes the
      // other two buttons mean something.
      expect(_readout(tester), '100%');
    });

    testWidgets('zooming in then out returns to the fitted scale',
        (tester) async {
      await _pump(tester, _png1x1);

      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_readout(tester), isNot('100%'));

      await tester.tap(find.bySemanticsLabel('Zoom out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_readout(tester), '100%');
    });

    testWidgets('the caption is shown only when the sender wrote one',
        (tester) async {
      await _pump(tester, _png1x1, body: 'look at this');
      expect(find.text('look at this'), findsOneWidget);

      await _pump(tester, _png1x1, body: '');
      expect(find.text('look at this'), findsNothing);
    });

    testWidgets('does not paint a permanent gesture hint', (tester) async {
      await _pump(tester, _png1x1);

      expect(find.textContaining('pinch'), findsNothing);
    });

    testWidgets('sits on the stated media backdrop, in both brightnesses',
        (tester) async {
      // A viewer is a hole in the app: a photograph must not sit on a light grey
      // rectangle in light mode. Both full-screen media surfaces have to agree,
      // and they had not.
      for (final brightness in Brightness.values) {
        await _pump(tester, _png1x1, brightness: brightness);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final expected = Theme.of(
          tester.element(find.byType(ImageViewerScreen)),
        ).moonrelay.layers.mediaBackdrop;

        expect(scaffold.backgroundColor, expected, reason: brightness.name);
      }
    });

testWidgets('the metadata row reports type and size before the decode lands',
        (tester) async {
      // The dimensions come from a real codec, which the fake clock a `pump`
      // loop runs on cannot resolve, so what is asserted here is the part that
      // is available immediately: the row is there, it is not empty, and it
      // holds the facts that do not need the picture decoded. The dimension
      // label is asserted *absent* rather than skipped, so this also pins that
      // it is conditional rather than rendered as a placeholder.
      await _pump(tester, _png1x1);

      expect(find.text('.png'), findsOneWidget);
      expect(find.textContaining('B'), findsOneWidget);
      expect(find.textContaining('×'), findsNothing);
    });
  });
}


