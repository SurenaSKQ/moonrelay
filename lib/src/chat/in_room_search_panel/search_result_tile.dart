// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/chat/in_room_search_panel/highlighted_text.dart';

class InRoomResultFilter {
  final String type; // empty = all
  final IconData icon;
  const InRoomResultFilter(this.type, this.icon);
}

class InRoomResultTile extends StatelessWidget {
  final Event event;
  final List<String> keywords;
  final void Function(String eventId)? onJumpToEvent;

  const InRoomResultTile({

    super.key,
    required this.event,
    required this.keywords,
    this.onJumpToEvent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final sender = event.senderFromMemoryOrFallback;
    final senderName = sender.displayName ?? sender.id;
    final body = event.body;
    final msgType = event.messageType;

    final typeIcon = switch (msgType) {
      MessageTypes.Image => LucideIcons.image,
      MessageTypes.Video => LucideIcons.video,
      MessageTypes.Audio => LucideIcons.headphones,
      MessageTypes.File => LucideIcons.file,
      _ => LucideIcons.messageSquare,
    };

    return InkWell(
      onTap: () => onJumpToEvent?.call(event.eventId),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.spaceXs, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              margin: EdgeInsets.only(top: t.spaceXxs),
              padding: EdgeInsets.all(t.spaceXs),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(typeIcon, size: 14, color: scheme.onSurfaceVariant),
            ),
            SizedBox(width: t.spaceSm),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name + match-count chip
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (keywords.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        MatchCountChip(text: body, keywords: keywords),
                      ],
                    ],
                  ),
                  SizedBox(height: t.spaceXxs),
                  // Message body with keyword highlights
                  HighlightedText(
                    text: body.isNotEmpty ? body : '(no content)',
                    keywords: keywords,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    highlightStyle: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MatchCountChip extends StatelessWidget {
  const MatchCountChip({
    super.key,
    required this.text, required this.keywords});

  final String text;
  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final count = _countMatches();
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Text(
        count == 1
            ? l10n.searchMatchCount(count)
            : l10n.searchMatchCountMany(count),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  /// Returns the total number of case-insensitive occurrences of all
  /// [keywords] inside [text].  Non-overlapping counts are summed
  /// across all keywords so multi-word queries show the combined
  /// match count.
  int _countMatches() {
    final haystack = text.toLowerCase();
    var total = 0;
    for (final raw in keywords) {
      final needle = raw.toLowerCase();
      if (needle.isEmpty) continue;
      var idx = 0;
      while (true) {
        final found = haystack.indexOf(needle, idx);
        if (found < 0) break;
        total++;
        idx = found + needle.length;
      }
    }
    return total;
  }
}
