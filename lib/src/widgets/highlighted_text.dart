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
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

/// Renders [text] with every occurrence of any of [keywords] highlighted.
///
/// Lives outside the search panel because it is not search-specific: anything
/// that renders matched text wants this. The panel used to own it privately.
class HighlightedText extends StatelessWidget {
  final String text;
  final List<String> keywords;
  final TextStyle style;
  final TextStyle highlightStyle;
  final int maxLines;

  const HighlightedText({
    super.key,
    required this.text,
    required this.keywords,
    required this.style,
    required this.highlightStyle,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (keywords.isEmpty) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    // Build a single lower-case copy for case-insensitive scanning.
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var pos = 0;

    while (pos < text.length) {
      // Find the earliest occurrence of any keyword.
      var earliestStart = text.length;
      String? earliestKw;

      for (final kw in keywords) {
        final idx = lower.indexOf(kw, pos);
        if (idx != -1 && idx < earliestStart) {
          earliestStart = idx;
          earliestKw = kw;
        }
      }

      if (earliestKw == null) {
        // No more matches: emit the rest as plain text.
        spans.add(TextSpan(text: text.substring(pos), style: style));
        break;
      }

      // Plain segment before the match.
      if (earliestStart > pos) {
        spans.add(
            TextSpan(text: text.substring(pos, earliestStart), style: style));
      }

      // Highlighted match.
      spans.add(TextSpan(
        text: text.substring(earliestStart, earliestStart + earliestKw.length),
        style: highlightStyle,
      ));

      pos = earliestStart + earliestKw.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      // Both of these were missing. RichText defaults to
      // TextScaler.noScaling, so at a 200% system text size the highlighted
      // body rendered at 100% while the sender name above it grew, which is
      // exactly the case the accessibility rule asks about. And without a
      // direction it lays out left-to-right even in a right-to-left locale.
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      // The spans carry their own sizes, so the scaler has to be told what to
      // scale from or it has no base.
      strutStyle: StrutStyle.fromTextStyle(style),
    );
  }
}
