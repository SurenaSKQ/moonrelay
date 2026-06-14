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
import 'package:intl/intl.dart';

/// A timeline separator that marks the boundary between two different days.
///
/// Renders a centered date label flanked by horizontal lines, styled in a
/// muted colour to sit unobtrusively between message groups.
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isSameYear = now.year == dateTime.year;

    String label;
    if (isSameYear && now.month == dateTime.month && now.day == dateTime.day) {
      label = 'Today';
    } else if (isSameYear &&
        now.month == dateTime.month &&
        now.day == dateTime.day + 1) {
      label = 'Yesterday';
    } else if (isSameYear) {
      label = DateFormat.MMMMd().format(dateTime);
    } else {
      label = DateFormat.yMMMd().format(dateTime);
    }

    final lineColor = theme.colorScheme.onSurface.withValues(alpha: 0.15);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: lineColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFamily: 'Rubik',
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: lineColor,
            ),
          ),
        ],
      ),
    );
  }
}
