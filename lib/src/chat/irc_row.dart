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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Renders a single IRC-style message row with the sender always visible and
/// the timestamp shown only on hover at the end of the row.
class IRCRow extends StatefulWidget {
  const IRCRow({
    super.key,
    required this.sender,
    required this.timestamp,
    required this.body,
  });

  final Widget sender;
  final Widget timestamp;
  final Widget body;

  @override
  State<IRCRow> createState() => _IRCRowState();
}

class _IRCRowState extends State<IRCRow> {
  /// Hover lives in a [ValueNotifier] rather than [setState].
  ///
  /// The body of an IRC row is a full message: the event handler, its
  /// reaction bar, receipts, and thread count.  Calling [setState] on hover
  /// rebuilt every one of those, and because [MessageEventHandler] caches its
  /// render subtree against a key derived from its inputs, that rebuild threw
  /// the cache away on every pointer entry and exit.  A [ValueNotifier]
  /// scopes the rebuild to the timestamp alone.
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: t.spaceXxs,
      ),
      child: MouseRegion(
        onEnter: (_) => _isHovered.value = true,
        onExit: (_) => _isHovered.value = false,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.sender,
                SizedBox(width: t.spaceSm),
                Expanded(child: widget.body),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isHovered,
                builder: (context, isHovered, _) {
                  if (!isHovered) return const SizedBox.shrink();
                  return widget.timestamp;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
