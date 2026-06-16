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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/widgets/space_card.dart';

/// Helper to create a MaterialApp wrapped SpaceCard for testing.
Widget buildSpaceCard({
  String name = 'Test Space',
  String? thumbnailURL,
  String? subtitle,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SpaceCard(
        name: name,
        thumbnailURL: thumbnailURL,
        subtitle: subtitle,
        onTap: onTap,
      ),
    ),
  );
}

void main() {
  group('SpaceCard', () {
    testWidgets('renders space name', (tester) async {
      await tester.pumpWidget(buildSpaceCard(name: 'My Cool Space'));

      expect(find.text('My Cool Space'), findsOneWidget);
    });

    testWidgets('renders folder icon when no thumbnail URL provided',
        (tester) async {
      await tester.pumpWidget(buildSpaceCard());

      // The folder icon should be rendered.
      expect(find.byIcon(LucideIcons.folder), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        buildSpaceCard(subtitle: '5 rooms'),
      );

      expect(find.text('5 rooms'), findsOneWidget);
    });

    testWidgets('does not render subtitle when not provided', (tester) async {
      await tester.pumpWidget(buildSpaceCard());

      expect(find.text('5 rooms'), findsNothing);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildSpaceCard(onTap: () => tapped = true),
      );

      await tester.tap(find.byType(SpaceCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders with empty name gracefully', (tester) async {
      await tester.pumpWidget(buildSpaceCard(name: ''));

      // Should render without crashing.
      expect(find.byType(SpaceCard), findsOneWidget);
    });

    testWidgets('renders card with thumbnail URL placeholder', (tester) async {
      await tester.pumpWidget(
        buildSpaceCard(thumbnailURL: 'https://example.com/avatar.png'),
      );

      // The card should still render; the network image may fail silently.
      expect(find.byType(SpaceCard), findsOneWidget);
      // Folder icon should NOT be shown when a thumbnail URL is present
      // (CircleAvatar child is null when backgroundImage is set).
      expect(find.byIcon(LucideIcons.folder), findsNothing);
    });
  });
}
