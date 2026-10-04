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
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/audio/audio_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/file/file_attached_message.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/video_message_type.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/localization/app_localizations_en.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// The information blob the attachment rows read for a file name and a size.
Map<String, dynamic> _info({String body = '', String mimetype = 'application/octet-stream', int? size}) =>
    <String, dynamic>{
      'info': <String, dynamic>{
        'mimetype': mimetype,
        'size': size,
        'mimetype_body': body,
      },
    };

void main() {
  final l10n = AppLocalizationsEn();
  late MockEvent event;

  MockEvent rowEvent({Map<String, dynamic>? content, bool attachment = true}) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(r'$file');
    when(() => e.roomId).thenReturn('!room:example.org');
    when(() => e.hasAttachment).thenReturn(attachment);
    when(() => e.hasThumbnail).thenReturn(false);
    when(() => e.content).thenReturn(
      content ??
          <String, dynamic>{'msgtype': 'm.file', 'filename': 'report.pdf'},
    );
    when(() => e.body).thenReturn('report.pdf');
    when(() => e.senderId).thenReturn('@ada:example.org');
    when(() => e.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1700000000000));
    return e;
  }

  /// The rows take their type size from `sidebarMetricsFor`, which reads the
  /// density off `SettingsController`, so a harness without it throws inside
  /// the build rather than failing an assertion.
  Widget host(Widget child) => ChangeNotifierProvider<SettingsController>(
    create: (_) => createTestSettingsController(),
    child: MaterialApp(
      theme: testMoonrelayTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  setUp(() => event = rowEvent());

  group('FileAttachedMessage', () {
    testWidgets('shows the file name from the event body', (tester) async {
      await tester.pumpWidget(host(FileAttachedMessage(event: event)));

      expect(find.textContaining('report.pdf'), findsWidgets);
    });

    testWidgets('says unknown rather than showing an empty name',
        (tester) async {
      // An event with no body at all must not render a row with a blank line
      // where the name goes.
      event = rowEvent(content: <String, dynamic>{'msgtype': 'm.file'});
      await tester.pumpWidget(host(FileAttachedMessage(event: event)));

      expect(find.text(l10n.unknown), findsOneWidget);
    });

    testWidgets('offers a download, labelled as a file and not as audio',
        (tester) async {
      // This label was l10n.downloadAudio, copied from the audio row, so a
      // screen reader called a spreadsheet an audio file.
      await tester.pumpWidget(host(FileAttachedMessage(event: event)));

      expect(find.bySemanticsLabel(l10n.downloadFile), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.downloadAudio), findsNothing);
    });

    testWidgets('a download is offered even when the event has no attachment',
        (tester) async {
      // Pinned because it is not obviously right either way: an m.file event
      // with no url is malformed, and the row draws the button anyway rather
      // than hiding it. Recorded in WORK_NEEDED rather than changed here.
      event = rowEvent(attachment: false);
      await tester.pumpWidget(host(FileAttachedMessage(event: event)));

      expect(find.bySemanticsLabel(l10n.downloadFile), findsOneWidget);
    });

    testWidgets('shows a reported file size', (tester) async {
      event = rowEvent(content: <String, dynamic>{
        'msgtype': 'm.file',
        'filename': 'movie.mkv',
        ..._info(size: 5 * 1024 * 1024),
      });
      await tester.pumpWidget(host(FileAttachedMessage(event: event)));

      expect(find.textContaining('5'), findsWidgets);
    });
  });

  group('AudioMessageType', () {
    testWidgets('renders with no attachment rather than throwing',
        (tester) async {
      event = rowEvent(attachment: false);
      await tester.pumpWidget(host(AudioMessageType(event: event)));

      expect(find.byType(AudioMessageType), findsOneWidget);
    });

    testWidgets('offers a download labelled as audio', (tester) async {
      await tester.pumpWidget(host(AudioMessageType(event: event)));

      expect(find.bySemanticsLabel(l10n.downloadAudio), findsOneWidget);
    });

    testWidgets('a playback control is present and announced', (tester) async {
      // The row is a player: a user needs to be able to start it, and a
      // screen reader user needs to be told what the control does.
      await tester.pumpWidget(host(AudioMessageType(event: event)));

      expect(
        find.bySemanticsLabel(RegExp(l10n.playAudio)),
        findsWidgets,
      );
    });
  });

  group('VideoMessageType', () {
    testWidgets('renders with no attachment rather than throwing',
        (tester) async {
      event = rowEvent(attachment: false);
      await tester.pumpWidget(host(VideoMessageType(event: event)));

      expect(find.byType(VideoMessageType), findsOneWidget);
    });

    testWidgets('offers a download labelled as video', (tester) async {
      await tester.pumpWidget(host(VideoMessageType(event: event)));

      expect(find.bySemanticsLabel(l10n.downloadVideo), findsOneWidget);
    });

    testWidgets('the file name appears, so the row is identifiable',
        (tester) async {
      await tester.pumpWidget(host(VideoMessageType(event: event)));

      expect(find.textContaining('report.pdf'), findsWidgets);
    });
  });
}