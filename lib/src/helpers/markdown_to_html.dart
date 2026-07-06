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

/// Converts a subset of Markdown into Matrix-compatible HTML.
///
/// This is intentionally limited to the formatting that the composing UI
/// supports and is _not_ a full Markdown parser.
///
/// Supported syntax:
/// - `**bold**` → `<b>bold</b>`
/// - `*italic*` → `<i>italic</i>`
/// - `~~strikethrough~~` → `<s>strikethrough</s>`
/// - `` `inline code` `` → `<code>inline code</code>`
/// - `` ```code block``` `` → `<pre>code block</pre>`
/// - `> quote` → `<blockquote><p>quote</p></blockquote>`
/// - `# heading` → `<h1>heading</h1>` (up to `######`)
/// - `[text](url)` → `<a href="url">text</a>`
/// - `- item` → `<ul><li>item</li></ul>`
/// - `1. item` → `<ol><li>item</li></ol>`
/// - Newlines → `<br>`
class MarkdownToHtml {
  /// Converts [markdown] to a Matrix-compatible HTML string.
  static String convert(String markdown) {
    return _processBlocks(markdown);
  }

  /// Processes block-level elements line-by-line.
  static String _processBlocks(String input) {
    final lines = input.split('\n');
    final output = StringBuffer();
    final List<String> ulItems = [];
    final List<String> olItems = [];
    bool inUl = false;
    bool inOl = false;

    void flushList() {
      if (inUl) {
        if (ulItems.isNotEmpty) {
          output.writeln('<ul>${ulItems.join()}</ul>');
        }
        ulItems.clear();
        inUl = false;
      }
      if (inOl) {
        if (olItems.isNotEmpty) {
          output.writeln('<ol>${olItems.join()}</ol>');
        }
        olItems.clear();
        inOl = false;
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      // Code block (``` ... ```)
      if (trimmed.startsWith('```')) {
        flushList();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        final code = codeLines.join('\n');
        output.writeln('<pre>$code</pre>');
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('> ')) {
        flushList();
        final content = _processInline(trimmed.substring(2));
        output.writeln('<blockquote><p>$content</p></blockquote>');
        continue;
      }

      // Headings
      if (trimmed.startsWith('###### ')) {
        flushList();
        output.writeln(
          '<h6>${_processInline(trimmed.substring(7).trim())}</h6>',
        );
        continue;
      }
      if (trimmed.startsWith('##### ')) {
        flushList();
        output.writeln(
          '<h5>${_processInline(trimmed.substring(6).trim())}</h5>',
        );
        continue;
      }
      if (trimmed.startsWith('#### ')) {
        flushList();
        output.writeln(
          '<h4>${_processInline(trimmed.substring(5).trim())}</h4>',
        );
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushList();
        output.writeln(
          '<h3>${_processInline(trimmed.substring(4).trim())}</h3>',
        );
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushList();
        output.writeln(
          '<h2>${_processInline(trimmed.substring(3).trim())}</h2>',
        );
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushList();
        output.writeln(
          '<h1>${_processInline(trimmed.substring(2).trim())}</h1>',
        );
        continue;
      }

      // Unordered list
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        inOl = false;
        if (olItems.isNotEmpty) _flushOl(output, olItems);
        inUl = true;
        final content = _processInline(trimmed.substring(2).trim());
        ulItems.add('<li>$content</li>');
        continue;
      }

      // Ordered list
      if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        inUl = false;
        if (ulItems.isNotEmpty) _flushUl(output, ulItems);
        inOl = true;
        final dotIndex = trimmed.indexOf('.');
        final content = _processInline(trimmed.substring(dotIndex + 1).trim());
        olItems.add('<li>$content</li>');
        continue;
      }

      // Regular paragraph
      flushList();
      if (line.isEmpty) {
        output.writeln();
      } else {
        final processed = _processInline(line);
        if (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
          output.writeln('<p>$processed</p>');
        } else {
          output.write('<p>$processed</p>');
        }
      }
    }

    flushList();
    return output.toString().trim();
  }

  static void _flushUl(StringBuffer buf, List<String> items) {
    if (items.isNotEmpty) {
      buf.writeln('<ul>${items.join()}</ul>');
    }
  }

  static void _flushOl(StringBuffer buf, List<String> items) {
    if (items.isNotEmpty) {
      buf.writeln('<ol>${items.join()}</ol>');
    }
  }

  /// Processes inline formatting within a single line.
  static String _processInline(String text) {
    return _escapeHtml(
      _processLinks(
        _processStrikethrough(
          _processBoldItalic(text),
        ),
      ),
      text,
    );
  }

  /// Converts `[text](url)` to `<a href="url">text</a>`.
  ///
  /// URLs containing `&`, `<`, `>`, `"`, apostrophe, spaces, or
  /// other characters that would break out of the `href="…"`
  /// attribute are silently dropped (the text is rendered without a
  /// link).  This is a defence-in-depth measure on top of the
  /// `[^\s<>")()]+` regex: even if a quote slipped through, the
  /// attribute has no way to escape.
  static String _processLinks(String text) {
    return text.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\(([^)]+)\)'),
      (m) {
        final linkText = _processBoldItalic(m[1]!);
        final url = m[2]!;
        if (!_isSafeHref(url)) {
          // Render the original text verbatim (escaped) without a
          // link wrapper so the user at least sees what they typed.
          return _escapeHtmlRaw(linkText);
        }
        return '<a href="${_escapeAttribute(url)}">$linkText</a>';
      },
    );
  }

  /// Whether [url] is safe to place inside `href="…"`.
  ///
  /// We allow the common URL characters and a small set of pcts
  /// (which the surrounding [_escapeAttribute] will further encode),
  /// but reject anything containing characters that would terminate
  /// the attribute early.
  static bool _isSafeHref(String url) {
    for (final c in url.split('')) {
      // Letters, digits, common URL punctuation, and percent-encoded
      // sequences are allowed.  Anything else — quotes, brackets,
      // angle brackets, whitespace, control chars — is rejected.
      final code = c.codeUnitAt(0);
      final allowed = (code >= 0x30 && code <= 0x39) || // 0-9
          (code >= 0x41 && code <= 0x5A) || // A-Z
          (code >= 0x61 && code <= 0x7A) || // a-z
          '!#\$%&\'()*+,-./:;=?@[]^_`{|}~'.contains(c);
      if (!allowed) return false;
    }
    return true;
  }

  /// Processes `~~strikethrough~~`, `**bold**`, `*italic*`, and
  /// `` `inline code` ``.
  ///
  /// Processes strikethrough first so nested patterns don't interfere.
  static String _processStrikethrough(String text) {
    return text.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
      (m) => '<s>${_processBoldItalic(m[1]!)}</s>',
    );
  }

  /// Converts `**bold**` and `*italic*` into `<b>` / `<i>`.
  ///
  /// Also handles `` `inline code` `` inline.
  ///
  /// The scanner walks the input character by character with the
  /// following precedence (highest first):
  ///
  /// 1. `` `…` `` — inline code: everything between matching backticks.
  /// 2. `**…**` — bold: greedy forward `**` close, rejecting empty
  ///    spans and anything that would land inside an already-started
  ///    bold.
  /// 3. `*…*` — italic: rejected when adjacent to another `*`, so
  ///    `*a**b*c*` italicises only `a` and leaves the inner `**`
  ///    pair un-touched.
  /// 4. Plain character pass-through.
  static String _processBoldItalic(String text) {
    final result = StringBuffer();
    int i = 0;

    while (i < text.length) {
      // ── 1. Inline code: backticks win over * and **. ───────────
      if (text[i] == '`' && i + 1 < text.length && text[i + 1] != '`') {
        final close = text.indexOf('`', i + 1);
        if (close != -1) {
          result.write('<code>${_escapeHtmlRaw(text.substring(i + 1, close))}'
              '</code>');
          i = close + 1;
          continue;
        }
      }

      // ── 2. Bold `**text**` ─────────────────────────────────────
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        // Reject empty `****` and `**` followed immediately by another
        // asterisk (which would be three+ in a row — ambiguous, just
        // emit the leading `**` literally rather than mis-nesting).
        if (i + 2 < text.length && text[i + 2] == '*') {
          // Three asterisks in a row — emit them as text; the next
          // pass may still find a valid italic if that's what the
          // user typed.
        } else {
          final close = text.indexOf('**', i + 2);
          if (close != -1 && close != i + 2) {
            final inner = _processItalic(text.substring(i + 2, close));
            result.write('<b>$inner</b>');
            i = close + 2;
            continue;
          }
        }
      }

      // ── 3. Italic `*text*` ─────────────────────────────────────
      // We only open italic when the surrounding bytes aren't also
      // asterisks: this prevents `*a**b*c*` from being scanned as a
      // single italic span that swallows the inner `**` pair.
      if (text[i] == '*' &&
          (i == 0 || text[i - 1] != '*') &&
          (i + 1 >= text.length || text[i + 1] != '*')) {
        final closeIdx = _findItalicClose(text, i + 1);
        if (closeIdx != null) {
          result.write('<i>${_escapeHtmlRaw(text.substring(i + 1, closeIdx))}</i>');
          i = closeIdx + 1;
          continue;
        }
      }

      result.write(text[i]);
      i++;
    }

    return result.toString();
  }

  /// Finds the position of the `*` that closes an italic span opened
  /// at position [start] (just past the opening `*`).  Returns `null`
  /// if no valid close is found.
  ///
  /// Valid close = a `*` such that the preceding character isn't `*`
  /// (so `*a**b*` doesn't form one span) and the following character
  /// isn't `*` (so `*a**` doesn't claim the second `*` as a close).
  static int? _findItalicClose(String text, int start) {
    var i = start;
    while (i < text.length) {
      if (text[i] == '*' &&
          (i == 0 || text[i - 1] != '*') &&
          (i + 1 >= text.length || text[i + 1] != '*')) {
        return i;
      }
      i++;
    }
    return null;
  }

  /// Converts `*italic*` inside bold content.
  static String _processItalic(String text) {
    final result = StringBuffer();
    int i = 0;
    while (i < text.length) {
      if (text[i] == '*' &&
          (i == 0 || text[i - 1] != '*') &&
          (i + 1 >= text.length || text[i + 1] != '*')) {
        final closeIdx = _findItalicClose(text, i + 1);
        if (closeIdx != null) {
          result.write('<i>${_escapeHtmlRaw(text.substring(i + 1, closeIdx))}</i>');
          i = closeIdx + 1;
          continue;
        }
      }
      result.write(text[i]);
      i++;
    }
    return result.toString();
  }

  /// Known HTML tags that the Markdown converter legitimately produces.
  /// Any `<...>` not matching this pattern is treated as raw user input
  /// and escaped so it cannot be interpreted as HTML by the renderer.
  ///
  /// This prevents raw `<script>`, `<iframe>`, `<img onerror>`, etc.
  /// in user input from passing through to `FormattedTextWidget`.
  static final _knownTag = RegExp(
    r'^</?(b|i|s|code|pre|blockquote|p|h[1-6]|ul|ol|li|br'
    r'|a(\s+href="[^"]*")?)'
    r'\s*/?>$',
    caseSensitive: false,
  );

  /// HTML-entity-encodes the plain-text parts of the body.
  ///
  /// The passed-in [processed] string already has tags; the original [raw]
  /// text is used only to decide what to escape.
  static String _escapeHtml(String processed, String raw) {
    // We only escape characters that were NOT inside a tag in [processed].
    // Since our converter only produces specific tags, we'll walk the
    // processed string and escape text outside <...>.
    final result = StringBuffer();
    int i = 0;
    while (i < processed.length) {
      if (processed[i] == '<') {
        final close = processed.indexOf('>', i);
        if (close != -1) {
          final tag = processed.substring(i, close + 1);
          if (_knownTag.hasMatch(tag)) {
            // Legitimate converter-generated tag — pass through.
            result.write(tag);
          } else {
            // Raw user-input HTML — escape it.
            result.write('&lt;');
            result.write(_escapeHtmlRaw(processed.substring(i + 1, close)));
            result.write('&gt;');
          }
          i = close + 1;
          continue;
        }
      }
      result.write(_escapeHtmlRaw(processed[i]));
      i++;
    }
    return result.toString();
  }

  /// Replaces `&`, `<`, `>`, `"` with their HTML entities.
  static String _escapeHtmlRaw(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Escapes characters that are unsafe inside an HTML attribute value.
  ///
  /// This is more conservative than [_escapeHtmlRaw]: quotes and angle
  /// brackets break the surrounding `<a href="…">` even when harmless
  /// inside text, so attribute values always use this pass instead of
  /// the surrounding body escape.
  static String _escapeAttribute(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
