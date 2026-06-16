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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/layouts/empty_space.dart';
import 'package:moonrelay/src/widgets/logo_with_text_themed.dart';

void main() {
  group('EmptySpace', () {
    testWidgets('renders LogoWithTextThemed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmptySpace(),
        ),
      );

      expect(find.byType(LogoWithTextThemed), findsOneWidget);
    });

    testWidgets('renders Scaffold with brand content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmptySpace(),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Moonrelay (Alpha)'), findsOneWidget);
    });
  });
}
