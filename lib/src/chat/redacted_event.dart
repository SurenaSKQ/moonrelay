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
import 'package:moonrelay/src/chat/message_context_menu.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Renders a compact placeholder for redacted (deleted) messages.
///
/// Shows the original sender's name and the redaction timestamp alongside
/// the "Message deleted" label. When a redaction reason is available (e.g.
/// "Deleted by moderator: spam"), it is displayed as secondary text.
///
/// The widget also wires up the context menu so users can inspect or copy
/// metadata (event ID, raw JSON, details page) even from deleted messages.
class RedactedEvent extends StatelessWidget {
  const RedactedEvent({
    super.key,
    required this.event,
    required this.isGroupContinuation,
    this.room,
    this.onForward,
    this.onThread,
    this.onReply,
    this.onOpenProfile,
  });

  final Event event;
  final bool isGroupContinuation;
  final Room? room;
  final VoidCallback? onForward;
  final VoidCallback? onThread;
  final VoidCallback? onReply;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    final senderName =
        event.senderFromMemoryOrFallback.calcDisplayname();
    final redactedBy = event.redactedBecause?.senderFromMemoryOrFallback
        .calcDisplayname();
    final reason = event.redactedBecause?.content['reason'] as String?;

    final hasContextActions = onForward != null ||
        onThread != null ||
        onReply != null ||
        onOpenProfile != null;

    final label = reason != null && redactedBy != null
        ? l10n.redactedWithReason(redactedBy, reason)
        : redactedBy != null
            ? l10n.redactedBy(redactedBy)
            : '';

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 72, vertical: t.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.delete,
            size: 14,
            color: cs.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.messageDeleted,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.30),
                  ),
                ),
                if (label.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: t.spaceXxs),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: cs.error.withValues(alpha: 0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Wrap with context menu if we have a room reference.
    if (room != null && hasContextActions) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) {
          MessageContextMenu.showForEvent(
            context: context,
            position: details.globalPosition,
            event: event,
            room: room!,
            timeline: null,
            onReply: onReply ?? () {},
            onForward: onForward,
            onThread: onThread,
            onOpenProfile: onOpenProfile ?? () {},
          );
        },
        onLongPressStart: (details) {
          MessageContextMenu.showForEvent(
            context: context,
            position: details.globalPosition,
            event: event,
            room: room!,
            timeline: null,
            onReply: onReply ?? () {},
            onForward: onForward,
            onThread: onThread,
            onOpenProfile: onOpenProfile ?? () {},
          );
        },
        child: content,
      );
    }

    return content;
  }
}
