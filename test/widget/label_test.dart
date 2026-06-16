import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/widgets/label.dart';

void main() {
  group('Label', () {
    testWidgets('shows label text above child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Label(
              label: 'Test Label',
              child: TextField(),
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('applies labelStyle to label text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Label(
              label: 'Styled Label',
              labelStyle: const TextStyle(color: Colors.red, fontSize: 20),
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Styled Label'));
      expect(text.style?.color, Colors.red);
      expect(text.style?.fontSize, 20);
    });
  });
}
