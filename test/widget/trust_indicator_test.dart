// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/widgets/encryption/trust_indicator.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

void main() {
  group('TrustIndicator', () {
    testWidgets('shows verified icon when verified is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrustIndicator(isVerified: true),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
    });

    testWidgets('shows warning icon when verified is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrustIndicator(isVerified: false),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.shieldOff), findsOneWidget);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrustIndicator(isVerified: true, size: 24),
          ),
        ),
      );

      expect(find.byType(TrustIndicator), findsOneWidget);
    });
  });
}
