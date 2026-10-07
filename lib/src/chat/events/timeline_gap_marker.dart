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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Marks a hole in the conversation where messages are missing.
///
/// Two history windows rendered next to each other look exactly like one
/// continuous conversation, and the user reads the part below the hole as if
/// it directly follows the part above it. They then reply to something that
/// is not what they thought. The marker exists to make the discontinuity
/// visible, so the reply is aimed at the right message.
///
/// Drawn as a dashed rule rather than a solid one so it does not read as a
/// [DateSeparator], which means "a new day" and is a different claim. A solid
/// rule in the same position would be misread as a day boundary.
class TimelineGapMarker extends StatelessWidget {
  const TimelineGapMarker({super.key});

  /// Key used by the view to find gap markers in the built child list.
  static const Key gapMarkerKey = ValueKey('timeline-gap-marker');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final lineColor =
        theme.colorScheme.onSurface.withValues(alpha: t.opacitySubtle);
    final textColor =
        theme.colorScheme.onSurface.withValues(alpha: t.opacityMuted);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.spaceMd),
      child: Row(
        children: [
          Expanded(child: _DashedRule(color: lineColor)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
            child: Text(
              AppLocalizations.of(context)!.messagesMissing,
              key: gapMarkerKey,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: textColor,
              ),
            ),
          ),
          Expanded(child: _DashedRule(color: lineColor)),
        ],
      ),
    );
  }
}

/// A horizontal rule of short dashes.
class _DashedRule extends StatelessWidget {
  const _DashedRule({required this.color});

  final Color color;

  static const double _dash = 5;
  static const double _gapWidth = 4;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        child: CustomPaint(painter: _DashPainter(color)),
      );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + _DashedRule._dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x = end + _DashedRule._gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}