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
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/json_utils.dart';
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Full sidebar pane that lists all pinned messages for a room.
class SidebarPinnedMessages extends StatefulWidget {
  const SidebarPinnedMessages({super.key, required this.room});

  final Room room;

  @override
  State<SidebarPinnedMessages> createState() => _SidebarPinnedMessagesState();
}

class _SidebarPinnedMessagesState extends State<SidebarPinnedMessages> {
  Map<String, Event> _pinnedEvents = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedEvents();
  }

  @override
  void didUpdateWidget(SidebarPinnedMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _loadPinnedEvents();
    }
  }

  Future<void> _loadPinnedEvents() async {
    final r = widget.room;
    final pinnedIds = pinnedEventIds(r);

    final Map<String, Event> result = {};
    if (pinnedIds.isNotEmpty) {
      final fetched = await Future.wait(
        pinnedIds.map((id) => PinnedEventsCache.instance.getEvent(r, id)),
      );
      for (var i = 0; i < pinnedIds.length; i++) {
        final ev = fetched[i];
        if (ev != null) result[pinnedIds[i]] = ev;
      }
    }

    if (!mounted) return;
    setState(() {
      _pinnedEvents = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final currentRoom = context.watch<CurrentRoom>();

    final pinnedIds = pinnedEventIds(widget.room);

    if (pinnedIds.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: t.opacityDisabled),
              ),
              SizedBox(height: t.spaceMd),
              Text(
                l10n.noPinnedMessages,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              t.spaceMd, t.spaceSm, t.spaceMd, t.spaceXs),
          child: FilledButton.tonalIcon(
            onPressed: () => currentRoom.togglePinnedFilter(),
            icon: Icon(
              currentRoom.pinnedFilterActive
                  ? Icons.push_pin_outlined
                  : Icons.visibility_outlined,
              size: t.iconSizeSmall,
            ),
            label: Text(
              currentRoom.pinnedFilterActive
                  ? l10n.showAllMessages
                  : l10n.showPinnedOnly,
              style: const TextStyle(fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: currentRoom.pinnedFilterActive
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              foregroundColor: currentRoom.pinnedFilterActive
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: t.spaceXs),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
            itemCount: pinnedIds.length,
            itemBuilder: (context, index) {
              final eventId = pinnedIds[index];
              return _PinnedTile(
                room: widget.room,
                eventId: eventId,
                event: _pinnedEvents[eventId],
                scheme: scheme,
                l10n: l10n,
                currentRoom: currentRoom,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PinnedTile extends StatelessWidget {
  const _PinnedTile({
    required this.room,
    required this.eventId,
    this.event,
    required this.scheme,
    required this.l10n,
    required this.currentRoom,
  });

  final Room room;
  final String eventId;
  final Event? event;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final CurrentRoom currentRoom;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final senderName =
        event?.senderFromMemoryOrFallback.calcDisplayname() ?? 'Unknown';
    final body = event?.body.isNotEmpty == true ? event!.body : '(no content)';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: currentRoom.pinnedFilterActive &&
              currentRoom.pinnedEventIds.contains(eventId)
          ? scheme.primaryContainer.withValues(alpha: 0.3)
          : scheme.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusMd),
        onTap: () => currentRoom.togglePinnedFilter(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 14,
                color: scheme.primary,
              ),
              SizedBox(width: t.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: t.spaceXxs),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
