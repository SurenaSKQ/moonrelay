// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/mocks.dart';

void main() {
  late MockClient client;

  setUp(() {
    client = MockClient();
    when(() => client.accessToken).thenReturn('test_token');
  });

  group('AvatarFromUriOrFallbackImage', () {
    testWidgets('renders placeholder when avatarUri is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AvatarFromUriOrFallbackImage(
              client: client,
              avatarUri: null,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('renders with custom radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AvatarFromUriOrFallbackImage(
              client: client,
              avatarUri: null,
              radius: 30,
            ),
          ),
        ),
      );

      // CircleAvatar with radius 30
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 30);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AvatarFromUriOrFallbackImage(
              client: client,
              avatarUri: null,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CircleAvatar));
      expect(tapped, isTrue);
    });

    testWidgets('shows placeholder while thumbnail URI resolves',
        (tester) async {
      when(() => client.accessToken).thenReturn('token');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AvatarFromUriOrFallbackImage(
              client: client,
              avatarUri: Uri.parse('mxc://example.com/avatar'),
            ),
          ),
        ),
      );

      // Should still render CircleAvatar while loading
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}
