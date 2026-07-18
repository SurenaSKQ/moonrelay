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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Shows a dialog that lets the user pick a destination room to forward
/// [event]'s content into.
///
/// The current [sourceRoom] is excluded from the picker so users don't
/// "forward" a message to the room it already lives in.
Future<void> showForwardDialog({
  required BuildContext context,
  required Event event,
  required Room sourceRoom,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ForwardDialog(
      event: event,
      sourceRoom: sourceRoom,
    ),
  );
}

class _ForwardDialog extends StatefulWidget {
  const _ForwardDialog({
    required this.event,
    required this.sourceRoom,
  });

  final Event event;
  final Room sourceRoom;

  @override
  State<_ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<_ForwardDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Gather all joined rooms except the source.
    final client = widget.sourceRoom.client;
    final rooms = client.rooms
        .where((r) =>
            r.id != widget.sourceRoom.id && r.membership == Membership.join)
        .toList()
      ..sort((a, b) => a
          .getLocalizedDisplayname()
          .toLowerCase()
          .compareTo(b.getLocalizedDisplayname().toLowerCase()));

    // Filter by search.
    final filtered = _searchQuery.isEmpty
        ? rooms
        : rooms
            .where((r) => r
                .getLocalizedDisplayname()
                .toLowerCase()
                .contains(_searchQuery))
            .toList();

    return AlertDialog(
      title: Text(l10n.forwardMessageTitle),
      content: SizedBox(
        // Constrain the dialog size so it doesn't grow too large.
        width: 380,
        height: 480,
        child: Column(
          children: [
            // -- Search field -----------------------------------------
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.forwardSearchRooms,
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // -- Preview of the message being forwarded --------------
            _buildMessagePreview(cs, l10n),
            const SizedBox(height: 12),

            // -- Room list -------------------------------------------
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.messageCircle,
                            size: 36,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty
                                ? l10n.forwardNoRooms
                                : l10n.forwardNoMatchingRooms,
                            style: TextStyle(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final room = filtered[index];
                        return _RoomTile(
                          room: room,
                          onTap: () => _doForward(context, room),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  /// A compact preview of the message content being forwarded.
  Widget _buildMessagePreview(ColorScheme cs, AppLocalizations l10n) {
    final body = widget.event.body;
    final sender = widget.event.senderFromMemoryOrFallback;
    final senderName = sender.displayName ?? sender.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.forwardMessagePreviewLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body.isNotEmpty ? body : l10n.forwardNonTextContent,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            senderName,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Performs the actual forward by sending the original event's content
  /// into [targetRoom].
  Future<void> _doForward(BuildContext context, Room targetRoom) async {
    try {
      // Build the forwarded content.
      final originalBody = widget.event.body;
      final originalHtml = widget.event.content['formatted_body'] as String?;
      final originalMsgtype =
          widget.event.content['msgtype'] as String? ?? MessageTypes.Text;

      // Determine if the original message had formatted content.
      final hasFormatted = originalHtml != null && originalHtml != originalBody;

      if (hasFormatted) {
        await targetRoom.sendEvent({
          'body': originalBody,
          'msgtype': originalMsgtype,
          'format': 'org.matrix.custom.html',
          'formatted_body': originalHtml,
        });
      } else {
        await targetRoom.sendTextEvent(originalBody);
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.forwardMessageSent(
              targetRoom.getLocalizedDisplayname(),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.forwardFailed('$e'),
          ),
        ),
      );
    }
  }
}

/// A single room tile shown in the forward picker list.
class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.onTap,
  });

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final lastBody = room.lastEvent?.body;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: _buildAvatar(cs),
      title: Text(
        room.getLocalizedDisplayname(),
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: lastBody != null
          ? Text(
              lastBody,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            )
          : null,
      trailing: room.isDirectChat
          ? Icon(LucideIcons.user, size: 14, color: cs.onSurfaceVariant)
          : Icon(LucideIcons.users, size: 14, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    if (room.avatar == null) {
      return CircleAvatar(
        radius: 16,
        child: Text(
          room
              .getLocalizedDisplayname()
              .toUpperCase()
              .split(RegExp(' +'))
              .map((s) => s[0])
              .take(2)
              .join(),
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(room.avatar.toString()),
      onBackgroundImageError: (_, __) {},
    );
  }
}
