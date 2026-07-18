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
import 'package:moonrelay/src/chat/events/user_mention.dart';
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
    this.room,
  });

  final Event event;

  /// Optional override for `formatted_body`. When set, this HTML is used
  /// instead of `event.content['formatted_body']`, bypassing the event's
  /// own formatted body entirely.
  final String? formattedBodyOverride;

  /// The base font size for message body text (default 16.0).
  /// All internal font sizes are scaled relative to this value.
  final double baseFontSize;

  /// Optional surrounding room.  When provided, inline user-mention
  /// pills are rendered with room context so the hover preview and
  /// profile overlay can offer room-scoped moderation actions.
  final Room? room;

  double _fs(double defaultValue) => defaultValue * (baseFontSize / 16.0);

  @override
  Widget build(BuildContext context) {
    final formattedBody =
        formattedBodyOverride ?? event.content['formatted_body'] as String?;
    final format = event.content['format'] as String?;

    if (formattedBody != null && format == 'org.matrix.custom.html') {
      // Check the parse cache before re-parsing.  Keyed on the raw
      // formatted-body string (NOT including `baseFontSize` — the
      // spans are stored at the canonical 16 px and re-scaled at
      // render time via [_fs], so a font-size slider tweak no longer
      // invalidates the entire cache and triggers a parse storm).
      final cacheKey = formattedBody;
      List<InlineSpan>? spans = _HtmlParseCache.get(cacheKey);
      if (spans == null) {
        spans = _HtmlTagParser(
          formattedBody,
          context,
          baseFontSize: 16,
          room: room,
        ).parse();
        _HtmlParseCache.set(cacheKey, spans);
      }
      if (spans.isNotEmpty) {
        return SelectableText.rich(
          TextSpan(
            style: TextStyle(fontSize: _fs(16)),
            children: spans,
          ),
          contextMenuBuilder: (_, __) => const SizedBox.shrink(),
        );
      }
      // Parser produced nothing – fall through to plain-text rendering.
    }

    // Plain text with manual URL detection.
    final spans = _linkifyPlainText(event.body, context);
    return SelectableText.rich(
      TextSpan(
        style: TextStyle(fontSize: _fs(16)),
        children: spans,
      ),
      contextMenuBuilder: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Splits [text] on URL boundaries and wraps detected links in styled,
  /// tappable [TextSpan]s.
  ///
  /// URLs that form the full text become the only span (entirely clickable).
  List<InlineSpan> _linkifyPlainText(String text, BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final uriRegExp = RegExp(
      r'\b(?:https?|ftp|matrix):\/\/(?:[^\s<>")()]|\([^\s<>")()]*\))*(?!\w)'
      r'|\b(?:www\.)[^\s<>")()]+(?!\w)',
      caseSensitive: false,
    );

    // First pass: split text on user mentions and URLs so each segment
    // gets the right inline widget (pill, tappable URL, or plain text).
    final tokens = <_PlainToken>[];
    final matches = <_PlainMatch>[];
    for (final m in userMentionPattern.allMatches(text)) {
      final id = m.group(0)!;
      if (RegExp(r'^@.+:.+$').hasMatch(id)) {
        matches.add(_PlainMatch(m.start, m.end, _PlainTokenKind.mention, id));
      }
    }
    for (final m in uriRegExp.allMatches(text)) {
      // Skip if this URL overlaps with an existing mention.
      final overlaps = matches.any(
        (other) => m.start < other.end && m.end > other.start,
      );
      if (overlaps) continue;
      matches
          .add(_PlainMatch(m.start, m.end, _PlainTokenKind.url, m.group(0)!));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        tokens.add(_PlainToken(
            _PlainTokenKind.plain, text.substring(cursor, m.start)));
      }
      tokens.add(_PlainToken(m.kind, text.substring(m.start, m.end),
          payload: m.payload));
      cursor = m.end;
    }
    if (cursor < text.length) {
      tokens.add(_PlainToken(_PlainTokenKind.plain, text.substring(cursor)));
    }
    if (tokens.isEmpty) {
      tokens.add(_PlainToken(_PlainTokenKind.plain, text));
    }

    final spans = <InlineSpan>[];
    for (final token in tokens) {
      switch (token.kind) {
        case _PlainTokenKind.plain:
          spans.add(TextSpan(
            text: token.text,
            style: TextStyle(fontSize: _fs(16)),
          ));
        case _PlainTokenKind.url:
          final rawUrl = token.payload;
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
        case _PlainTokenKind.mention:
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: UserMentionPill(
              userId: token.payload,
              room: room,
              fontSize: _fs(16),
            ),
          ));
      }
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
/// Each entry holds a list of [InlineSpan]s plus a per-entry byte
/// estimate so the total memory footprint stays bounded even when a
/// single body is very large.
///
/// The cache is LRU: on insert we move the key to the end of
/// [_keys]; on eviction we drop the head. The previous implementation
/// had a bug where re-inserting an existing key returned early and
/// never refreshed the order, so the eviction actually picked a stale
/// "oldest" rather than the real LRU entry.
class _HtmlParseCache {
  _HtmlParseCache._();

  /// Maximum number of entries. Each entry is sized via [_estimateSize].
  static const int kMaxCacheEntries = 200;

  /// Approximate byte budget for the whole cache. InlineSpan trees can
  /// hold WidgetSpans, gesture recognizers, and text — summing the
  /// plain-text length plus a per-span overhead is a good-enough proxy
  /// without dragging in a real measuring pass.
  static const int kMaxCacheBytes = 4 * 1024 * 1024; // 4 MB

  /// Estimated per-span overhead in bytes (recognizer, widget children,
  /// etc.) added to the plain-text length of each cached entry.
  static const int kPerSpanOverhead = 48;

  static final Map<String, List<InlineSpan>> _cache = {};
  static final List<String> _keys = [];
  static int _bytes = 0;

  /// Returns cached spans for [key], or `null` if not in cache. Promotes
  /// the entry to most-recently-used.
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
      // Replace the contents; update size tracking.
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
  /// lengths plus a constant per-span overhead for recognizers, widget
  /// children, and the [InlineSpan] object header.
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

/// Converts a subset of Matrix HTML into [TextSpan] lists.
///
/// Supported tags:
/// - Inline: `b`/`strong`, `i`/`em`, `u`/`ins`, `s`/`del`/`strike`, `a`,
///   `code`
/// - Block: `blockquote`, `pre`, `p`, `h1`–`h6`, `ul`, `ol`, `li`
/// - Void: `br`
/// - Entities: `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, numeric
class _HtmlTagParser {
  _HtmlTagParser(
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

        if (rawTag == 'img' || rawTag.startsWith('img ')) {
          // `<img>` is a void element.  Render the alt text as a link so
          // sighted users see a description; clients with image rendering
          // enabled can swap this for a `WidgetSpan` later.  Skipping the
          // tag silently (the previous behaviour) hid inline images and
          // confused the user.
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
          // Render an inline mention pill instead of a tappable
          // anchor.  The pill opens the profile overlay and shows the
          // hover preview.
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

// -- Plain-text linkification helpers -------------------------------------

enum _PlainTokenKind { plain, url, mention }

class _PlainMatch {
  _PlainMatch(this.start, this.end, this.kind, this.payload);
  final int start;
  final int end;
  final _PlainTokenKind kind;
  final String payload;
}

class _PlainToken {
  _PlainToken(this.kind, this.text, {this.payload = ''});
  final _PlainTokenKind kind;
  final String text;
  final String payload;
}
