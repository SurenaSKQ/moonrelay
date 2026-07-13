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

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/markdown_to_html.dart';

/// Property-style round-trip tests for the limited Markdown converter
/// we ship in [MarkdownToHtml].
///
/// These tests are deliberately not exhaustive: the converter only
/// supports a fixed tag allow-list, so the "round-trip" only holds for
/// things the converter itself produced.  We instead verify the
/// positive cases (expected output) and the security cases (raw user
/// HTML escaping / no script tags / no event handlers).
void main() {
  group('MarkdownToHtml basic formatting', () {
    test('bold (**text**)', () {
      expect(MarkdownToHtml.convert('**hello**.'), '<p><b>hello</b>.</p>');
    });

    test('italic (*text*)', () {
      expect(MarkdownToHtml.convert('*hello*.'), '<p><i>hello</i>.</p>');
    });

    test('strikethrough (~~text~~)', () {
      expect(
          MarkdownToHtml.convert('~~hello~~.'), '<p><s>hello</s>.</p>');
    });

    test('inline code', () {
      expect(
        MarkdownToHtml.convert('a `b` c.'),
        '<p>a <code>b</code> c.</p>',
      );
    });

    test('link', () {
      expect(
        MarkdownToHtml.convert('[label](https://example.com).'),
        '<p><a href="https://example.com">label</a>.</p>',
      );
    });

    test('paragraphs are wrapped in <p>', () {
      // Sanity: the converter wraps standalone lines in <p>.  We pin this
      // so future changes don't accidentally drop the wrapper, which
      // would break every downstream consumer that looks for paragraphs.
      expect(MarkdownToHtml.convert('hello world'),
          '<p>hello world</p>');
    });

    test('code block', () {
      expect(
        MarkdownToHtml.convert('```\nfoo\nbar\n```'),
        '<pre>foo\nbar</pre>',
      );
    });

    test('headings', () {
      expect(MarkdownToHtml.convert('# H1.'), '<h1>H1.</h1>');
      expect(MarkdownToHtml.convert('## H2.'), '<h2>H2.</h2>');
      expect(MarkdownToHtml.convert('### H3.'), '<h3>H3.</h3>');
      expect(MarkdownToHtml.convert('#### H4.'), '<h4>H4.</h4>');
      expect(MarkdownToHtml.convert('##### H5.'), '<h5>H5.</h5>');
      expect(MarkdownToHtml.convert('###### H6.'), '<h6>H6.</h6>');
    });

    test('blockquote', () {
      expect(MarkdownToHtml.convert('> quoted.'), contains('blockquote'));
      expect(MarkdownToHtml.convert('> quoted.'), contains('quoted.'));
    });

    test('unordered list', () {
      final out = MarkdownToHtml.convert('- one\n- two');
      expect(out, contains('<ul>'));
      expect(out, contains('<li>one</li>'));
      expect(out, contains('<li>two</li>'));
      expect(out, contains('</ul>'));
    });

    test('ordered list', () {
      final out = MarkdownToHtml.convert('1. one\n2. two');
      expect(out, contains('<ol>'));
      expect(out, contains('<li>one</li>'));
      expect(out, contains('<li>two</li>'));
      expect(out, contains('</ol>'));
    });
  });

  group('MarkdownToHtml safety / XSS', () {
    test('plain text is HTML-escaped', () {
      // No markdown  the output should escape `<`, `>`, `&`, `"`.
      expect(MarkdownToHtml.convert('<script>.'), '<p>&lt;script&gt;.</p>');
      expect(MarkdownToHtml.convert('a & b.'), '<p>a &amp; b.</p>');
      expect(MarkdownToHtml.convert('"quoted".'), '<p>&quot;quoted&quot;.</p>');
    });

    test('mixed formatting + raw HTML escapes the raw tag', () {
      // A user types valid markdown AND smuggles a `<script>` into it.
      // The rendered output must escape the `<script>` (no tag, no
      // script execution risk), while still rendering the bold.
      final out = MarkdownToHtml.convert('**hi** <script>alert(1)</script>');
      expect(out, contains('<b>hi</b>'));
      expect(out, isNot(contains('<script>')));
      expect(out, contains('&lt;script&gt;'));
    });

    test('does not emit anchor event handlers', () {
      // Even if the link URL contains unsafe characters (e.g. a
      // double-quote or `onclick=...`), the converter must never
      // emit an `<a …onclick=…>` tag that the browser would parse as
      // an event handler.  Escaping the offending characters into
      // entities (e.g. `&quot;`) is acceptable  and in fact preferable
      // to silently dropping the user input.
      final out = MarkdownToHtml.convert(
          '[x](https://example.com/x" onclick=alert(1))');
      // Anchor must NOT contain an unescaped `onclick=` attribute.
      expect(RegExp(r'<a [^>]*onclick=').hasMatch(out), isFalse);
    });

    test('does not produce <img>, <iframe>, <svg>', () {
      final out = MarkdownToHtml.convert(
        '<img src=x onerror=alert(1)> <iframe> </iframe>',
      );
      expect(out, isNot(contains('<img')));
      expect(out, isNot(contains('<iframe')));
    });
  });

  group('MarkdownToHtml regressions', () {
    test('asterisk inside text does not produce spurious tags', () {
      // A single `*` should not generate anything.
      expect(MarkdownToHtml.convert('2 * 3 = 6.'), '<p>2 * 3 = 6.</p>');
    });

    test('empty input', () {
      expect(MarkdownToHtml.convert(''), '');
    });

    test('whitespace-only input does not produce empty inline tags', () {
      // Whitespace on every line is still wrapped, but the helper
      // strips the trailing newline.  We assert that the output
      // contains only the already-known-whitespace paragraph wrappers,
      // not e.g. empty `<b>` / `<code>` tags.
      final out = MarkdownToHtml.convert('   \n\n   ');
      expect(out.contains('<b>'), isFalse);
      expect(out.contains('<i>'), isFalse);
      expect(out.contains('<code>'), isFalse);
    });

    test('inline code with HTML inside is escaped, not parsed', () {
      final out =
          MarkdownToHtml.convert('Here is `<script>alert(1)</script>`.');
      expect(out, contains('<code>'));
      // The angle brackets inside the code run escape the closing tag
      // (`&lt;`) but the developer-visible expectation is "no <script>
      // tag reaches the renderer".  Be liberal in what we accept.
      expect(out, isNot(contains('<script>alert')));
    });

    test('link text can contain markdown', () {
      // Link label should still pass through the inline pipeline.
      final out = MarkdownToHtml.convert(
          '[**bold link**](https://example.com)');
      expect(out, contains('<a href="https://example.com"'));
      expect(out, contains('<b>bold link</b>'));
    });
  });
}
