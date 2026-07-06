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

import 'formatted_text_widget.dart';

/// Renders the body text of a Matrix text/emote/notice message, choosing
/// between HTML-formatted content (via [FormattedTextWidget]) and plain
/// text depending on the event's `formatted_body` and `format` fields.
///
/// Shared by all display styles (modern, bubbles, IRC) to eliminate
/// duplicated text rendering logic.
class MessageBody extends StatelessWidget {
  const MessageBody({
    super.key,
    required this.event,
    this.fontSize = 16.0,
  });

  final Event event;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final formattedBody = event.content['formatted_body'] as String?;
    final format = event.content['format'] as String?;

    if (formattedBody != null && format == 'org.matrix.custom.html') {
      return FormattedTextWidget(
        event: event,
        baseFontSize: fontSize,
      );
    }

    return Text(
      event.body,
      style: TextStyle(fontSize: fontSize),
    );
  }
}
