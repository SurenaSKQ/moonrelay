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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:matrix/matrix.dart';

/// Renders a Matrix message body with rich formatting support.
///
/// If the event has `formattedBody` with `format == "org.matrix.custom.html"`,
/// the HTML content is parsed and rendered as styled [TextSpan] children
/// inside a [SelectableText.rich].
///
/// Otherwise, the plain [body] is displayed as a [SelectableText] with manual
/// URL linkification: bare URLs are converted into clickable spans styled with
/// the accent colour and underline.
class FormattedTextWidget extends StatelessWidget {
  const FormattedTextWidget({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final formattedBody = event.content['formatted_body'] as String?;
    final format = event.content['format'] as String?;

    if (formattedBody != null && format == 'org.matrix.custom.html') {
      final spans = _HtmlTagParser(formattedBody, context).parse();
      return SelectableText.rich(TextSpan(children: spans));
    }

    // Plain text with manual URL detection.
    final spans = _linkifyPlainText(event.body, context);
    return SelectableText.rich(TextSpan(children: spans));
  }

  /// Splits [text] on URL boundaries and wraps detected links in styled,
  /// tappable [TextSpan]s.
  ///
  /// URLs that form the full text become the only span (entirely clickable).
  List<TextSpan> _linkifyPlainText(String text, BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final uriRegExp = RegExp(
      r'\b(?:https?|ftp|matrix):\/\/(?:[^\s<>")()]|\([^\s<>")()]*\))*(?!\w)'
      r'|\b(?:www\.)[^\s<>")()]+(?!\w)',
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in uriRegExp.allMatches(text)) {
      // Plain segment before the URL.
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final rawUrl = match.group(0)!;
      final url = rawUrl.startsWith('www.') ? 'https://$rawUrl' : rawUrl;

      spans.add(TextSpan(
        text: rawUrl,
        style: TextStyle(
          color: accent,
          decoration: TextDecoration.underline,
          fontSize: 16,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
      ));

      lastEnd = match.end;
    }

    // Trailing plain text.
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }

  /// Opens [url] in the system default browser via the platform shell.
  static void _openUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (Platform.isWindows) {
        Process.run('start', [url], runInShell: true);
      } else if (Platform.isMacOS) {
        Process.run('open', [url]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [url]);
      }
    } catch (_) {
      // Text is selectable – user can copy the URL manually.
    }
  }
}

// ---------------------------------------------------------------------------
// Lightweight recursive-descent HTML parser for Matrix custom HTML.
// ---------------------------------------------------------------------------

/// Converts a subset of Matrix HTML into [TextSpan] lists.
///
/// Supported tags:
/// - Inline: `b`/`strong`, `i`/`em`, `u`/`ins`, `s`/`del`/`strike`, `a`,
///   `code`
/// - Block: `blockquote`, `pre`, `p`, `h1`–`h6`, `ul`, `ol`, `li`
/// - Void: `br`
/// - Entities: `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, numeric
class _HtmlTagParser {
  _HtmlTagParser(this.source, this.context)
      : _pos = 0,
        _depth = 0;

  final String source;
  final BuildContext context;
  int _pos;
  int _depth;

  static const int _maxParseDepth = 64;

  List<TextSpan> parse() => _parseNodes(isTopLevel: true);

  List<TextSpan> _parseNodes({bool isTopLevel = false}) {
    _depth++;
    if (_depth > _maxParseDepth) {
      _depth--;
      return [
        TextSpan(
          text: source.substring(_pos),
          style: const TextStyle(fontSize: 16),
        )
      ];
    }
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    while (_pos < source.length) {
      if (source[_pos] == '<') {
        _flushBuffer(buffer, spans);

        final tagEnd = source.indexOf('>', _pos);
        if (tagEnd == -1) {
          buffer.write(source.substring(_pos));
          break;
        }

        final rawTag = source.substring(_pos + 1, tagEnd).trim();
        _pos = tagEnd + 1;

        if (rawTag.startsWith('/')) {
          _flushBuffer(buffer, spans);
          // Return so the caller can close its own span.
          _depth--;
          return spans;
        }

        if (rawTag == 'br' || rawTag == 'br/') {
          buffer.write('\n');
          continue;
        }

        final parts = rawTag.split(RegExp(r'\s+'));
        final tag = parts.first.toLowerCase();
        final attrs = _parseAttrs(parts);

        if (_isBlock(tag)) {
          final innerSpans = _parseBlockContent(tag);
          spans.addAll(_wrapBlock(tag, innerSpans, attrs));
        } else {
          final innerSpans = _parseInlineContent(tag);
          spans.add(_wrapInline(tag, innerSpans, attrs));
        }
      } else if (source[_pos] == '&') {
        buffer.write(_entity());
      } else {
        buffer.write(source[_pos]);
        _pos++;
      }
    }

    _flushBuffer(buffer, spans);
    _depth--;
    return spans;
  }

  void _flushBuffer(StringBuffer buf, List<TextSpan> out) {
    if (buf.isNotEmpty) {
      out.add(TextSpan(
        text: buf.toString(),
        style: const TextStyle(fontSize: 16),
      ));
      buf.clear();
    }
  }

  // ---- Block content ----------------------------------------------------

  List<TextSpan> _parseBlockContent(String tag, {int depth = 0}) {
    if (depth > _maxParseDepth) {
      _pos = source.length;
      return [
        const TextSpan(
          text: '…',
          style: TextStyle(fontSize: 16),
        )
      ];
    }
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    while (_pos < source.length) {
      if (source[_pos] == '<') {
        final next = source.indexOf('>', _pos);
        if (next == -1) break;

        final raw = source.substring(_pos + 1, next).trim();
        final end = next + 1;

        if (raw == '/$tag' || raw == '/${tag}s') {
          _flushBuffer(buffer, spans);
          _pos = end;
          return spans;
        }

        _flushBuffer(buffer, spans);

        if (raw.startsWith('/')) {
          _pos = end;
          return spans;
        }

        if (raw == 'br' || raw == 'br/') {
          buffer.write('\n');
          _pos = end;
          continue;
        }

        final parts = raw.split(RegExp(r'\s+'));
        final nested = parts.first.toLowerCase();
        final attrs = _parseAttrs(parts);

        if (_isBlock(nested)) {
          spans.addAll(_wrapBlock(
              nested, _parseBlockContent(nested, depth: depth + 1), attrs));
        } else {
          spans.add(_wrapInline(
              nested, _parseInlineContent(nested, depth: depth + 1), attrs));
        }
      } else if (source[_pos] == '&') {
        buffer.write(_entity());
      } else {
        buffer.write(source[_pos]);
        _pos++;
      }
    }

    _flushBuffer(buffer, spans);
    return spans;
  }

  // ---- Inline content ---------------------------------------------------

  List<TextSpan> _parseInlineContent(String tag, {int depth = 0}) {
    if (depth > _maxParseDepth) {
      _pos = source.length;
      return [
        const TextSpan(
          text: '…',
          style: TextStyle(fontSize: 16),
        )
      ];
    }
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    while (_pos < source.length) {
      if (source[_pos] == '<') {
        final next = source.indexOf('>', _pos);
        if (next == -1) break;

        final raw = source.substring(_pos + 1, next).trim();
        final end = next + 1;

        if (raw == '/$tag') {
          _flushBuffer(buffer, spans);
          _pos = end;
          return spans;
        }

        _flushBuffer(buffer, spans);

        if (raw.startsWith('/')) {
          _pos = end;
          return spans;
        }

        if (raw == 'br' || raw == 'br/') {
          buffer.write('\n');
          _pos = end;
          continue;
        }

        final parts = raw.split(RegExp(r'\s+'));
        final nested = parts.first.toLowerCase();
        final attrs = _parseAttrs(parts);

        if (_isBlock(nested)) {
          return spans;
        }

        spans.add(_wrapInline(
            nested, _parseInlineContent(nested, depth: depth + 1), attrs));
      } else if (source[_pos] == '&') {
        buffer.write(_entity());
      } else {
        buffer.write(source[_pos]);
        _pos++;
      }
    }

    _flushBuffer(buffer, spans);
    return spans;
  }

  // ---- Tag classification & wrapping -----------------------------------

  bool _isBlock(String tag) => const {
        'blockquote',
        'pre',
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'ul',
        'ol',
        'li',
      }.contains(tag);

  List<TextSpan> _wrapBlock(
    String tag,
    List<TextSpan> inner,
    Map<String, String> attrs,
  ) {
    final base = TextStyle(fontSize: 16);

    switch (tag) {
      case 'blockquote':
        return [
          const TextSpan(text: '\n'),
          TextSpan(
            children: inner,
            style: base.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          const TextSpan(text: '\n'),
        ];

      case 'pre':
        final scheme = Theme.of(context).colorScheme;
        return [
          const TextSpan(text: '\n'),
          TextSpan(
            children: [
              TextSpan(
                children: inner,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: scheme.onSurface,
                  height: 1.5,
                ),
              ),
              const TextSpan(text: ' '),
            ],
            style: TextStyle(
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const TextSpan(text: '\n'),
        ];

      case 'p':
        return [...inner, const TextSpan(text: '\n')];

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.tryParse(tag.substring(1)) ?? 1;
        const sizes = [24.0, 20.0, 18.0, 16.0, 14.0, 13.0];
        final size = sizes[level.clamp(1, 6) - 1];
        return [
          const TextSpan(text: '\n'),
          TextSpan(
            children: inner,
            style: base.copyWith(fontSize: size, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '\n'),
        ];

      case 'ul':
        final items = _splitItems(inner);
        return [
          const TextSpan(text: '\n'),
          for (final item in items)
            TextSpan(children: [
              const TextSpan(text: '  •  '),
              TextSpan(children: item),
              const TextSpan(text: '\n'),
            ]),
        ];

      case 'ol':
        final items = _splitItems(inner);
        return [
          const TextSpan(text: '\n'),
          for (int i = 0; i < items.length; i++)
            TextSpan(children: [
              TextSpan(text: '  ${i + 1}.  '),
              TextSpan(children: items[i]),
              const TextSpan(text: '\n'),
            ]),
        ];

      case 'li':
        return inner;

      default:
        return inner;
    }
  }

  TextSpan _wrapInline(
    String tag,
    List<TextSpan> inner,
    Map<String, String> attrs,
  ) {
    final accent = Theme.of(context).colorScheme.primary;
    final base = const TextStyle(fontSize: 16);

    switch (tag) {
      case 'b':
      case 'strong':
        return TextSpan(
          children: inner,
          style: base.copyWith(fontWeight: FontWeight.bold),
        );
      case 'i':
      case 'em':
        return TextSpan(
          children: inner,
          style: base.copyWith(fontStyle: FontStyle.italic),
        );
      case 'u':
      case 'ins':
        return TextSpan(
          children: inner,
          style: base.copyWith(decoration: TextDecoration.underline),
        );
      case 's':
      case 'del':
      case 'strike':
        return TextSpan(
          children: inner,
          style: base.copyWith(decoration: TextDecoration.lineThrough),
        );
      case 'a':
        final href = attrs['href'] ?? '';
        return TextSpan(
          children: inner,
          style: base.copyWith(
            color: accent,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => FormattedTextWidget._openUrl(href),
        );
      case 'code':
        return TextSpan(
          children: inner,
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            backgroundColor: Color(0x33FFFFFF),
          ),
        );
      default:
        return TextSpan(children: inner);
    }
  }

  // ---- Helpers ----------------------------------------------------------

  List<List<TextSpan>> _splitItems(List<TextSpan> spans) {
    if (spans.isEmpty) return [spans];
    final items = <List<TextSpan>>[];
    var cur = <TextSpan>[];
    for (final s in spans) {
      if (s.text == '\n' && cur.isNotEmpty) {
        items.add(cur);
        cur = [];
      } else if (s.text != '\n') {
        cur.add(s);
      }
    }
    if (cur.isNotEmpty) items.add(cur);
    return items.isEmpty ? [spans] : items;
  }

  Map<String, String> _parseAttrs(List<String> parts) {
    final map = <String, String>{};
    for (int i = 1; i < parts.length; i++) {
      final eq = parts[i].indexOf('=');
      if (eq == -1) continue;
      final k = parts[i].substring(0, eq).toLowerCase();
      var v = parts[i].substring(eq + 1);
      if ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'"))) {
        v = v.substring(1, v.length - 1);
      }
      map[k] = v;
    }
    return map;
  }

  String _entity() {
    final start = _pos;
    if (source[_pos] == '&') {
      final end = source.indexOf(';', _pos);
      if (end != -1 && end - _pos < 12) {
        final name = source.substring(_pos + 1, end);
        _pos = end + 1;
        switch (name) {
          case 'amp':
            return '&';
          case 'lt':
            return '<';
          case 'gt':
            return '>';
          case 'quot':
            return '"';
          case 'apos':
            return "'";
          case 'nbsp':
            return '\u00a0';
          default:
            if (name.startsWith('#')) {
              final code = name.substring(1);
              final cp = code.startsWith('x')
                  ? int.tryParse(code.substring(1), radix: 16)
                  : int.tryParse(code);
              if (cp != null) return String.fromCharCode(cp);
            }
            return source.substring(start, _pos);
        }
      }
    }
    _pos++;
    return '&';
  }
}
