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

// Widget tests for `RoomEncryptionBadge`.
//
// Exercises the contract:
// - Renders nothing when the room is null.
// - Renders the shield icon when the room claims encryption.
// - Survives room lookups that throw (e.g. disposed Client).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/encryption_badge.dart';

import '../helpers/mocks.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('RoomEncryptionBadge', () {
    testWidgets('renders nothing when room is null', (tester) async {
      await tester.pumpWidget(_wrap(const RoomEncryptionBadge(room: null)));
      expect(find.byType(RoomEncryptionBadge), findsOneWidget);
      expect(find.byIcon(LucideIcons.shieldCheck), findsNothing);
    });

    testWidgets('renders the shield when room is encrypted', (tester) async {
      final mock = MockRoom();
      when(() => mock.encrypted).thenReturn(true);

      await tester.pumpWidget(_wrap(RoomEncryptionBadge(room: mock)));
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
    });

    testWidgets('survives SDK lookups that throw', (tester) async {
      final mock = MockRoom();
      when(() => mock.encrypted).thenThrow(Exception('boom'));

      await tester.pumpWidget(_wrap(RoomEncryptionBadge(room: mock)));
      expect(find.byIcon(LucideIcons.shieldCheck), findsNothing);
    });
  });
}