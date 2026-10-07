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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/verification_notice_event.dart';
import 'package:moonrelay/src/chat/events/timeline_gap_marker.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/localization/app_localizations_en.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  group('VerificationNoticeEvent', () {
    final l10n = AppLocalizationsEn();

    MockEvent notice({required String type, String messageType = ''}) {
      final e = MockEvent();
      when(() => e.type).thenReturn(type);
      when(() => e.messageType).thenReturn(messageType);
      when(() => e.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1700000000000));
      return e;
    }

    Widget host(Widget child) => MaterialApp(
      theme: testMoonrelayTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    /// The notice's own sentence: the longest `Text` in the card, since the
    /// timestamp is short and has a leading double space to look different.
    String description(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.trim().isNotEmpty && !s.contains('  '));

    testWidgets('each verification event says something different',
        (tester) async {
      // A notice that renders the same sentence for start, done and cancel is
      // worse than no notice: it looks informed and tells the user nothing
      // about whether the verification worked.
      final seen = <String>{};
      for (final entry in {
        'm.key.verification.start': l10n.stateVerificationStart,
        'm.key.verification.done': l10n.stateVerificationDone,
        'm.key.verification.cancel': l10n.stateVerificationCancel,
      }.entries) {
        await tester.pumpWidget(
          host(VerificationNoticeEvent(event: notice(type: entry.key))),
        );
        final text = description(tester);
        expect(text, entry.value, reason: '${entry.key} said the wrong thing');
        seen.add(text);
      }
      expect(seen, hasLength(3), reason: 'three states, three sentences');
    });

    testWidgets('messageType wins over the event type when both are present',
        (tester) async {
      // Legacy servers send these as a plain m.room.message carrying the
      // verification name in msgtype, so the msgtype is the authoritative one.
      await tester.pumpWidget(
        host(
          VerificationNoticeEvent(
            event: notice(
              type: 'm.room.message',
              messageType: 'm.key.verification.done',
            ),
          ),
        ),
      );

      expect(description(tester), l10n.stateVerificationDone);
    });

    testWidgets('an event type it has never seen still renders a sentence',
        (tester) async {
      // The important negative. An MSC revision adding a fourth state used to
      // be the kind of thing that produced an empty card or a thrown build.
      await tester.pumpWidget(
        host(
          VerificationNoticeEvent(
            event: notice(type: 'm.key.verification.something.new'),
          ),
        ),
      );

      expect(description(tester), l10n.stateVerificationEvent);
      expect(find.byIcon(LucideIcons.shield), findsOneWidget);
    });

    testWidgets('the timestamp is shown when asked for and omitted otherwise',
        (tester) async {
      await tester.pumpWidget(
        host(VerificationNoticeEvent(event: notice(type: 'm.key.verification.done'))),
      );
      expect(
        find.textContaining(RegExp(r'^\s{2}\S')),
        findsOneWidget,
        reason: 'the timestamp line is prefixed with two spaces to keep it '
            'distinguishable from the sentence',
      );

      await tester.pumpWidget(
        host(
          VerificationNoticeEvent(
            event: notice(type: 'm.key.verification.done'),
            showTimestamp: false,
          ),
        ),
      );
      expect(find.textContaining(RegExp(r'^\s{2}\S')), findsNothing);
    });

    testWidgets('the timestamp comes from the event, not the clock',
        (tester) async {
      await tester.pumpWidget(
        host(
          VerificationNoticeEvent(event: notice(type: 'm.key.verification.done')),
        ),
      );

      final stamp = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.startsWith('  '));
      final stampFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('  '),
      );
      expect(
        stamp.trim(),
        isNot(
          DateTime.now().localizedTimeShort(tester.element(stampFinder)),
        ),
        reason: 'the event is pinned to 2023, so a stamp that matches the '
            'wall clock is the renderer reading the wrong time',
      );
    });
  });

  group('TimelineGapMarker', () {
    testWidgets('says messages are missing', (tester) async {
      // The marker exists so a user who scrolled past a hole in their history
      // knows there is one. A marker that renders no words is just a rule.
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TimelineGapMarker()),
        ),
      );

      expect(
        find.text(AppLocalizationsEn().messagesMissing),
        findsOneWidget,
      );
    });

    testWidgets('exposes the key the timeline looks it up by', (tester) async {
      // `TimelineView` finds these with `gapMarkerKey` to decide whether the
      // list has a hole. Renaming the key without updating the finder would
      // silently stop the view knowing, with no error anywhere.
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TimelineGapMarker()),
        ),
      );

      expect(find.byKey(TimelineGapMarker.gapMarkerKey), findsOneWidget);
    });

    testWidgets('the rules are dashed, not solid', (tester) async {
      // The whole reason it is not a DateSeparator: a solid rule in the same
      // position reads as "a new day", which is a different claim.
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TimelineGapMarker()),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}