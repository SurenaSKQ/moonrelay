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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

/// The header at the top of the room and space information pages.
///
/// Left-aligned where the previous one was centred, and that is the whole
/// change. Centring was right for a dialog and wrong here: this is a page you
/// scroll and act in, and a centred column of centred text has no leading edge
/// for the eye to return to after the panels below it. Every other surface in
/// this app is flush left, so the centred header was also the one place a
/// reader had to re-learn where to start.
class IdentityHeader extends StatelessWidget {
  const IdentityHeader({
    super.key,
    required this.name,
    required this.topic,
    required this.avatar,
    required this.chips,
  });

  final String name;
  final String topic;

  /// The avatar or space icon, already resolved by the caller.
  final Widget avatar;

  /// The facts under the name: type, member count, encryption.
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final theme = MoonrelayThemeExtension.of(context);
    final t = theme.tokens;
    final scheme = Theme.of(context).colorScheme;
    final hasTopic = topic.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The avatar overhangs the header rather than sitting inside it,
            // and carries the only glow in the page. The rail, the room list,
            // and the conversation are three depths of one wall and every one
            // of them is flat; the thing you drilled into is the one element
            // that gets to look lit, and earthshine is the only light source
            // the theme has.
            Container(
              decoration: theme.layers.glow.a > 0
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: theme.layers.glow,
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: avatar,
            ),
            SizedBox(width: t.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: MoonrelayTypography.display(context),
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasTopic) ...[
                    SizedBox(height: t.spaceXs),
                    Text(
                      topic,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          SizedBox(height: t.spaceLg),
          // `crossAxisAlignment: start` rather than centre, for the same
          // leading-edge reason as everything above it. A wrapped second line
          // of chips that centres under a flush-left heading looks broken.
          Wrap(
            spacing: t.spaceSm,
            runSpacing: t.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: chips,
          ),
        ],
        // The topic is a decorative statement of what the room is for, not a
        // control, and it is already read by the text above it. It gets no
        // semantics node of its own.
      ],
    );
  }
}
