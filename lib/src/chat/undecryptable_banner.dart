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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Banner shown at the bottom of the timeline when one or more messages
/// can't be decrypted (no session key, device not verified, etc.).
///
/// The [TimelineViewState] owns a [ValueNotifier] for the undecryptable
/// count and feeds it into this widget, so the count updates whenever a
/// new encrypted event arrives without a full timeline rebuild.
class UndecryptableBanner extends StatelessWidget {
  const UndecryptableBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final TimelineViewState? state =
        context.findAncestorStateOfType<TimelineViewState>();

    final notifier = state?.undecryptableCountNotifier;
    if (notifier == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.symmetric(
              horizontal: t.spaceMd, vertical: t.spaceSm),
          child: Container(
            padding: EdgeInsets.all(t.spaceMd),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: t.opacityDisabled),
              borderRadius: BorderRadius.circular(t.radiusMd),
              border: Border.all(
                color: scheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  color: scheme.tertiary,
                  size: 22,
                ),
                SizedBox(width: t.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.encryptionDecryptionFailed,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      SizedBox(height: t.spaceXs),
                      Text(
                        count == 1
                            ? '$count ${l10n.encryptionUndecryptableMessage}'
                            : '$count ${l10n.encryptionUndecryptableMessages}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onTertiaryContainer
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
