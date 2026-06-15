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

/// Common emojis shown in the quick-reaction popup.
const List<String> kQuickReactionEmojis = [
  '\u{1F44D}', // 👍
  '\u{2764}\u{FE0F}', // ❤️
  '\u{1F600}', // 😀
  '\u{1F62E}', // 😮
  '\u{1F622}', // 😢
  '\u{1F64F}', // 🙏
  '\u{1F44E}', // 👎
  '\u{1F525}', // 🔥
];

/// Opens a popup menu with common reaction emojis positioned near [button].
/// Calls [onSelected] when an emoji is picked.
void showReactionPicker(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final button = context.findRenderObject() as RenderBox;
  final position = button.localToGlobal(Offset.zero, ancestor: overlay);

  showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(
        position + const Offset(0, 24),
        position + const Offset(200, 200),
      ),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem<String>(
        enabled: false,
        child: ReactionEmojiGrid(onSelected: onSelected),
      ),
    ],
  );
}

/// A grid of emoji buttons used inside the add-reaction popup.
class ReactionEmojiGrid extends StatelessWidget {
  const ReactionEmojiGrid({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: kQuickReactionEmojis.map((emoji) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              onSelected(emoji);
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reactions bar (placed below message body)
// ---------------------------------------------------------------------------

/// A compact bar that displays emoji reactions for a timeline event.
///
/// Reactions are retrieved from [Timeline.aggregatedEvents] and grouped by
/// emoji key. The current user's reactions are visually distinguished. Tapping
/// a reaction toggles it (send if not present, redact if own). An add button
/// opens a small popup with common emojis.
class ReactionsBar extends StatelessWidget {
  const ReactionsBar({
    super.key,
    required this.event,
    required this.timeline,
    required this.room,
  });

  final Event event;
  final Timeline timeline;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final reactions =
        event.aggregatedEvents(timeline, RelationshipTypes.reaction);

    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group by reaction key.
    final grouped = <String, List<Event>>{};
    for (final r in reactions) {
      final key =
          ((r.content['m.relates_to'] as Map?) ?? const {})['key'] as String? ??
              '';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final currentUserId = room.client.userID;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          for (final entry in grouped.entries)
            _ReactionChip(
              emoji: entry.key,
              count: entry.value.length,
              isOwn: entry.value.any((e) => e.senderId == currentUserId),
              onTap: () => _toggleReaction(
                context,
                entry.key,
                entry.value,
                currentUserId,
              ),
            ),
          // Add-reaction button
          _AddReactionButton(
            onSelected: (emoji) => _addReaction(context, emoji),
          ),
        ],
      ),
    );
  }

  /// Toggle a reaction: redact own reaction event if present, otherwise send.
  Future<void> _toggleReaction(
    BuildContext context,
    String key,
    List<Event> reactions,
    String? currentUserId,
  ) async {
    final ownReaction =
        reactions.where((e) => e.senderId == currentUserId).toList();
    if (ownReaction.isNotEmpty) {
      // Redact the first own reaction for this key.
      for (final r in ownReaction) {
        try {
          await r.redactEvent();
        } catch (_) {
          // Silently ignore – the redaction may already be in-flight.
        }
      }
    } else {
      try {
        await room.sendReaction(event.eventId, key);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.failedToSendReaction('$e'))),
          );
        }
      }
    }
  }

  /// Send a new reaction with the chosen emoji.
  Future<void> _addReaction(BuildContext context, String emoji) async {
    try {
      await room.sendReaction(event.eventId, emoji);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.failedToSendReaction('$e'))),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Reaction chip
// ---------------------------------------------------------------------------

/// A small chip showing an emoji, a count, and a highlight when the current
/// user has used that reaction.
class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isOwn,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isOwn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isOwn
          ? cs.primary.withValues(alpha: 0.15)
          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isOwn ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isOwn ? cs.primary : cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add-reaction button
// ---------------------------------------------------------------------------

/// A small `+` button that opens a popup with common reaction emojis.
class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showReactionPicker(context, onSelected: onSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Icon(
            Icons.add,
            size: 14,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
