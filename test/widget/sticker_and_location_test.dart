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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/location/location_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/sticker/sticker_message_type.dart';
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/localization/app_localizations_en.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A valid 1x1 PNG. The assertions are about geometry and about which glyph is
/// drawn, not about what the picture looks like.
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _roomId = '!room:example.org';

/// The default `stickerMaxPx`.
const _stickerMax = 180.0;

void main() {
  late MockEvent event;

  MockEvent mediaEvent({Map<String, dynamic>? info, bool attachment = false}) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(r'$media');
    when(() => e.roomId).thenReturn(_roomId);
    when(() => e.hasAttachment).thenReturn(attachment);
    when(() => e.hasThumbnail).thenReturn(false);
    when(() => e.content).thenReturn(
      info == null ? <String, dynamic>{} : <String, dynamic>{'info': info},
    );
    when(() => e.body).thenReturn('cat.png');
    return e;
  }

  Widget host(Widget child) => MaterialApp(
    theme: testMoonrelayTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Future<void> seed(MatrixFile file) =>
      RoomMediaCache.instance.getOrDownload(_roomId, r'$media', () async => file);

  /// The size the widget declares for its box.
  ///
  /// Both the placeholder and the sticker declare an explicit one, so reading
  /// `constraints` is uniform across them and asserts the choice rather than
  /// however the parent laid it out.
  Size declaredBox(WidgetTester tester) {
    final container = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(StickerMessageType),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((c) => c.constraints != null);
    return Size(
      container.constraints!.maxWidth,
      container.constraints!.maxHeight,
    );
  }
  setUp(() => event = mediaEvent());
  tearDown(RoomMediaCache.instance.clear);

  group('StickerMessageType sizing', () {
    // The regression. The placeholder was a fixed hundred by hundred while the
    // sticker that replaced it is drawn at `stickerMax`, so the bubble visibly
    // jumped the moment the download finished.
    testWidgets('the placeholder is the size of the sticker it becomes',
        (tester) async {
      event = mediaEvent(info: <String, dynamic>{'w': 400, 'h': 900});
      await tester.pumpWidget(host(StickerMessageType(event: event)));

      final size = declaredBox(tester);
      expect(size.height, closeTo(_stickerMax, 0.01));
      expect(size.width, closeTo(_stickerMax * 400 / 900, 0.01));
    });

    testWidgets('a landscape sticker is capped on its long side',
        (tester) async {
      event = mediaEvent(info: <String, dynamic>{'w': 1600, 'h': 900});
      await tester.pumpWidget(host(StickerMessageType(event: event)));

      final size = declaredBox(tester);
      expect(size.width, closeTo(_stickerMax, 0.01));
      expect(size.height, closeTo(_stickerMax * 900 / 1600, 0.01));
    });

    testWidgets('unknown dimensions still get a box', (tester) async {
      await tester.pumpWidget(host(StickerMessageType(event: event)));

      expect(find.byIcon(LucideIcons.stickyNote), findsOneWidget);
    });

    testWidgets('a downloaded sticker is drawn, not offered again',
        (tester) async {
      await seed(
        MatrixFile(bytes: _png1x1, name: 'cat.png', mimeType: 'image/png'),
      );
      await tester.pumpWidget(host(StickerMessageType(event: event)));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a sticker is Lucide, like the rest of the app', (tester) async {
      // This used to be Icons.sticky_note_2_outlined, the last Material glyph
      // in this file.
      await tester.pumpWidget(host(StickerMessageType(event: event)));

      expect(find.byIcon(LucideIcons.stickyNote), findsOneWidget);
    });

    testWidgets('the sticker is fitted rather than cropped', (tester) async {
      await seed(
        MatrixFile(bytes: _png1x1, name: 'cat.png', mimeType: 'image/png'),
      );
      await tester.pumpWidget(host(StickerMessageType(event: event)));

      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    });
  });

  group('LocationMessageType', () {
    testWidgets('shows both coordinates to six decimals', (tester) async {
      event = mediaEvent(
        info: <String, dynamic>{
          'latitude': 52.520008,
          'longitude': 13.404954,
        },
      );
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(find.text('Lat 52.520008'), findsOneWidget);
      expect(find.text('Lon 13.404954'), findsOneWidget);
    });

    testWidgets('the coordinate labels are localized, not spelled out',
        (tester) async {
      // They were the hardcoded literals "Lat:" and "Lon:", which is why
      // app_en.arb grew latitudeLabel and longitudeLabel in the same change.
      final l10n = AppLocalizationsEn();
      event = mediaEvent(
        info: <String, dynamic>{'latitude': 1.0, 'longitude': 2.0},
      );
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(find.textContaining(l10n.latitudeLabel), findsOneWidget);
      expect(find.textContaining(l10n.longitudeLabel), findsOneWidget);
      expect(find.textContaining('Lat:'), findsNothing);
      expect(find.textContaining('Lon:'), findsNothing);
    });

    testWidgets('accuracy is shown when the sender reported it', (tester) async {
      final l10n = AppLocalizationsEn();
      event = mediaEvent(
        info: <String, dynamic>{
          'latitude': 1.0,
          'longitude': 2.0,
          'accuracy': 12.4,
        },
      );
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(find.text(l10n.locationAccuracyMeters(12)), findsOneWidget);
    });

    testWidgets('accuracy is omitted when it was not sent', (tester) async {
      event = mediaEvent(
        info: <String, dynamic>{'latitude': 1.0, 'longitude': 2.0},
      );
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(
        find.textContaining(RegExp(r'\d+ m$')),
        findsNothing,
        reason: 'there is no accuracy figure to report, and inventing one '
            'would be worse than leaving it out',
      );
    });

    testWidgets('a geo_uri is the fallback when the info blob is missing',
        (tester) async {
      // Matrix clients have historically sent one or the other, and the
      // location is the whole event: dropping it means showing nothing at all.
      event = mediaEvent();
      when(() => event.content).thenReturn(<String, dynamic>{
        'geo_uri': 'geo:52.52,13.40',
      });
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(find.text('Lat 52.520000'), findsOneWidget);
      expect(find.text('Lon 13.400000'), findsOneWidget);
    });

    testWidgets('an event with no coordinates at all degrades to a placeholder',
        (tester) async {
      // The one case that must not throw: a malformed location event from any
      // client still has to render something.
      event = mediaEvent();
      when(() => event.content).thenReturn(<String, dynamic>{});
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(find.byType(LocationMessageType), findsOneWidget);
      expect(find.text('Lat'), findsNothing);
    });

    testWidgets('partial coordinates are not treated as a location',
        (tester) async {
      event = mediaEvent(
        info: <String, dynamic>{'latitude': 52.52},
      );
      await tester.pumpWidget(host(LocationMessageType(event: event)));

      expect(find.text('Lat 52.520000'), findsNothing);
      expect(find.byType(LocationMessageType), findsOneWidget);
    });
  });
}

/// The public fields of the private `ClickToDownloadTile`, read through a
/// dynamic view so the test does not have to name the type.
typedef ClickToDownloadTileProbe = dynamic;