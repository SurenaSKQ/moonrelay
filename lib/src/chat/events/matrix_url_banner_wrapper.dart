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
import 'package:moonrelay/src/chat/events/user_mention.dart';
import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

/// Wraps a message's [child] (the text/rich-content widget) and appends one
/// [MatrixUrlBanner] per distinct Matrix URL detected in [textBody].
///
/// When [event] is provided and the event is a reply (contains
/// `m.relates_to` / `m.in_reply_to`), the reply-quoted portion of
/// [textBody] is excluded from URL scanning so that `@user:domain`
/// mentions inside the replied-to quote don't trigger preview banners.
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
    final showPreviews =
        context.select<SettingsController, bool>((c) => c.linkPreviewsEnabled);
    if (!showPreviews) return child;

    // Fast-path: the matrix URI detector's RegExp can be skipped
    // entirely when the body has no plausible matrix-style substring.
    // Most messages don't link to rooms or users, so this trims the
    // O(n) regex walk to a single substring search for the common
    // case.  The substring check accepts false positives freely --
    // parseAll still runs the full RegExp, just only on bodies that
    // could plausibly contain a match.
    if (!_couldContainMatrixReference(textBody)) return child;

    final scanText = _stripReplyQuote(textBody);
    final results = MatrixUriParser.parseAll(scanText);
    if (results.isEmpty) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        for (final result in results)
          if (!_isCoveredByInlineMention(result, event, textBody))
            MatrixUrlBanner(
              result: result,
              client: room.client,
            ),
      ],
    );
  }

  /// Returns `true` when [body] could plausibly contain a Matrix URL or
  /// bare mention.  Cheap substring scan; deliberately accepts false
  /// positives so the actual regex parse can do the precise filtering.
  ///
  /// The detector ([MatrixUriParser.detectPattern]) looks for any of:
  ///   * a literal `matrix:` prefix,
  ///   * the `matrix.to` host,
  ///   * a bare `@…:…` or `#…:…` mention.
  ///
  /// Any body missing all three substrings cannot produce a banner, so
  /// we can return [child] unchanged without running the regex.
  @visibleForTesting
  static bool couldContainMatrixReference(String body) {
    if (body.isEmpty) return false;
    // The order matches the alternation in the detector so the check
    // stays easy to audit against [MatrixUriParser.detectPattern].
    return body.contains('matrix:') ||
        body.contains('matrix.to') ||
        body.contains('@') ||
        body.contains('#');
  }

  /// Internal alias preserved so the production call site reads cleanly.
  bool _couldContainMatrixReference(String body) =>
      couldContainMatrixReference(body);

  /// Returns `true` when the inline [UserMentionPill] already surfaces
  /// this entity inside the rendered message body, so we shouldn't
  /// stack a redundant [MatrixUrlBanner] below the message.
  ///
  /// We treat any *user* entity whose id appears as a bare mention in
  /// the body, or as a `matrix.to` / `matrix:u` href in the
  /// `formatted_body`, as already covered.  Room entities are always
  /// shown as banners.
  bool _isCoveredByInlineMention(
    MatrixUriResult result,
    Event? event,
    String body,
  ) {
    if (result.entityType != MatrixUriEntity.user) return false;
    if (findUserMentions(body).any((m) => m.userId == result.entityId)) {
      return true;
    }
    final formattedBody =
        event?.content['formatted_body'] as String?;
    if (formattedBody != null) {
      if (formattedBodyContainsUserMention(formattedBody) &&
          findUserMentions(formattedBody)
              .any((m) => m.userId == result.entityId)) {
        return true;
      }
    }
    return false;
  }

  /// Strips the reply-quote prefix from [text] when this event is a reply.
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
