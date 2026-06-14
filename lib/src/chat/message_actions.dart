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

/// A row of small icon buttons that appear when the user hovers over a
/// timeline message.
///
/// Provides **Reply**, **Forward** (copy to clipboard), and **Delete**
/// (redact, only if the user has permission) actions.  The button visibility
/// is controlled by a [HoverController] so that the parent can show/hide
/// the whole row in response to mouse hover.
class MessageActions extends StatefulWidget {
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
  State<MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<MessageActions> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final canDelete = event.canRedact;

    if (!_isHovered) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: const SizedBox(width: 80, height: 24),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIcon(
            icon: Icons.reply_rounded,
            tooltip: 'Reply',
            color: cs.onSurface.withValues(alpha: 0.6),
            onTap: widget.onReply,
          ),
          const SizedBox(width: 2),
          _ActionIcon(
            icon: Icons.shortcut_rounded,
            tooltip: 'Forward',
            color: cs.onSurface.withValues(alpha: 0.6),
            onTap: _forward,
          ),
          if (canDelete) ...[
            const SizedBox(width: 2),
            _ActionIcon(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete',
              color: cs.error.withValues(alpha: 0.7),
              onTap: _confirmDelete,
            ),
          ],
        ],
      ),
    );
  }

  /// Forwards the message by copying its body to the clipboard.
  void _forward() {
    final body = widget.event.body;
    Clipboard.setData(ClipboardData(text: body));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Shows a confirmation dialog before redacting the event.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text(
          'Are you sure you want to delete this message?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.event.redactEvent(reason: 'Deleted by user');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
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
