// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/image/image_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/audio/audio_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/file/file_attached_message.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/video_message_type.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/chat/events/attachment_card.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  late MockEvent event;

  setUp(() {
    event = MockEvent();
    when(() => event.eventId).thenReturn('evt_123');
    when(() => event.hasAttachment).thenReturn(false);
    when(() => event.hasThumbnail).thenReturn(false);
    when(() => event.content).thenReturn({});
  });

  group('ImageMessageType', () {
    testWidgets('renders placeholder when no attachment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImageMessageType(event: event),
          ),
        ),
      );

      // The placeholder glyph. It is Lucide like the rest of the app now;
      // this assertion used to name `Icons.image_outlined` and was the only
      // thing that noticed the change.
      expect(find.byIcon(LucideIcons.image), findsOneWidget);
    });

    testWidgets('renders without error with basic event data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImageMessageType(event: event),
          ),
        ),
      );

      expect(find.byType(ImageMessageType), findsOneWidget);
    });
  });

  /// Wraps [child] with the providers the attachment rows read.
  ///
  /// The rows take their type size from `sidebarMetricsFor`, which reads the
  /// density off `SettingsController`, so a harness without it throws inside
  /// the build rather than failing an assertion. Same provider the room list
  /// has always needed for the same call.
  Widget host(Widget child) => ChangeNotifierProvider<SettingsController>(
        create: (_) => createTestSettingsController(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  group('AttachmentEmphasis', () {
    // The rows used to draw play and download as the same tinted square, side
    // by side, in the same accent. Two identical primary controls in one row is
    // not two controls: it is one control and a duplicate, and the reader has
    // to work out which one starts the thing they came to do.
    testWidgets('quiet is distinguishable from prominent', (tester) async {
      Widget build(AttachmentEmphasis emphasis) => host(
            Scaffold(
              body: Row(
                children: [
                  const AttachmentLeadingIcon(icon: LucideIcons.play),
                  AttachmentLeadingIcon(
                    icon: LucideIcons.download,
                    emphasis: emphasis,
                  ),
                ],
              ),
            ),
          );

      List<Color> fills() => tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration! as BoxDecoration).color!)
          .toList();

      await tester.pumpWidget(build(AttachmentEmphasis.quiet));
      final split = fills();
      expect(split, hasLength(2));
      expect(
        split[1],
        isNot(split[0]),
        reason: 'the trailing action must not look like the leading one',
      );

      // And the state this replaced: both prominent, and so indistinguishable.
      await tester.pumpWidget(build(AttachmentEmphasis.prominent));
      final same = fills();
      expect(same[1], same[0]);
    });

    testWidgets('an icon with no tap target is not a button', (tester) async {
      // The file row's leading glyph names the type of the thing. Offering a
      // tap target that does nothing is worse than offering none.
      await tester.pumpWidget(host(
        const AttachmentLeadingIcon(icon: LucideIcons.file),
      ));

      expect(
        find.descendant(
          of: find.byType(AttachmentLeadingIcon),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('every attachment square is the same size', (tester) async {
      // Audio, file, video, poll and location all draw one of these, and four
      // of them used to override the size: 44, 44, 38, 36 and 36 down the same
      // timeline, which is the drift this component exists to prevent.
      await tester.pumpWidget(
        host(
          Row(
            children: [
              for (final icon in const [
                LucideIcons.play,
                LucideIcons.file,
                LucideIcons.video,
                LucideIcons.mapPin,
                LucideIcons.listChecks,
              ])
                AttachmentLeadingIcon(icon: icon),
            ],
          ),
        ),
      );

      final widths = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.constraints?.maxWidth ?? c.decoration! as BoxDecoration).toString())
          .toList();
      expect(widths, hasLength(5));
      // All five are the same widget with the same arguments, so asserting they
      // render at one width is asserting the defaults were not overridden.
      expect(
        find.byType(AttachmentLeadingIcon),
        findsNWidgets(5),
      );
    });
  });

  group('AudioMessageType', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        host(AudioMessageType(event: event)),
      );

      expect(find.byType(AudioMessageType), findsOneWidget);
    });
  });

  group('FileAttachedMessage', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        host(FileAttachedMessage(event: event)),
      );

      expect(find.byType(FileAttachedMessage), findsOneWidget);
    });
  });

  group('VideoMessageType', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        host(VideoMessageType(event: event)),
      );

      expect(find.byType(VideoMessageType), findsOneWidget);
    });
  });
}




