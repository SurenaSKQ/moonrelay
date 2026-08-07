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

import 'package:moonrelay/src/chat/events/html_tag_parser.dart';
import 'package:moonrelay/src/chat/events/user_mention.dart';

/// Renders a Matrix message body with rich formatting support.
///
/// If the event has `formattedBody` with `format == "org.matrix.custom.html"`,
/// the HTML content is parsed (via [HtmlTagParser]) and rendered as styled
/// [TextSpan] children inside a [SelectableText.rich].
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
      final cacheKey = formattedBody;
      List<InlineSpan>? spans = HtmlParseCache.get(cacheKey);
      if (spans == null) {
        spans = HtmlTagParser(
          formattedBody,
          context,
          baseFontSize: 16,
          room: room,
        ).parse();
        HtmlParseCache.set(cacheKey, spans);
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
    }

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

    final tokens = <PlainToken>[];
    final matches = <PlainMatch>[];
    for (final m in userMentionPattern.allMatches(text)) {
      final id = m.group(0)!;
      if (RegExp(r'^@.+:.+$').hasMatch(id)) {
        matches.add(PlainMatch(m.start, m.end, PlainTokenKind.mention, id));
      }
    }
    for (final m in uriRegExp.allMatches(text)) {
      final overlaps = matches.any(
        (other) => m.start < other.end && m.end > other.start,
      );
      if (overlaps) continue;
      matches.add(PlainMatch(m.start, m.end, PlainTokenKind.url, m.group(0)!));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        tokens.add(PlainToken(
            PlainTokenKind.plain, text.substring(cursor, m.start)));
      }
      tokens.add(PlainToken(m.kind, text.substring(m.start, m.end),
          payload: m.payload));
      cursor = m.end;
    }
    if (cursor < text.length) {
      tokens.add(PlainToken(PlainTokenKind.plain, text.substring(cursor)));
    }
    if (tokens.isEmpty) {
      tokens.add(PlainToken(PlainTokenKind.plain, text));
    }

    final spans = <InlineSpan>[];
    for (final token in tokens) {
      switch (token.kind) {
        case PlainTokenKind.plain:
          spans.add(TextSpan(
            text: token.text,
            style: TextStyle(fontSize: _fs(16)),
          ));
        case PlainTokenKind.url:
          final rawUrl = token.payload;
          final url = rawUrl.startsWith('www.') ? 'https://$rawUrl' : rawUrl;
          spans.add(TextSpan(
            text: rawUrl,
            style: TextStyle(
              color: accent,
              decoration: TextDecoration.underline,
              fontSize: _fs(16),
            ),
            recognizer: TapGestureRecognizer()..onTap = () => openUrlInBrowser(url),
          ));
        case PlainTokenKind.mention:
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
}
