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

// Unit tests for `AttachmentDownloadPolicy`, the shared decision behind
// `attachmentClickThresholdMb`.
//
// The point these pin is that a size guard is only useful if it is
// combined with a way to actually get the file, and that an unknown size
// must not be treated as a large one. Before this policy existed, each
// of the five attachment renderers carried its own copy of the
// always/wifi/never switch and none of them looked at the size at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/attachment_download_policy.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

/// Builds a mock [Event] whose `content` carries the given `info` blob,
/// which is where the Matrix spec puts the attachment size.
MockEvent eventWithInfo(Object? info) {
  final content = <String, dynamic>{
    'msgtype': 'm.file',
    'body': 'file.bin',
    'url': 'mxc://example.com/file',
  };
  if (info != null) content['info'] = info;

  final event = MockEvent();
  when(() => event.type).thenReturn(EventTypes.Message);
  when(() => event.eventId).thenReturn('evt1');
  when(() => event.content).thenReturn(content);
  return event;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttachmentDownloadPolicy.sizeOf', () {
    test('reads an int size from the info blob', () {
      expect(
        AttachmentDownloadPolicy.sizeOf(
          eventWithInfo(<String, dynamic>{'size': 4096}),
        ),
        4096,
      );
    });

    test('reads a double size', () {
      expect(
        AttachmentDownloadPolicy.sizeOf(
          eventWithInfo(<String, dynamic>{'size': 4096.0}),
        ),
        4096,
      );
    });

    test('returns null when info is absent', () {
      expect(AttachmentDownloadPolicy.sizeOf(eventWithInfo(null)), isNull);
    });

    test('returns null when info is not a map', () {
      expect(AttachmentDownloadPolicy.sizeOf(eventWithInfo('nope')), isNull);
    });

    test('returns null when the size is a non-numeric string', () {
      expect(
        AttachmentDownloadPolicy.sizeOf(
          eventWithInfo(<String, dynamic>{'size': 'big'}),
        ),
        isNull,
      );
    });

    test('returns null when the size key is missing', () {
      expect(
        AttachmentDownloadPolicy.sizeOf(
          eventWithInfo(<String, dynamic>{'mimetype': 'image/png'}),
        ),
        isNull,
      );
    });
  });

  group('AttachmentDownloadPolicy without a SettingsController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('permits the download and keeps the size visible',
        (tester) async {
      late AttachmentDownloadPolicy policy;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              policy = AttachmentDownloadPolicy.of(
                context,
                event: eventWithInfo(<String, dynamic>{'size': 1024}),
                mediaPolicy: AutoDownloadPolicy.always,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(policy.shouldAutoDownload, isTrue);
      expect(policy.requiresExplicitClick, isFalse);
      expect(policy.knownSizeBytes, 1024);
    });

    testWidgets('still honours a "never" policy', (tester) async {
      late AttachmentDownloadPolicy policy;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              policy = AttachmentDownloadPolicy.of(
                context,
                event: eventWithInfo(<String, dynamic>{'size': 1024}),
                mediaPolicy: AutoDownloadPolicy.never,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(policy.shouldAutoDownload, isFalse);
      expect(policy.requiresExplicitClick, isFalse,
          reason: 'a "never" policy is not a size withholding, and must not '
              'render as a click-to-download tile');
    });
  });

  group('derived views', () {
    test('asDownloading clears the click requirement', () {
      const withheld = AttachmentDownloadPolicy(
        shouldAutoDownload: false,
        requiresExplicitClick: true,
        knownSizeBytes: 500,
      );
      final downloading = withheld.asDownloading();
      expect(downloading.shouldAutoDownload, isTrue);
      expect(downloading.requiresExplicitClick, isFalse);
      expect(downloading.knownSizeBytes, 500,
          reason: 'the size is still worth showing after the user commits');
    });

    test('ignoringSizeThreshold honours a withheld policy', () {
      const withheld = AttachmentDownloadPolicy(
        shouldAutoDownload: false,
        requiresExplicitClick: true,
        knownSizeBytes: 500,
      );
      final ignored = withheld.ignoringSizeThreshold;
      expect(ignored.shouldAutoDownload, isTrue);
      expect(ignored.requiresExplicitClick, isFalse);
    });

    test('ignoringSizeThreshold leaves an allowed policy alone', () {
      const allowed = AttachmentDownloadPolicy(
        shouldAutoDownload: true,
        requiresExplicitClick: false,
        knownSizeBytes: null,
      );
      expect(allowed.ignoringSizeThreshold.shouldAutoDownload, isTrue);
      expect(allowed.ignoringSizeThreshold.requiresExplicitClick, isFalse);
    });

    test('permissive is the documented default', () {
      expect(AttachmentDownloadPolicy.permissive.shouldAutoDownload, isTrue);
      expect(
          AttachmentDownloadPolicy.permissive.requiresExplicitClick, isFalse);
    });
  });

  group('formatSize', () {
    testWidgets('renders bytes, KB and MB', (tester) async {
      late String? small, kilo, mega;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              small = AttachmentDownloadPolicy.formatSize(context, 512);
              kilo = AttachmentDownloadPolicy.formatSize(context, 2048);
              mega = AttachmentDownloadPolicy.formatSize(context,
                  5 * 1024 * 1024);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(small, '512 B');
      expect(kilo, '2.0 KB');
      expect(mega, '5.0 MB');
    });

    testWidgets('returns null for an unknown or negative size',
        (tester) async {
      late String? unknown, negative;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              unknown = AttachmentDownloadPolicy.formatSize(context, null);
              negative = AttachmentDownloadPolicy.formatSize(context, -1);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(unknown, isNull);
      expect(negative, isNull);
    });
  });

  group('ClickToDownloadTile', () {
    testWidgets('shows the size when known and fires on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClickToDownloadTile(
              policy: const AttachmentDownloadPolicy(
                shouldAutoDownload: false,
                requiresExplicitClick: true,
                knownSizeBytes: 3 * 1024 * 1024,
              ),
              onDownload: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('Click to download'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);

      await tester.tap(find.byType(ClickToDownloadTile));
      expect(taps, 1);
    });

    testWidgets('omits the size line when it is unknown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClickToDownloadTile(
              policy: const AttachmentDownloadPolicy(
                shouldAutoDownload: false,
                requiresExplicitClick: true,
                knownSizeBytes: null,
              ),
              onDownload: () {},
            ),
          ),
        ),
      );

      expect(find.text('Click to download'), findsOneWidget);
      // A wrong or placeholder size is worse than none.
      expect(find.textContaining('B'), findsNothing);
    });
  });
}
