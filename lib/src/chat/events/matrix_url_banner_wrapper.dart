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
/// If no Matrix URLs are found the [child] is returned unchanged.
class MatrixUrlBannerWrapper extends StatelessWidget {
  const MatrixUrlBannerWrapper({
    super.key,
    required this.textBody,
    required this.room,
    required this.child,
  });

  /// The rendered text/rich-content widget.
  final Widget child;

  /// The raw text body to scan for Matrix URLs.
  final String textBody;

  /// The current room (provides the [Client] for lookups).
  final Room room;

  @override
  Widget build(BuildContext context) {
    final results = MatrixUriParser.parseAll(textBody);
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
}
