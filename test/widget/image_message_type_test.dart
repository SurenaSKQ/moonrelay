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
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/image/image_message_type.dart';
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/screens/image_viewer_screen.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A valid 1x1 PNG. The assertions are about geometry, decoding budget and
/// what a tap does, not about what the picture looks like, and one real
/// decodable image is enough for all three.
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _roomId = '!room:example.org';
const _eventId = r'$image1';

/// The default `imageThumbnailMaxPx`, which is also this widget's own
/// fallback, so these tests pin the shipped size rather than a test-only one.
const _maxDim = 360.0;

void main() {
  late MockEvent event;

  /// A [MockEvent] that reports [info] as its attachment info block.
  ///
  /// `hasAttachment` is false by default so the widget takes the placeholder
  /// path without touching the network, which is how the sizing tests get a
  /// box to measure.
  MockEvent imageEvent({Map<String, dynamic>? info, bool attachment = false}) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(_eventId);
    when(() => e.roomId).thenReturn(_roomId);
    when(() => e.hasAttachment).thenReturn(attachment);
    when(() => e.hasThumbnail).thenReturn(false);
    when(() => e.content).thenReturn(
      info == null ? <String, dynamic>{} : <String, dynamic>{'info': info},
    );
    when(() => e.body).thenReturn('cat.png');
    // And the send time, which the viewer's top bar formats.
    when(() => e.originServerTs).thenReturn(
      DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    // The full-screen viewer puts the sender's name in its top bar, so an
    // unstubbed `calcDisplayname` returns null and the viewer throws in build
    // before a widget is laid out.
    final sender = MockUser();
    when(() => sender.calcDisplayname()).thenReturn('Ada');
    when(() => e.senderFromMemoryOrFallback).thenAnswer((_) => sender);
    return e;
  }

  /// Puts [file] into the shared media cache so the widget's fast path finds
  /// it and renders the thumbnail synchronously, with no download and no
  /// pending future to pump.
  Future<void> seed(MatrixFile file) =>
      RoomMediaCache.instance.getOrDownload(_roomId, _eventId, () async => file);

  /// The size the widget declares for its box.
  ///
  /// Read off the widget's `constraints` rather than through `getSize`,
  /// because `Container` is a composite and the element a size lookup finds is
  /// not necessarily the constrained one. Both the placeholder and the
  /// thumbnail declare an explicit box, so this is uniform across them, and it
  /// asserts the intent (this is the size we chose) rather than the result of
  /// however the parent happened to lay it out.
  Size laidOut(WidgetTester tester) {
    final container = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(ImageMessageType),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((c) => c.constraints != null);
    return Size(
      container.constraints!.maxWidth,
      container.constraints!.maxHeight,
    );
  }

  setUp(() {
    // `updateAutoDownloadImages` persists, and without the mock that write
    // goes to a platform channel that never answers, so the test hangs rather
    // than failing.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    event = imageEvent();
  });

  tearDown(RoomMediaCache.instance.clear);

  group('ImageMessageType sizing', () {
    // The regression. The placeholder was a fixed hundred and twenty square
    // while the thumbnail that replaced it is drawn at up to 360 on its long
    // side, so every image in a conversation tripled in size the moment its
    // download finished, and everything below it jumped.
    testWidgets('the placeholder is the size of the image it becomes',
        (tester) async {
      event = imageEvent(info: <String, dynamic>{'w': 1600, 'h': 900});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(laidOut(tester), const Size(360, 202.5));
    });

    testWidgets('a portrait thumbnail keeps its shape', (tester) async {
      event = imageEvent(info: <String, dynamic>{'w': 400, 'h': 900});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(laidOut(tester), const Size(160, 360));
    });

    testWidgets('a square thumbnail is square', (tester) async {
      event = imageEvent(info: <String, dynamic>{'w': 100, 'h': 100});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(laidOut(tester), const Size(_maxDim, _maxDim));
    });

    testWidgets('a tall portrait never exceeds the long-side limit',
        (tester) async {
      event = imageEvent(info: <String, dynamic>{'w': 1000, 'h': 4000});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      final size = laidOut(tester);
      expect(size.height, _maxDim);
      expect(size.width, lessThanOrEqualTo(_maxDim));
      expect(size.width / size.height, closeTo(0.25, 0.01));
    });

    testWidgets('unknown dimensions still get a box', (tester) async {
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(laidOut(tester).width, greaterThan(0));
      expect(laidOut(tester).height, greaterThan(0));
    });

    testWidgets('a zero dimension is treated as unknown, not as a collapse',
        (tester) async {
      // A sender that reports w:0 would otherwise produce an infinite aspect
      // ratio and a zero-height bubble.
      event = imageEvent(info: <String, dynamic>{'w': 0, 'h': 0});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      final size = laidOut(tester);
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    testWidgets('dimensions sent as doubles are accepted', (tester) async {
      // Matrix has no schema here and some clients send JSON floats.
      event = imageEvent(info: <String, dynamic>{'w': 1600.0, 'h': 900.0});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(laidOut(tester), const Size(360, 202.5));
    });

    testWidgets('the long and short key spellings both work', (tester) async {
      event = imageEvent(info: <String, dynamic>{'width': 1600, 'height': 900});
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(laidOut(tester), const Size(360, 202.5));
    });
  });

  group('ImageMessageType thumbnail', () {
    setUp(() => event = imageEvent(
          info: <String, dynamic>{'w': 1600, 'h': 900, 'mimetype': 'image/png'},
        ));

    testWidgets('decodes at the rendered size, not the source size',
        (tester) async {
      // Without a cacheWidth cap a 4032x3024 photo becomes a ~48 MB ui.Image
      // to be drawn at 360 logical pixels, which is the single largest
      // allocation in the timeline.
      await seed(MatrixFile(bytes: _png1x1, name: 'cat.png', mimeType: 'image/png'));
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      // `cacheWidth` is not readable off the built widget, but it is what
      // `Image.memory` wraps the provider in when one is given, so the
      // decode budget is still observable.
      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image;
      expect(resized, isA<ResizeImage>());
      expect(
        (resized as ResizeImage).width,
        lessThanOrEqualTo((_maxDim * 3).ceil()),
        reason: 'the decode budget must track the drawn size',
      );
    });

    testWidgets('fits rather than crops', (tester) async {
      // The bubble already matches the image's aspect ratio, so cover would
      // crop into something the viewer cannot show either.
      await seed(MatrixFile(bytes: _png1x1, name: 'cat.png', mimeType: 'image/png'));
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    });

    testWidgets('a tap opens the full-screen viewer', (tester) async {
      await seed(MatrixFile(bytes: _png1x1, name: 'cat.png', mimeType: 'image/png'));
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      await tester.tap(find.byType(Image));
      // The push is deferred to the next frame on purpose, so one pump for
      // the callback and one to build the route. Not `pumpAndSettle`: the
      // viewer shows a `CircularProgressIndicator` while it reads the image's
      // natural size, and an animation that never ends means a settle call
      // runs to its ten minute timeout instead of failing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(ImageViewerScreen, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a gif is badged', (tester) async {
      event = imageEvent(
        info: <String, dynamic>{'w': 320, 'h': 240, 'mimetype': 'image/gif'},
      );
      await seed(MatrixFile(bytes: _png1x1, name: 'cat.gif', mimeType: 'image/gif'));
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(find.text('GIF'), findsOneWidget);
    });

    testWidgets('a still image is not badged', (tester) async {
      await seed(MatrixFile(bytes: _png1x1, name: 'cat.png', mimeType: 'image/png'));
      await tester.pumpWidget(wrapWithProviders(child: ImageMessageType(event: event)));

      expect(find.text('GIF'), findsNothing);
    });
  });

  group('ImageMessageType failure', () {
    testWidgets('a failed download offers a retry', (tester) async {
      // The auto-download default is "on wifi", which a test is neither on nor
      // off, so the policy has to be forced or the widget never starts the
      // download and never reaches the error state at all.
      final settings = createTestSettingsController();
      await settings.updateAutoDownloadImages(AutoDownloadPolicy.always);
      event = imageEvent(attachment: true, info: <String, dynamic>{'w': 8, 'h': 8});
      // A future that fails, not a synchronous throw. 	henThrow fires when
      // the stub is called, which for a real download happens inside the
      // future the cache hands out; throwing synchronously instead escapes
      // didChangeDependencies before the FutureBuilder exists.
      when(() => event.downloadAndDecryptAttachment()).thenAnswer(
        (_) => Future<MatrixFile>.error(StateError('server said no')),
      );
      await tester.pumpWidget(
        wrapWithProviders(
          child: ImageMessageType(event: event),
          settingsController: settings,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tap to retry'), findsOneWidget);
    });
  });
}
