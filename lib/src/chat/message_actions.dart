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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/message_details_page.dart';

/// A row of small icon buttons for **React**, **Reply**, **Copy**,
/// **Details**, and **Delete** (if permitted).
///
/// This widget does **not** manage its own visibility — the parent controls
/// when it appears (e.g. via a hover wrapper).
class MessageActions extends StatelessWidget {
  const MessageActions({
    super.key,
    required this.event,
    required this.room,
    required this.onReply,
  });

  final Event event;
  final Room room;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canDelete = event.canRedact;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: Icons.add_reaction_rounded,
          tooltip: AppLocalizations.of(context)!.reactTooltip,
          color: cs.onSurface.withValues(alpha: 0.6),
          onTap: () => _react(context),
        ),
        const SizedBox(width: 2),
        _ActionIcon(
          icon: Icons.reply_rounded,
          tooltip: AppLocalizations.of(context)!.replyTooltip,
          color: cs.onSurface.withValues(alpha: 0.6),
          onTap: onReply,
        ),
        const SizedBox(width: 2),
        _ActionIcon(
          icon: Icons.copy_rounded,
          tooltip: AppLocalizations.of(context)!.copyTooltip,
          color: cs.onSurface.withValues(alpha: 0.6),
          onTap: () => _copyMessage(context),
        ),
        const SizedBox(width: 2),
        _ActionIcon(
          icon: Icons.info_outline_rounded,
          tooltip: AppLocalizations.of(context)!.detailsTooltip,
          color: cs.onSurface.withValues(alpha: 0.6),
          onTap: () => _showDetails(context),
        ),
        if (canDelete) ...[
          const SizedBox(width: 2),
          _ActionIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: AppLocalizations.of(context)!.deleteTooltip,
            color: cs.error.withValues(alpha: 0.7),
            onTap: () => _confirmDelete(context),
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
