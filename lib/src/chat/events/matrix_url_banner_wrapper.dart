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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/events/matrix_url_banner.dart';
import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';

/// Wraps a message's [child] (the text/rich-content widget) and appends one
/// [MatrixUrlBanner] per distinct Matrix URL detected in [textBody].
///
/// When [event] is provided and the event is a reply (contains
/// `m.relates_to` / `m.in_reply_to`), the reply-quoted portion of
/// [textBody] is excluded from URL scanning so that `@user:domain`
/// mentions inside the replied‑to quote don't trigger preview banners.
///
/// If no Matrix URLs are found the [child] is returned unchanged.
class MatrixUrlBannerWrapper extends StatelessWidget {
  const MatrixUrlBannerWrapper({
    super.key,
    required this.textBody,
    required this.room,
    required this.child,
    this.event,
  });

  /// The rendered text/rich-content widget.
  final Widget child;

  /// The raw text body to scan for Matrix URLs.
  final String textBody;

  /// The current room (provides the [Client] for lookups).
  final Room room;

  /// The event this message belongs to, used to detect replies.
  final Event? event;

  @override
  Widget build(BuildContext context) {
    final scanText = _stripReplyQuote(textBody);
    final results = MatrixUriParser.parseAll(scanText);
    if (results.isEmpty) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        for (final result in results)
          MatrixUrlBanner(
            result: result,
            client: room.client,
          ),
      ],
    );
  }

  /// Strips the reply‑quote prefix from [text] when this event is a reply.
  ///
  /// Matrix replies prefix the body with one or more lines starting with
  /// `> ` followed by `\n\n` and the actual message.  Only the actual
  /// message portion is returned so that user IDs inside the quote don't
  /// produce spurious Matrix URL banners.
  String _stripReplyQuote(String text) {
    if (event == null) return text;

    // Check if this event is a reply.
    final relatesTo = event!.content['m.relates_to'] as Map?;
    final inReplyTo = relatesTo?['m.in_reply_to'] as Map?;
    if (inReplyTo == null || inReplyTo['event_id'] == null) return text;

    final lines = text.split('\n');
    if (lines.isEmpty) return text;

    // Count consecutive leading lines that start with "> ".
    int quoteEnd = 0;
    while (quoteEnd < lines.length && lines[quoteEnd].startsWith('> ')) {
      quoteEnd++;
    }
    if (quoteEnd == 0) return text;

    // Skip the blank line that separates the quote from the reply body.
    int bodyStart = quoteEnd;
    while (bodyStart < lines.length && lines[bodyStart].trim().isEmpty) {
      bodyStart++;
    }
    if (bodyStart >= lines.length) return text;

    return lines.sublist(bodyStart).join('\n').trim();
  }
}
