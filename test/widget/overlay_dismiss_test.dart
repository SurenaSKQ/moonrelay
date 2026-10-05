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

// The palette end to end, through the real overlay rather than a harness
// built to make it pass.
//
// The previous version of this file wrapped the whole interaction in a
// `try { ... } catch (_) {}` on the grounds that the mock client "will produce
// async-failure noise from the search provider". Which is exactly what happened:
// the palette stopped building because it needed a `Logger`, the throw was
// eaten, and the test passed while asserting nothing at all. It is worth
// remembering that a swallow-everything catch around a widget test converts
// every regression into a green tick.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/command_palette/command_palette.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  testWidgets('the palette opens over the app and an outside tap closes it',
      (tester) async {
    final MockClient client = MockClient();
    when(() => client.userID).thenReturn('@me:example.org');
    when(() => client.rooms).thenReturn(<Room>[]);

    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCommandPalette(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byType(CommandPalettePage),
      findsOneWidget,
      reason: 'the palette must actually be on screen before dismissal means '
          'anything',
    );

    // Top-left corner, well outside the centred card.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(CommandPalettePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes it without a tap', (tester) async {
    final MockClient client = MockClient();
    when(() => client.userID).thenReturn('@me:example.org');
    when(() => client.rooms).thenReturn(<Room>[]);

    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCommandPalette(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CommandPalettePage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // The old palette had no Escape handler at all. It was dismissed by tapping
    // outside, which means a keyboard user had to reach for the mouse to close
    // the thing they opened with the keyboard.
    expect(find.byType(CommandPalettePage), findsNothing);
  });
}
