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
import 'package:moonrelay/src/chat/events/formatted_text_widget.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

/// Finder that matches a [SelectableText] whose plain text [contains] [text].
Finder _findSelectableTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SelectableText &&
        (widget.textSpan?.toPlainText().contains(text) ?? false),
  );
}

void main() {
  group('FormattedTextWidget HTML parsing', () {
    late MockEvent event;

    setUp(() {
      event = MockEvent();
      when(() => event.type).thenReturn(EventTypes.Message);
      when(() => event.messageType).thenReturn(MessageTypes.Text);
    });

    group('formatted_body rendering', () {
      testWidgets('renders bold text with <b> tag', (tester) async {
        when(() => event.body).thenReturn('Hello **bold** world');
        when(() => event.content).thenReturn({
          'body': 'Hello **bold** world',
          'formatted_body': 'Hello <b>bold</b> world',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('bold'), findsOneWidget);
      });

      testWidgets('renders italic text with <i> tag', (tester) async {
        when(() => event.body).thenReturn('Hello italic world');
        when(() => event.content).thenReturn({
          'body': 'Hello italic world',
          'formatted_body': 'Hello <i>italic</i> world',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('italic'), findsOneWidget);
      });

      testWidgets('renders strikethrough with <s> tag', (tester) async {
        when(() => event.body).thenReturn('strike');
        when(() => event.content).thenReturn({
          'body': 'strike',
          'formatted_body': '<s>strike</s>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('strike'), findsOneWidget);
      });

      testWidgets('renders underlined text with <u> tag', (tester) async {
        when(() => event.body).thenReturn('underline');
        when(() => event.content).thenReturn({
          'body': 'underline',
          'formatted_body': '<u>underline</u>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('underline'), findsOneWidget);
      });

      testWidgets('renders inline code with <code> tag', (tester) async {
        when(() => event.body).thenReturn('code block');
        when(() => event.content).thenReturn({
          'body': 'code block',
          'formatted_body': 'Here is <code>inline code</code> text',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('inline code'), findsOneWidget);
      });

      testWidgets('renders blockquote', (tester) async {
        when(() => event.body).thenReturn('quote');
        when(() => event.content).thenReturn({
          'body': 'quote',
          'formatted_body': '<blockquote>This is a quote</blockquote>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(
          _findSelectableTextContaining('This is a quote'),
          findsOneWidget,
        );
      });

      testWidgets('renders headers h1-h6', (tester) async {
        when(() => event.body).thenReturn('heading');
        when(() => event.content).thenReturn({
          'body': 'heading',
          'formatted_body': '<h1>Title</h1><h2>Subtitle</h2>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('Title'), findsOneWidget);
        expect(_findSelectableTextContaining('Subtitle'), findsOneWidget);
      });

      testWidgets('renders unordered list without error', (tester) async {
        when(() => event.body).thenReturn('list');
        when(() => event.content).thenReturn({
          'body': 'list',
          'formatted_body': '<ul><li>Item 1</li><li>Item 2</li></ul>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        // Should render without errors
        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('renders ordered list without error', (tester) async {
        when(() => event.body).thenReturn('olist');
        when(() => event.content).thenReturn({
          'body': 'olist',
          'formatted_body': '<ol><li>First</li><li>Second</li></ol>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('renders <br> as newline', (tester) async {
        when(() => event.body).thenReturn('line1\nline2');
        when(() => event.content).thenReturn({
          'body': 'line1\nline2',
          'formatted_body': 'line1<br>line2',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('line1'), findsOneWidget);
        expect(_findSelectableTextContaining('line2'), findsOneWidget);
      });

      testWidgets('renders preformatted text', (tester) async {
        when(() => event.body).thenReturn('code');
        when(() => event.content).thenReturn({
          'body': 'code',
          'formatted_body': '<pre>const x = 1;</pre>',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('const x = 1;'), findsOneWidget);
      });

      testWidgets('falls back to plain body when no HTML', (tester) async {
        when(() => event.body).thenReturn('Just plain text');
        when(() => event.content).thenReturn({
          'body': 'Just plain text',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(
            _findSelectableTextContaining('Just plain text'), findsOneWidget);
      });

      testWidgets('ignores format without formatted_body', (tester) async {
        when(() => event.body).thenReturn('Plain body only');
        when(() => event.content).thenReturn({
          'body': 'Plain body only',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(
            _findSelectableTextContaining('Plain body only'), findsOneWidget);
      });

      testWidgets('renders HTML entities', (tester) async {
        when(() => event.body).thenReturn('entities');
        when(() => event.content).thenReturn({
          'body': 'entities',
          'formatted_body': '&amp; &lt; &gt; &quot; &apos;',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        final selectableText =
            tester.widget<SelectableText>(find.byType(SelectableText));
        final plainText = selectableText.textSpan?.toPlainText() ?? '';
        expect(plainText.contains('&'), isTrue);
        expect(plainText.contains('<'), isTrue);
        expect(plainText.contains('>'), isTrue);
      });

      testWidgets('renders link in formatted text', (tester) async {
        when(() => event.body).thenReturn('link');
        when(() => event.content).thenReturn({
          'body': 'link',
          'formatted_body':
              'Visit <a href="https://example.com">Example</a> today',
          'format': 'org.matrix.custom.html',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('Example'), findsOneWidget);
      });

      testWidgets('handles empty body gracefully', (tester) async {
        when(() => event.body).thenReturn('');
        when(() => event.content).thenReturn({
          'body': '',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(find.byType(SelectableText), findsOneWidget);
      });
    });

    group('URL linkification in plain text', () {
      testWidgets('detects https URLs in plain text', (tester) async {
        when(() => event.body).thenReturn('Check out https://example.com/page');
        when(() => event.content).thenReturn({
          'body': 'Check out https://example.com/page',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('example.com'), findsOneWidget);
      });

      testWidgets('matrix URLs appear in rendered text', (tester) async {
        when(() => event.body).thenReturn('Join matrix:roomid');
        when(() => event.content).thenReturn({
          'body': 'Join matrix:roomid',
          'msgtype': 'm.text',
        });

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FormattedTextWidget(event: event))),
        );

        expect(_findSelectableTextContaining('matrix:roomid'), findsOneWidget);
      });
    });
  });
}
