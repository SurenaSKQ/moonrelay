// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/events/user_mention.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple bounded LRU cache for HTML parse results keyed by formatted
/// body text.
///
/// Prevents re-parsing the same HTML string on every timeline rebuild.
/// Each entry holds a list of [InlineSpan]s plus a per-entry byte
/// estimate so the total memory footprint stays bounded even when a
/// single body is very large.
///
/// On insert the key is promoted to most-recent-used; on eviction the
/// oldest entries are dropped.
class HtmlParseCache {
  HtmlParseCache._();

  /// Maximum number of entries.
  static const int kMaxCacheEntries = 200;

  /// Approximate byte budget for the whole cache. InlineSpan trees can
  /// hold WidgetSpans, gesture recognizers, and text. Summing the
  /// plain-text length plus a per-span overhead is a good-enough proxy
  /// without dragging in a real measuring pass.
  static const int kMaxCacheBytes = 4 * 1024 * 1024; // 4 MB

  /// Estimated per-span overhead in bytes (recognizer, widget children,
  /// and the [InlineSpan] object header).
  static const int kPerSpanOverhead = 48;

  static final Map<String, List<InlineSpan>> _cache = {};
  static final List<String> _keys = [];
  static int _bytes = 0;

  /// Returns cached spans for [key], or `null` if not in cache. Promotes
  /// the entry to most-recent-used.
  static List<InlineSpan>? get(String key) {
    final spans = _cache[key];
    if (spans == null) return null;
    _touch(key);
    return spans;
  }

  /// Stores [spans] for [key], promoting to MRU and evicting oldest
  /// entries until the entry-count and byte caps are both satisfied.
  static void set(String key, List<InlineSpan> spans) {
    final existing = _cache[key];
    if (existing != null) {
      _bytes -= _estimateSize(existing);
      _cache[key] = spans;
      _bytes += _estimateSize(spans);
      _touch(key);
      return;
    }
    _cache[key] = spans;
    _keys.add(key);
    _bytes += _estimateSize(spans);
    _evictIfNeeded();
  }

  static void _touch(String key) {
    final idx = _keys.indexOf(key);
    if (idx < 0) return;
    if (idx == _keys.length - 1) return;
    _keys.removeAt(idx);
    _keys.add(key);
  }

  static void _evictIfNeeded() {
    while (_keys.length > kMaxCacheEntries || _bytes > kMaxCacheBytes) {
      if (_keys.isEmpty) break;
      final oldest = _keys.removeAt(0);
      final removed = _cache.remove(oldest);
      if (removed != null) {
        _bytes -= _estimateSize(removed);
      }
    }
  }

  /// Rough byte estimate for an [InlineSpan] list: sum of plain-text
  /// lengths plus a constant per-span overhead.
  static int _estimateSize(List<InlineSpan> spans) {
    var bytes = 0;
    for (final span in spans) {
      bytes += _spanSize(span);
    }
    return bytes;
  }

  static int _spanSize(InlineSpan span) {
    var bytes = kPerSpanOverhead;
    final text = span.toPlainText();
    bytes += text.length * 2; // UTF-16.
    if (span is TextSpan && span.children != null) {
      for (final child in span.children!) {
        bytes += _spanSize(child);
      }
    }
    return bytes;
  }
}

/// Opens [url] in the system default browser, but only if the scheme is
/// in the allowlist.  Rejects `javascript:`, `data:`, `file:`, and any
/// other scheme not in [_allowedSchemes].
///
/// Moved out of [FormattedTextWidget] so [HtmlTagParser] can call it
/// directly when constructing link tap handlers.
Future<void> openUrlInBrowser(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final scheme = uri.scheme.toLowerCase();
  if (!_allowedSchemes.contains(scheme)) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// URI schemes allowed for external navigation via [launchUrl].
const Set<String> _allowedSchemes = <String>{
  'https',
  'http',
  'mailto',
  'matrix',
};

/// Converts a subset of Matrix HTML into [TextSpan] lists.
///
/// Supported tags:
/// - Inline: `b`/`strong`, `i`/`em`, `u`/`ins`, `s`/`del`/`strike`, `a`,
///   `code`
/// - Block: `blockquote`, `pre`, `p`, `h1`-`h6`, `ul`, `ol`, `li`
/// - Void: `br`
/// - Entities: `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, numeric
class HtmlTagParser {
  HtmlTagParser(
    this.source,
    this.context, {
    required double baseFontSize,
    this.room,
  })  : _pos = 0,
        _depth = 0,
        _ratio = baseFontSize / 16.0;

  final String source;
  final BuildContext context;
  final Room? room;
  final double _ratio;
  int _pos;
  int _depth;

  double _fs(double defaultValue) => defaultValue * _ratio;

  static const int _maxParseDepth = 64;

  List<InlineSpan> parse() => _parseNodes(isTopLevel: true);

  List<InlineSpan> _parseNodes({bool isTopLevel = false}) {
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
    final spans = <InlineSpan>[];
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
          buffer.write('<');
          buffer.write(rawTag);
          buffer.write('>');
          continue;
        }

        if (rawTag == 'br' || rawTag == 'br/' || rawTag == 'br /') {
          buffer.write('\n');
          continue;
        }

        if (rawTag == 'img' || rawTag.startsWith('img ')) {
          final attrs = _parseAttrs(rawTag);
          final alt = attrs['alt']?.trim();
          final src = attrs['src']?.trim() ?? '';
          if (alt != null && alt.isNotEmpty) {
            buffer.write(alt);
          } else if (src.isNotEmpty) {
            buffer.write(src);
          }
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

  void _flushBuffer(StringBuffer buf, List<InlineSpan> out) {
    if (buf.isNotEmpty) {
      out.add(TextSpan(
        text: buf.toString(),
        style: TextStyle(fontSize: _fs(16)),
      ));
      buf.clear();
    }
  }

  // ---- Block content ----------------------------------------------------

  List<InlineSpan> _parseBlockContent(String tag, {int depth = 0}) {
    if (depth > _maxParseDepth) {
      _pos = source.length;
      return [
        TextSpan(
          text: '…',
          style: TextStyle(fontSize: _fs(16)),
        )
      ];
    }
    final spans = <InlineSpan>[];
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

        _pos = end;
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

  List<InlineSpan> _parseInlineContent(String tag, {int depth = 0}) {
    if (depth > _maxParseDepth) {
      _pos = source.length;
      return [
        TextSpan(
          text: '…',
          style: TextStyle(fontSize: _fs(16)),
        )
      ];
    }
    final spans = <InlineSpan>[];
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

        _pos = end;
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

  List<InlineSpan> _wrapBlock(
    String tag,
    List<InlineSpan> inner,
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
            style:muted,
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

  InlineSpan _wrapInline(
    String tag,
    List<InlineSpan> inner,
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
        final userId = isUserPermalink(href) ? userIdFromHref(href) : null;
        if (userId != null) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: UserMentionPill(
              userId: userId,
              room: room,
              fontSize: _fs(16),
            ),
          );
        }
        return TextSpan(
          children: inner,
          style: base.copyWith(
            color: accent,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => openUrlInBrowser(href),
        );
      case 'code':
        return TextSpan(
          children: inner,
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: _fs(14),
            backgroundColor: const Color(0x33FFFFFF),
          ),
        );
      default:
        return TextSpan(children: inner);
    }
  }

  // ---- Helpers ----------------------------------------------------------

  List<List<InlineSpan>> _splitItems(List<InlineSpan> spans) {
    if (spans.isEmpty) return [spans];
    final items = <List<InlineSpan>>[];
    var cur = <InlineSpan>[];
    for (final s in spans) {
      final isNewline = s is TextSpan && (s.text == '\n' || s.text == null);
      if (isNewline && cur.isNotEmpty) {
        items.add(cur);
        cur = [];
      } else if (!isNewline) {
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
          // Unquoted value - read until whitespace.
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
  /// between `<` and `>`).  e.g. `'a href="..."'` -> `'a'`.
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

// -- Plain-text linkification helpers -------------------------------------

enum PlainTokenKind { plain, url, mention }

class PlainMatch {
  PlainMatch(this.start, this.end, this.kind, this.payload);
  final int start;
  final int end;
  final PlainTokenKind kind;
  final String payload;
}

class PlainToken {
  PlainToken(this.kind, this.text, {this.payload = ''});
  final PlainTokenKind kind;
  final String text;
  final String payload;
}
