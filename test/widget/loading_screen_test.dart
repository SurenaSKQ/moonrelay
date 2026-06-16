import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';

void main() {
  group('LoadingScreen', () {
    testWidgets('displays a CircularProgressIndicator centered',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoadingScreen()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });
  });
}
