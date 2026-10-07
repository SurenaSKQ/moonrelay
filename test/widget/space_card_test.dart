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
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/widgets/space_card.dart';

import '../helpers/mocks.dart';

/// Helper to create a MaterialApp wrapped SpaceCard for testing.
Widget buildSpaceCard({
  String name = 'Test Space',
  String? thumbnailURL,
  String? subtitle,
  VoidCallback? onTap,
  Client? client,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SpaceCard(
        name: name,
        thumbnailURL: thumbnailURL,
        subtitle: subtitle,
        onTap: onTap,
        client: client,
      ),
    ),
  );
}

/// A client with a token, which is the whole reason the card takes one.
Client _clientWithToken() {
  final client = MockClient();
  when(() => client.accessToken).thenReturn('test-token');
  return client;
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
        buildSpaceCard(
          thumbnailURL: 'https://example.com/avatar.png',
          client: _clientWithToken(),
        ),
      );

      // The card should still render; the network image may fail silently.
      expect(find.byType(SpaceCard), findsOneWidget);
      // Folder icon should NOT be shown when a thumbnail URL is present
      // (CircleAvatar child is null when backgroundImage is set).
      expect(find.byIcon(LucideIcons.folder), findsNothing);
    });

    testWidgets('sends the bearer token with the thumbnail', (tester) async {
      // Matrix media is authenticated, so a thumbnail fetched without the
      // token answers 401 and the card silently shows its folder icon. The
      // header is asserted through the widget's own `NetworkImage`, which is
      // the only place it is observable: `flutter_test` replaces the HTTP
      // stack the image would actually go out on.
      await tester.pumpWidget(
        buildSpaceCard(
          thumbnailURL: 'https://example.com/avatar.png',
          client: _clientWithToken(),
        ),
      );
      await tester.pump();

      final avatar =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      final image = avatar.backgroundImage;
      expect(image, isA<NetworkImage>());
      final network = image! as NetworkImage;
      expect(
        network.headers?['authorization'],
        'Bearer test-token',
        reason: 'the thumbnail would be fetched unauthenticated and 401',
      );
    });

    testWidgets('shows the folder icon when there is no client to fetch with',
        (tester) async {
      // Without a token the request cannot succeed, so the honest rendering
      // is the placeholder rather than an image that will fail.
      await tester.pumpWidget(
        buildSpaceCard(thumbnailURL: 'https://example.com/avatar.png'),
      );

      expect(find.byIcon(LucideIcons.folder), findsOneWidget);
    });
  });
}
