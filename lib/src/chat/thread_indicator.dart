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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A clickable indicator shown below a message when it has thread replies.
/// Shows the reply count and navigates to the thread view on tap.
class ThreadIndicator extends StatelessWidget {
  const ThreadIndicator({
    super.key,
    required this.replyCount,
    this.onTap,
  });

  final int replyCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    // A pill, like every other small control in the chat. It was a six-pixel
    // radius on both the ink and the box, which is neither of them: not the
    // app's six, because it was written as a literal and would not have
    // tracked a change to it, and not small enough to read as a pill next to
    // the reaction chips sitting beside it.
    final radius = BorderRadius.circular(t.radiusSm);

    return Padding(
      padding: EdgeInsets.only(top: t.spaceXs),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceSm,
            vertical: t.spaceXs,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: radius,
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.3),
              width: t.borderWidthThin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_rounded,
                size: t.iconSizeSmall - 2,
                color: scheme.primary,
              ),
              SizedBox(width: t.spaceXs),
              Text(
                l10n.threadReplies(replyCount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              SizedBox(width: t.spaceXs),
              Icon(
                Icons.chevron_right,
                size: t.iconSizeSmall - 2,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
