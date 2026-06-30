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
import 'package:flutter/gestures.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const FormattedTextWidget({
    super.key,
    required this.event,
    this.formattedBodyOverride,
    this.baseFontSize = 16.0,
  });

  final Event event;

  /// Optional override for `formatted_body`. When set, this HTML is used
  /// instead of `event.content['formatted_body']`, bypassing the event's
  /// own formatted body entirely.
  final String? formattedBodyOverride;

  /// The base font size for message body text (default 16.0).
  /// All internal font sizes are scaled relative to this value.
  final double baseFontSize;

  double _fs(double defaultValue) => defaultValue * (baseFontSize / 16.0);

  @override
  Widget build(BuildContext context) {
    final formattedBody =
        formattedBodyOverride ?? event.content['formatted_body'] as String?;
    final format = event.content['format'] as String?;

    if (formattedBody != null && format == 'org.matrix.custom.html') {
      // Check the parse cache before re-parsing.
      final cacheKey = formattedBody.hashCode ^ baseFontSize.hashCode;
      List<TextSpan>? spans = _HtmlParseCache.get(cacheKey);
      if (spans == null) {
        spans =
            _HtmlTagParser(formattedBody, context, baseFontSize: baseFontSize)
                .parse();
        _HtmlParseCache.set(cacheKey, spans);
      }
      if (spans.isNotEmpty) {
        return SelectableText.rich(TextSpan(
          style: TextStyle(fontSize: _fs(16)),
          children: spans,
        ));
      }
      // Parser produced nothing – fall through to plain-text rendering.
    }

    // Plain text with manual URL detection.
    final spans = _linkifyPlainText(event.body, context);
    return SelectableText.rich(TextSpan(
      style: TextStyle(fontSize: _fs(16)),
      children: spans,
    ));
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
          fontSize: _fs(16),
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

  /// URI schemes allowed for external navigation via [launchUrl].
  static const _allowedSchemes = <String>{
    'https',
    'http',
    'mailto',
    'matrix',
  };

  /// Opens [url] in the system default browser, but only if the scheme is
  /// in the allowlist.  Rejects `javascript:`, `data:`, `file:`, and any
  /// other scheme not in [_allowedSchemes].
  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (!_allowedSchemes.contains(scheme)) {
      // Silently reject dangerous URI schemes.
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// Lightweight recursive-descent HTML parser for Matrix custom HTML.
// ---------------------------------------------------------------------------

/// Simple bounded cache for HTML parse results keyed by formatted body text.
///
/// Prevents re-parsing the same HTML string on every timeline rebuild.
/// Only the most recent [kMaxCacheEntries] entries are kept.
class _HtmlParseCache {
  _HtmlParseCache._();
  static const int kMaxCacheEntries = 200;
  static final Map<int, List<TextSpan>> _cache = {};
  static final List<int> _keys = [];

  /// Returns cached spans for [key], or `null` if not in cache.
  static List<TextSpan>? get(int key) => _cache[key];

  /// Stores [spans] for [key], evicting the oldest entry if over capacity.
  static void set(int key, List<TextSpan> spans) {
    if (_cache.containsKey(key)) return;
    if (_keys.length >= kMaxCacheEntries) {
      final oldest = _keys.removeAt(0);
      _cache.remove(oldest);
    }
    _keys.add(key);
    _cache[key] = spans;
  }
}

/// Converts a subset of Matrix HTML into [TextSpan] lists.
///
/// Supported tags:
/// - Inline: `b`/`strong`, `i`/`em`, `u`/`ins`, `s`/`del`/`strike`, `a`,
///   `code`
/// - Block: `blockquote`, `pre`, `p`, `h1`–`h6`, `ul`, `ol`, `li`
/// - Void: `br`
/// - Entities: `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, numeric
class _HtmlTagParser {
  _HtmlTagParser(this.source, this.context, {required double baseFontSize})
      : _pos = 0,
        _depth = 0,
        _ratio = baseFontSize / 16.0;

  final String source;
  final BuildContext context;
  final double _ratio;
  int _pos;
  int _depth;

  double _fs(double defaultValue) => defaultValue * _ratio;

  static const int _maxParseDepth = 64;

  List<TextSpan> parse() => _parseNodes(isTopLevel: true);

  List<TextSpan> _parseNodes({bool isTopLevel = false}) {
    _depth++;
    if (_depth > _maxParseDepth) {
      _depth--;
      return [
        TextSpan(
          text: source.substring(_pos),
          style: TextStyle(fontSize: _fs(16)),
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
          // Unexpected closing tag at top level – treat as literal
          // text so we don't silently drop all remaining content.
          buffer.write('<');
          buffer.write(rawTag);
          buffer.write('>');
          continue;
        }

        if (rawTag == 'br' || rawTag == 'br/' || rawTag == 'br /') {
          buffer.write('\n');
          continue;
        }

        final tag = _tagName(rawTag);
        final attrs = _parseAttrs(rawTag);

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
        style: TextStyle(fontSize: _fs(16)),
      ));
      buf.clear();
    }
  }

  // ---- Block content ----------------------------------------------------

  List<TextSpan> _parseBlockContent(String tag, {int depth = 0}) {
    if (depth > _maxParseDepth) {
      _pos = source.length;
      return [
        TextSpan(
          text: '…',
          style: TextStyle(fontSize: _fs(16)),
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
          // Unexpected closing tag – treat as literal text rather
          // than aborting and dropping the rest of the message.
          buffer.write('<');
          buffer.write(raw);
          buffer.write('>');
          _pos = end;
          continue;
        }

        if (raw == 'br' || raw == 'br/' || raw == 'br /') {
          buffer.write('\n');
          _pos = end;
          continue;
        }

        final nested = _tagName(raw);
        final attrs = _parseAttrs(raw);

        _pos = end; // advance past the opening tag before recursing
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
        TextSpan(
          text: '…',
          style: TextStyle(fontSize: _fs(16)),
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
          // Unexpected closing tag – treat as literal text rather
          // than aborting and dropping the rest of the message.
          buffer.write('<');
          buffer.write(raw);
          buffer.write('>');
          _pos = end;
          continue;
        }

        if (raw == 'br' || raw == 'br/' || raw == 'br /') {
          buffer.write('\n');
          _pos = end;
          continue;
        }

        final nested = _tagName(raw);
        final attrs = _parseAttrs(raw);

        if (_isBlock(nested)) {
          return spans;
        }

        _pos = end; // advance past the opening tag before recursing
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
        'mx-reply',
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
    final base = TextStyle(fontSize: _fs(16));

    switch (tag) {
      case 'blockquote':
        final scheme = Theme.of(context).colorScheme;
        final muted = base.copyWith(
          fontStyle: FontStyle.italic,
          color: scheme.onSurface.withValues(alpha: 0.75),
          fontSize: _fs(15),
        );
        return [
          const TextSpan(text: '\n'),
          TextSpan(
            children: inner,
            style: muted,
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
                  fontSize: _fs(13),
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

      case 'mx-reply':
        final scheme = Theme.of(context).colorScheme;
        final muted = base.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.65),
          fontSize: _fs(14),
        );
        return [
          const TextSpan(text: '\n'),
          TextSpan(
            children: [
              TextSpan(
                text: '│ ',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: _fs(14),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              TextSpan(children: inner, style: muted),
            ],
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
            style:
                base.copyWith(fontSize: _fs(size), fontWeight: FontWeight.bold),
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
    final base = TextStyle(fontSize: _fs(16));

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
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: _fs(14),
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

  /// Parses HTML attributes from the portion of [raw] that follows the
  /// tag name.  Respects single- and double-quoted values that may
  /// themselves contain whitespace.
  ///
  /// [raw] is the full content between `<` and `>` (e.g.
  /// `a href="url" title="hello world"`).
  Map<String, String> _parseAttrs(String raw) {
    final map = <String, String>{};
    int i = 0;

    // Skip leading tag name and any whitespace that follows it.
    while (i < raw.length && raw[i] != ' ') {
      i++;
    }

    while (i < raw.length) {
      // Skip whitespace between attributes.
      while (i < raw.length && raw[i] == ' ') {
        i++;
      }
      if (i >= raw.length) break;

      // Read the attribute name up to '=' or end-of-attribute.
      final nameStart = i;
      while (i < raw.length && raw[i] != '=' && raw[i] != ' ') {
        i++;
      }
      final name = raw.substring(nameStart, i).toLowerCase();

      if (i < raw.length && raw[i] == '=') {
        i++; // skip '='

        // Read quoted or unquoted value.
        if (i < raw.length && (raw[i] == '"' || raw[i] == "'")) {
          final quote = raw[i];
          i++; // skip opening quote
          final valueStart = i;
          while (i < raw.length && raw[i] != quote) {
            i++;
          }
          map[name] = raw.substring(valueStart, i);
          if (i < raw.length) i++; // skip closing quote
        } else {
          // Unquoted value – read until whitespace.
          final valueStart = i;
          while (i < raw.length && raw[i] != ' ') {
            i++;
          }
          map[name] = raw.substring(valueStart, i);
        }
      } else {
        // Boolean attribute (no value).
        map[name] = '';
      }
    }

    return map;
  }

  /// Extracts the tag name from a raw HTML tag string (the content
  /// between `<` and `>`).  e.g. `'a href="..."'` → `'a'`.
  String _tagName(String raw) {
    final space = raw.indexOf(' ');
    return (space == -1 ? raw : raw.substring(0, space)).toLowerCase();
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
