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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// Renders a stacked list of small avatars for every user who has sent a
/// read receipt for [event]. Used by [MessageEventHandler] in the timeline
/// to show "seen by" affordances per message.
///
/// Reads [Event.receipts] directly (the matrix SDK computes the latest
/// public/private receipt for any event). Filtering out the current user
/// from the visible stack avoids redundancy on single-user windows.
class ReceiptAvatars extends StatelessWidget {
  const ReceiptAvatars({super.key, required this.event, required this.room});
  final Event event;
  final Room room;

  /// Maximum number of avatars to render inline. Any leftover is collapsed
  /// into a "+N" tag.
  static const int _maxInline = 5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final l10n = AppLocalizations.of(context)!;
    final me = room.client.userID;

    // Honour the user-level "show read receipts" toggle.
    final showReceipts =
        context.select<SettingsController, bool>((c) => c.showReadReceipts);
    if (!showReceipts) return const SizedBox.shrink();

    final seen = <String, User>{};
    for (final r in event.receipts) {
      if (r.user.senderId == me) continue;
      seen[r.user.senderId] = r.user;
    }
    if (seen.isEmpty) return const SizedBox.shrink();

    final visible = seen.values.take(_maxInline).toList();
    final extra = seen.length - visible.length;

    final chipWidget = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        for (final u in visible)
          AvatarFromUriOrFallbackImage(
            client: room.client,
            avatarUri: u.avatarUrl,
            radius: ext.components.avatar.sizeSmall / 2,
          ),
        if (extra > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: t.spaceXxs),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Text(
              '+${l10n.unreadCount('$extra')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );

    // [Semantics] instead of [Tooltip]: this widget renders inline
    // inside the chat timeline, which lives under the dashboard's
    // [LayoutBuilder] shell. A Tooltip always mounts an internal
    // [OverlayPortal] (via [RawTooltip]) that activates the moment
    // the message appears; the activation marks a sibling
    // [_RenderLayoutBuilder] as needing layout mid-performLayout,
    // tripping the `_RenderLayoutBuilder was mutated in
    // performLayout` assertion (the chat-page layout race). A
    // Semantics label gives screen readers the same affordance
    // without ever materialising an overlay entry.
    return Semantics(
      label: l10n.seenBy(seen.length),
      child: Padding(
        padding: EdgeInsets.only(top: t.spaceXxs),
        child: chipWidget,
      ),
    );
  }
}
