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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A timeline separator that marks the boundary between two different days.
///
/// Renders a centered date label flanked by horizontal lines, styled in a
/// muted colour to sit unobtrusively between message groups.
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.dateTime});

  final DateTime dateTime;

  /// True when [dateTime] is the calendar day before [now].  Compares
  /// day-of-epoch so the check survives month and year boundaries
  /// (e.g. Jan 1 sees Dec 31 of the previous year as "yesterday").
  static bool _isYesterday(DateTime now, DateTime dateTime) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return today.difference(day).inDays == 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final chat = ext.components.chat;
    final dividerThickness = ext.components.divider.thickness;
    final dividerFontSize = chat.metadataFontSize(16);
    final now = DateTime.now();
    final isSameYear = now.year == dateTime.year;

    String label;
    if (isSameYear && now.month == dateTime.month && now.day == dateTime.day) {
      label = AppLocalizations.of(context)!.today;
    } else if (isSameYear && _isYesterday(now, dateTime)) {
      label = AppLocalizations.of(context)!.yesterday;
    } else if (isSameYear) {
      label = DateFormat.MMMMd().format(dateTime);
    } else {
      label = DateFormat.yMMMd().format(dateTime);
    }

    final lineColor =
        theme.colorScheme.onSurface.withValues(alpha: t.opacityMuted);
    final textColor =
        theme.colorScheme.onSurface.withValues(alpha: t.opacitySubtle);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: chat.groupSpacing),
      child: Row(
        children: [
          Expanded(
            child: Container(
              // The divider token's thickness, not the border scale's. The
              // rest of the app draws rules at half a pixel; a one-pixel
              // rule here made the day divider the heaviest line on the
              // screen, heavier than the bubble edges around it.
              height: dividerThickness,
              color: lineColor,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
            child: Text(
              label,
              style: TextStyle(
                fontSize: dividerFontSize,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: dividerThickness,
              color: lineColor,
            ),
          ),
        ],
      ),
    );
  }
}
