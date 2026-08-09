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

import 'package:moonrelay/src/chat/message_action_runner.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A floating toolbar of action buttons for **React**, **Reply**, **Copy**,
/// **Details**, **Forward**, **Delete** (if permitted), and **Moderation**
/// actions (kick, ban, report) for users with sufficient permissions.
///
/// When the user is the sender of a text message, the toolbar also exposes
/// **Edit** and **View edit history** actions; together with the
/// `(edited)` marker rendered inline by `MessageEventHandler` they implement
/// the full `m.replace` flow.
///
/// Uses proper [ColorScheme] surface colors that adapt to light/dark themes.
/// This widget does **not** manage its own visibility  the parent controls
/// when it appears (e.g. via a hover wrapper).
class MessageActions extends StatelessWidget {
  const MessageActions({
    super.key,
    required this.event,
    required this.room,
    required this.onReply,
    this.onForward,
    this.onThread,
    this.onEdit,
    this.timeline,
  });

  final Event event;
  final Room room;
  final VoidCallback onReply;

  /// Optional callback to open the forward dialog.
  /// When null, the forward button is hidden.
  final VoidCallback? onForward;

  /// Optional callback to open the thread view for this event.
  /// When null, the thread button is hidden.
  final VoidCallback? onThread;

  /// Optional callback triggered when the user wants to edit this event
  /// inline instead of opening the edit dialog.  When null, the edit
  /// button opens the dialog via [MessageActionRunner.edit].
  final VoidCallback? onEdit;

  /// When non-null, the action toolbar offers an "Edit history" affordance
  /// that scans the timeline for `m.replace` events related to this one.
  final Timeline? timeline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final client = room.client;
    final canDelete = event.canRedact;
    final canModerate = MessageActionRunner.canModerate(room, event);
    final canBanUser = MessageActionRunner.canBan(room, event);
    final isOwnMessage = event.senderId == client.userID;
    final canPin = room.canChangeStateEvent('m.room.pinned_events');
    final isPinned = MessageActionRunner.isPinned(room, event.eventId);
    final canEdit = MessageActionRunner.canEditText(event, room);
    final tl = timeline;
    final showEditHistory =
        tl != null && event.hasAggregatedEvents(tl, RelationshipTypes.edit);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: Icons.add_reaction_rounded,
          tooltip: l10n.reactTooltip,
          color: cs.onSurfaceVariant,
          onTap: () => _react(context),
        ),
        SizedBox(width: t.spaceXs),
        _ActionIcon(
          icon: Icons.reply_rounded,
          tooltip: l10n.replyTooltip,
          color: cs.onSurfaceVariant,
          onTap: onReply,
        ),
        SizedBox(width: t.spaceXs),
        if (onForward != null)
          _ActionIcon(
            icon: Icons.shortcut_rounded,
            tooltip: l10n.forwardTooltip,
            color: cs.onSurfaceVariant,
            onTap: onForward!,
          ),
        SizedBox(width: t.spaceXs),
        if (onThread != null)
          _ActionIcon(
            icon: Icons.forum_rounded,
            tooltip: l10n.openThread,
            color: cs.onSurfaceVariant,
            onTap: onThread!,
          ),
        SizedBox(width: t.spaceXs),
        _ActionIcon(
          icon: Icons.copy_rounded,
          tooltip: l10n.copyTooltip,
          color: cs.onSurfaceVariant,
          onTap: () => _copyMessage(context),
        ),
        SizedBox(width: t.spaceXs),
        _ActionIcon(
          icon: Icons.info_outline_rounded,
          tooltip: l10n.detailsTooltip,
          color: cs.onSurfaceVariant,
          onTap: () => _showDetails(context),
        ),
        if (canEdit) ...[
          SizedBox(width: t.spaceXs),
          _ActionIcon(
            icon: Icons.edit_outlined,
            tooltip: l10n.editTooltip,
            color: cs.onSurfaceVariant,
            onTap: () => _editMessage(context),
          ),
        ],
        if (showEditHistory) ...[
          SizedBox(width: t.spaceXs),
          if (showEditHistory)
            _ActionIcon(
              icon: Icons.history_rounded,
              tooltip: l10n.viewEditHistory,
              color: cs.onSurfaceVariant,
              onTap: () => _showEditHistory(context),
            ),
        ],
        if (canPin) ...[
          SizedBox(width: t.spaceXs),
          _ActionIcon(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            tooltip: isPinned ? l10n.unpinMessage : l10n.pinMessage,
            color: isPinned ? cs.primary : cs.onSurfaceVariant,
            onTap: () => _togglePin(context),
          ),
        ],
        if (canDelete) ...[
          SizedBox(width: t.spaceXs),
          _ActionIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.deleteTooltip,
            color: cs.error,
            onTap: () => _confirmDelete(context),
          ),
        ],
        // -- Moderation actions -------------------------------------------
        if (!isOwnMessage && (canModerate || canBanUser)) ...[
          SizedBox(width: t.spaceXs),
          _ModerationMenu(
            event: event,
            room: room,
            canKick: canModerate,
            canBan: canBanUser,
            l10n: l10n,
            cs: cs,
          ),
        ],
      ],
    );
  }

  /// Opens the reaction emoji picker and sends the chosen reaction.
  void _react(BuildContext context) {
    MessageActionRunner.react(context, event, room);
  }

  /// Copies the message body to the clipboard.
  void _copyMessage(BuildContext context) {
    MessageActionRunner.copy(context, event);
  }

  /// Opens the message details page.
  void _showDetails(BuildContext context) {
    MessageActionRunner.showDetails(context, event, room);
  }

  /// Opens the in-place editor for the message body and writes the edit
  /// (m.replace) when the user confirms.
  void _editMessage(BuildContext context) async {
    if (onEdit != null) {
      onEdit!();
    } else {
      await MessageActionRunner.edit(context, event, room, timeline: timeline);
    }
  }

  /// Shows the edit history dialog.
  void _showEditHistory(BuildContext context) {
    MessageActionRunner.showEditHistory(context, event, timeline, room);
  }

  /// Toggles the pin state of this event.
  Future<void> _togglePin(BuildContext context) async {
    await MessageActionRunner.togglePin(context, event, room);
  }

  /// Shows a confirmation dialog before redacting the event.
  Future<void> _confirmDelete(BuildContext context) async {
    await MessageActionRunner.confirmDelete(context, event);
  }
}

// ---------------------------------------------------------------------------
// Small icon button used inside the actions row
// ---------------------------------------------------------------------------

/// A larger icon button used inside the hover toolbar.
///
/// Shows a subtle circular hover/ripple via [InkWell] and adapts its
/// highlight color to the current theme.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusSm),
          onTap: onTap,
          hoverColor: cs.onSurfaceVariant.withValues(alpha: t.opacityHover),
          splashColor: cs.onSurfaceVariant.withValues(alpha: t.opacityFocus),
          child: Padding(
            padding: EdgeInsets.all(t.spaceXs + 2),
            child: Icon(icon, size: t.iconSizeMedium, color: color),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Moderation popup menu
// ---------------------------------------------------------------------------

/// A popup menu button that shows moderation actions (kick, ban, report)
/// for users with sufficient permissions in the room.
class _ModerationMenu extends StatelessWidget {
  const _ModerationMenu({
    required this.event,
    required this.room,
    required this.canKick,
    required this.canBan,
    required this.l10n,
    required this.cs,
  });

  final Event event;
  final Room room;
  final bool canKick;
  final bool canBan;
  final AppLocalizations l10n;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return PopupMenuButton<String>(
      tooltip: l10n.moderationTooltip,
      icon: Icon(Icons.more_vert_rounded,
          size: t.iconSizeMedium, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusMd)),
      color: cs.surfaceContainerHighest,
      onSelected: (value) {
        switch (value) {
          case 'kick':
            MessageActionRunner.kick(context, event, room);
          case 'ban':
            MessageActionRunner.ban(context, event, room);
          case 'report':
            MessageActionRunner.report(context, event, room);
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (canKick)
          PopupMenuItem(
            value: 'kick',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined,
                    size: t.iconSizeSmall, color: cs.tertiary),
                SizedBox(width: t.spaceSm),
                Text(l10n.actionKick),
              ],
            ),
          ),
        if (canBan)
          PopupMenuItem(
            value: 'ban',
            child: Row(
              children: [
                Icon(Icons.block_outlined,
                    size: t.iconSizeSmall, color: cs.error),
                SizedBox(width: t.spaceSm),
                Text(l10n.actionBan),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: t.iconSizeSmall, color: cs.error),
              SizedBox(width: t.spaceSm),
              Text(l10n.actionReport),
            ],
          ),
        ),
      ],
    );
  }
}
