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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.sender,
                const SizedBox(width: 8),
                Expanded(child: widget.body),
              ],
            ),
            if (_isHovered)
              Positioned(
                top: 0,
                right: 0,
                child: widget.timestamp,
              ),
          ],
        ),
      ),
    );
  }
}
