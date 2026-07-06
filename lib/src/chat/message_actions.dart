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
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/edit_history_dialog.dart';
import 'package:moonrelay/src/chat/edit_message_dialog.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/message_details_page.dart';
import 'package:provider/provider.dart';

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
/// This widget does **not** manage its own visibility — the parent controls
/// when it appears (e.g. via a hover wrapper).
class MessageActions extends StatelessWidget {
  const MessageActions({
    super.key,
    required this.event,
    required this.room,
    required this.onReply,
    this.onForward,
    this.onThread,
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

  /// When non-null, the action toolbar offers an "Edit history" affordance
  /// that scans the timeline for `m.replace` events related to this one.
  final Timeline? timeline;

  /// Whether the current user can moderate the sender of this event.
  bool _canModerate(Client client) {
    if (event.senderId == client.userID) return false;
    try {
      final sender = room.unsafeGetUserFromMemoryOrFallback(event.senderId);
      return sender.canKick;
    } catch (_) {
      return false;
    }
  }

  /// Whether the given [eventId] is in the room's pinned-events list.
  bool _isPinned(Room room, String eventId) {
    final state = room.getState('m.room.pinned_events');
    if (state == null) return false;
    final pinned = state.content['pinned'];
    if (pinned is! List) return false;
    return pinned.contains(eventId);
  }

  /// Whether the current user can ban the sender of this event.
  bool _canBan(Client client) {
    if (event.senderId == client.userID) return false;
    try {
      final sender = room.unsafeGetUserFromMemoryOrFallback(event.senderId);
      return sender.canBan;
    } catch (_) {
      return false;
    }
  }

  /// Whether [event] is editable: text-shaped, sent by us, and not redacted.
  bool _canEditText(BuildContext context) {
    final client = room.client;
    final isMine = event.senderId == client.userID;
    if (!isMine) return false;
    if (event.redacted) return false;
    if (event.relationshipEventId != null) return false;
    final mt = event.messageType;
    if (mt != MessageTypes.Text &&
        mt != MessageTypes.Emote &&
        mt != MessageTypes.Notice) {
      return false;
    }
    try {
      return event.canRedact;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final client = room.client;
    final canDelete = event.canRedact;
    final canModerate = _canModerate(client);
    final canBanUser = _canBan(client);
    final isOwnMessage = event.senderId == client.userID;
    final canPin = room.canChangeStateEvent('m.room.pinned_events');
    final isPinned = _isPinned(room, event.eventId);
    final canEdit = _canEditText(context);
    final showEditHistory = isOwnMessage &&
        isEditedMessage(event) &&
        timeline != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: Icons.add_reaction_rounded,
          tooltip: l10n.reactTooltip,
          color: cs.onSurfaceVariant,
          onTap: () => _react(context),
        ),
        const SizedBox(width: 4),
        _ActionIcon(
          icon: Icons.reply_rounded,
          tooltip: l10n.replyTooltip,
          color: cs.onSurfaceVariant,
          onTap: onReply,
        ),
        const SizedBox(width: 4),
        if (onForward != null)
          _ActionIcon(
            icon: Icons.shortcut_rounded,
            tooltip: l10n.forwardTooltip,
            color: cs.onSurfaceVariant,
            onTap: onForward!,
          ),
        const SizedBox(width: 4),
        if (onThread != null)
          _ActionIcon(
            icon: Icons.forum_rounded,
            tooltip: l10n.openThread,
            color: cs.onSurfaceVariant,
            onTap: onThread!,
          ),
        const SizedBox(width: 4),
        _ActionIcon(
          icon: Icons.copy_rounded,
          tooltip: l10n.copyTooltip,
          color: cs.onSurfaceVariant,
          onTap: () => _copyMessage(context),
        ),
        const SizedBox(width: 4),
        _ActionIcon(
          icon: Icons.info_outline_rounded,
          tooltip: l10n.detailsTooltip,
          color: cs.onSurfaceVariant,
          onTap: () => _showDetails(context),
        ),
        if (canEdit) ...[
          const SizedBox(width: 4),
          _ActionIcon(
            icon: Icons.edit_outlined,
            tooltip: l10n.editTooltip,
            color: cs.onSurfaceVariant,
            onTap: () => _editMessage(context),
          ),
        ],
        if (showEditHistory) ...[
          const SizedBox(width: 4),
          _ActionIcon(
            icon: Icons.history_rounded,
            tooltip: l10n.viewEditHistory,
            color: cs.onSurfaceVariant,
            onTap: () => _showEditHistory(context),
          ),
        ],
        if (canPin) ...[
          const SizedBox(width: 4),
          _ActionIcon(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            tooltip: isPinned ? l10n.unpinMessage : l10n.pinMessage,
            color: isPinned ? cs.primary : cs.onSurfaceVariant,
            onTap: () => _togglePin(context),
          ),
        ],
        if (canDelete) ...[
          const SizedBox(width: 4),
          _ActionIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.deleteTooltip,
            color: cs.error,
            onTap: () => _confirmDelete(context),
          ),
        ],
        // ── Moderation actions ───────────────────────────────────────────
        if (!isOwnMessage && (canModerate || canBanUser)) ...[
          const SizedBox(width: 4),
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
    showReactionPicker(
      context,
      onSelected: (emoji) {
        room.sendReaction(event.eventId, emoji);
      },
    );
  }

  /// Copies the message body to the clipboard.
  void _copyMessage(BuildContext context) {
    final body = event.body;
    Clipboard.setData(ClipboardData(text: body));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.messageCopiedToClipboard),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Opens the message details page.
  void _showDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageDetailsPage(
          event: event,
          room: room,
        ),
      ),
    );
  }

  /// Opens the in-place editor for the message body and writes the edit
  /// (m.replace) when the user confirms.
  void _editMessage(BuildContext context) async {
    await showEditMessageDialog(context, event: event, room: room);
  }

  /// Shows the edit history dialog.
  void _showEditHistory(BuildContext context) {
    final tl = timeline;
    if (tl == null) return;
    showEditHistoryDialog(context, event: event, timeline: tl, room: room);
  }

  /// Toggles the pin state of this event.
  Future<void> _togglePin(BuildContext context) async {
    final state = room.getState('m.room.pinned_events');
    final existing = state?.content['pinned'];
    final pinned = existing is List ? List<String>.from(existing.map((e) => e.toString())) : <String>[];
    final eventId = event.eventId;

    List<String> updated;
    if (pinned.contains(eventId)) {
      updated = pinned.where((id) => id != eventId).toList();
    } else {
      updated = [...pinned, eventId];
    }

    try {
      await room.setPinnedEvents(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pinned.contains(eventId)
                  ? AppLocalizations.of(context)!.unpinMessage
                  : AppLocalizations.of(context)!.pinMessage,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed('$e'))),
        );
      }
    }
  }

  /// Shows a confirmation dialog before redacting the event.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteMessage),
        content: Text(
          AppLocalizations.of(context)!.areYouSureDeleteMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await event.redactEvent(reason: 'Deleted by user');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.failedToDelete('$e'))),
        );
      }
    }
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

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: cs.onSurfaceVariant.withValues(alpha: 0.08),
          splashColor: cs.onSurfaceVariant.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 20, color: color),
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

  String get _senderName =>
      event.senderFromMemoryOrFallback.calcDisplayname();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: l10n.moderationTooltip,
      icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cs.surfaceContainerHighest,
      onSelected: (value) {
        switch (value) {
          case 'kick':
            _confirmKick(context);
          case 'ban':
            _confirmBan(context);
          case 'report':
            _reportUser(context);
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (canKick)
          PopupMenuItem(
            value: 'kick',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 18, color: cs.tertiary),
                const SizedBox(width: 8),
                Text(l10n.actionKick),
              ],
            ),
          ),
        if (canBan)
          PopupMenuItem(
            value: 'ban',
            child: Row(
              children: [
                Icon(Icons.block_outlined, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Text(l10n.actionBan),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Text(l10n.actionReport),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmKick(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionKick),
        content: Text(l10n.kickConfirm(_senderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionKick),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final log = context.read<Logger>();
    try {
      await room.kick(event.senderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userKicked(_senderName))),
        );
      }
    } catch (e) {
      log.w('Failed to kick', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }

  void _confirmBan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionBan),
        content: Text(l10n.banConfirm(_senderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionBan),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final log = context.read<Logger>();
    try {
      await room.ban(event.senderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userBanned(_senderName))),
        );
      }
    } catch (e) {
      log.w('Failed to ban', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }

  void _reportUser(BuildContext context) async {
    final log = context.read<Logger>();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.actionReport),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(l10n.actionReport),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await room.client.reportUser(event.senderId, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userReported)),
        );
      }
    } catch (e) {
      log.w('Failed to report user', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }
}