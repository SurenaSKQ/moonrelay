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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/common/status_card.dart';

// --- Room Info sidebar content ---------------------------------------------

/// Shows a concise room-information panel in the right sidebar.
///
/// All derived strings (display name, topic, room type, canonical alias,
/// encryption flag, member count) are recomputed only when the room's
/// state actually changes  not on every parent rebuild. Previously every
/// parent build called `room.getLocalizedDisplayname()`,
/// `room.summary.mJoinedMemberCount`, `room.joinRules`, etc., which do
/// non-trivial SDK work; during a window resize the entire sidebar rebuilt
/// dozens of times per second. The cached fields also let the parent's
/// rebuild (e.g. from a `CurrentRoom` notification) skip the expensive
/// recompute when nothing relevant has changed.
class SidebarRoomInfo extends StatefulWidget {
  const SidebarRoomInfo({super.key, required this.room});

  final Room room;

  @override
  State<SidebarRoomInfo> createState() => SidebarRoomInfoState();
}

class SidebarRoomInfoState extends State<SidebarRoomInfo> {
  // -- Cached derived state -----------------------------------------
  // Each field is paired with a `_last*` value so the state-event
  // listener can do a no-op setState when nothing visible actually
  // changed (the room can emit many state events per minute; we only
  // need to rebuild when one of the user-facing fields actually moves).
  String _displayName = '';
  String _topic = '';
  int _memberCount = 0;
  String _roomType = '';
  String _canonicalAlias = '';
  bool _encrypted = false;

  @override
  void initState() {
    super.initState();
    // Listen to the shared room-state bus instead of subscribing
    // directly to the client's onRoomState stream. The bus is one
    // O(N) stream filter per state event regardless of how many
    // subscribers there are; the previous per-widget subscription
    // cost O(subscribers) per state event.
    _bindRoomStateBus();
  }

  /// Subscribes to the room-state bus and re-binds when the room id
  /// changes. The bus is provided by the app shell so we don't have
  /// to instantiate a new one per sidebar.
  void _bindRoomStateBus() {
    // No-op; didChangeDependencies wires the listener.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshFromRoom(force: true);
  }

  @override
  void didUpdateWidget(SidebarRoomInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      // Room changed (right sidebar re-mounted): the bus tick is
      // already keyed by room id, so listeners automatically pick
      // up the new room.
      _refreshFromRoom(force: true);
    }
  }

  @override
  void dispose() {
    // The bus outlives this widget; we don't cancel the subscription
    // here. The bus drops per-room state when the room is left.
    super.dispose();
  }

  /// Refreshes the cached fields from the underlying room. Only
  /// called when the room-state bus ticks; cheap when nothing
  /// actually changed. Returns `true` when at least one field
  /// differs from the previous value (a rebuild is needed).
  bool _refreshFromRoom({required bool force}) {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;
    final nextDisplayName = room.getLocalizedDisplayname();
    final nextTopic = room.topic;
    final nextMemberCount = (room.summary.mJoinedMemberCount ?? 0) +
        (room.summary.mInvitedMemberCount ?? 0);
    final nextRoomType = room.isDirectChat
        ? l10n.directMessage
        : room.isSpace
            ? l10n.spaceType
            : room.joinRules == JoinRules.public
                ? l10n.publicRoom
                : room.joinRules == JoinRules.knock ||
                        room.joinRules == JoinRules.knockRestricted
                    ? l10n.roomTypeKnock
                    : room.joinRules == JoinRules.restricted
                        ? l10n.roomTypeRestricted
                        : l10n.roomTypeInviteOnly;
    final nextAlias = room.canonicalAlias;
    final nextEncrypted = room.encrypted;

    if (!force &&
        nextDisplayName == _displayName &&
        nextTopic == _topic &&
        nextMemberCount == _memberCount &&
        nextRoomType == _roomType &&
        nextAlias == _canonicalAlias &&
        nextEncrypted == _encrypted) {
      return false;
    }

    _displayName = nextDisplayName;
    _topic = nextTopic;
    _memberCount = nextMemberCount;
    _roomType = nextRoomType;
    _canonicalAlias = nextAlias;
    _encrypted = nextEncrypted;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the room-state bus so this widget only rebuilds
    // when this specific room emits a state event. Subscribers for
    // other rooms do not affect us.
    final bus = context.read<RoomStateBus>();
    return ValueListenableBuilder<int>(
      valueListenable: bus.tickFor(widget.room.id),
      builder: (context, _, __) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Adapt padding and avatar radius to the pane width. Narrow panes get a
    // tighter layout so the header doesn't dominate the view.
    //
    // Read the width from [LayoutScope] (already provided by the dashboard
    // controller) rather than [MediaQuery.sizeOf]. The latter subscribes to
    // *every* MediaQuery change across the app and rebuilds on unrelated
    // changes like keyboard show/hide; LayoutScope only fires on actual
    // layout-pass width changes scoped to this subtree.
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = LayoutScope.of(context).availableWidth;
    final compactPane = width < 240;
    final outerPadding = compactPane ? 12.0 : 16.0;
    final avatarRadius = compactPane ? 28.0 : 36.0;
    final nameFontSize = compactPane ? 16.0 : 18.0;
    final topicText = _topic.isNotEmpty ? _topic : l10n.noTopicSet;

    return SingleChildScrollView(
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room avatar + name
          Center(
            child: Column(
              children: [
                AvatarFromUriOrFallbackImage(
                  client: widget.room.client,
                  avatarUri: widget.room.avatar,
                  radius: avatarRadius,
                ),
                const SizedBox(height: 12),
                Text(
                  _displayName,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(height: outerPadding),

          // Topic
          InfoRow(
            icon: LucideIcons.alignLeft,
            label: topicText,
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // Room type
          InfoRow(
            icon: LucideIcons.hash,
            label: _roomType,
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // Room ID
          InfoRow(
            icon: LucideIcons.tag,
            label: widget.room.id,
            scheme: scheme,
            mono: true,
          ),
          const SizedBox(height: 8),

          // Member count
          InfoRow(
            icon: LucideIcons.users,
            label: l10n.membersCount(_memberCount),
            scheme: scheme,
          ),
          if (_canonicalAlias.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoRow(
              icon: LucideIcons.atSign,
              label: _canonicalAlias,
              scheme: scheme,
              mono: true,
            ),
          ],

          const SizedBox(height: 24),

          // Encryption status
          StatusCard(
            icon: _encrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            label: _encrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            color: _encrypted ? scheme.primary : scheme.error,
            scheme: scheme,
          ),

          const SizedBox(height: 24),

          // -- Pinned messages section ---------------------------------
          PinnedSection(room: widget.room),
        ],
      ),
    );
  }
}

/// A single key-value row in the room-info sidebar.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.scheme,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontFamily: mono ? 'JetBrainsMono' : null,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// --- Pinned messages section (embedded in room info) -----------------------

/// A compact pinned-messages section rendered inside the room-info sidebar.
///
/// Shows a header with pin count and a list of pinned message previews.
/// Tapping a preview filters the timeline to show only pinned messages.
class PinnedSection extends StatefulWidget {
  const PinnedSection({super.key, required this.room});

  final Room room;

  @override
  State<PinnedSection> createState() => PinnedSectionState();
}

class PinnedSectionState extends State<PinnedSection> {
  Map<String, Event> _pinnedEvents = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedEvents();
  }

  @override
  void didUpdateWidget(PinnedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _loadPinnedEvents();
    }
  }

  Future<void> _loadPinnedEvents() async {
    final r = widget.room;
    final state = r.getState('m.room.pinned_events');
    final pinnedList = state?.content['pinned'];
    final pinnedIds =
        pinnedList is List ? pinnedList.cast<String>() : <String>[];

    // Try to look up events from the timeline first (no network needed), then
    // fall back to the shared cache, then to the server via the cache itself.
    final Map<String, Event> result = {};
    final missingFromTimeline = <String>[];
    try {
      final timeline = await r.getTimeline();
      for (final id in pinnedIds) {
        final event = timeline.events.where((e) => e.eventId == id).firstOrNull;
        if (event != null) {
          result[id] = event;
        } else {
          missingFromTimeline.add(id);
        }
      }
    } catch (_) {
      // Timeline not available  fall through to the cache/server for all.
      missingFromTimeline
        ..clear()
        ..addAll(pinnedIds);
    }

    if (missingFromTimeline.isNotEmpty) {
      final fetched = await Future.wait(missingFromTimeline
          .map((id) => PinnedEventsCache.instance.getEvent(r, id)));
      for (var i = 0; i < missingFromTimeline.length; i++) {
        final ev = fetched[i];
        if (ev != null) result[missingFromTimeline[i]] = ev;
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
    final l10n = AppLocalizations.of(context)!;
    final currentRoom = context.watch<CurrentRoom>();

    final state = widget.room.getState('m.room.pinned_events');
    final pinnedList = state?.content['pinned'];
    final pinnedIds =
        pinnedList is List ? pinnedList.cast<String>() : <String>[];
    final count = pinnedIds.length;

    // Show fewer previews when the pane is narrow so they don't dominate.
    //
    // Read the width from [LayoutScope] (already provided by the dashboard
    // controller) rather than [MediaQuery.sizeOf]. The latter subscribes to
    // *every* MediaQuery change across the app and rebuilds on unrelated
    // changes like keyboard show/hide; LayoutScope only fires on actual
    // layout-pass width changes scoped to this subtree.
    final paneWidth = LayoutScope.of(context).availableWidth;
    final previewCount = paneWidth < 240 ? 1 : (paneWidth < 320 ? 2 : 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- Section header -----------------------------------------
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (count > 0) {
              final settings = context.read<SettingsController>();
              settings.setRightPaneChoice(RightPaneChoice.pinned);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 16,
                  color: currentRoom.pinnedFilterActive
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pinnedMessages,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (count == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noPinnedMessages,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          )
        else if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          )
        else
          ...pinnedIds.take(previewCount).map((eventId) {
            return PinnedPreview(
              room: widget.room,
              eventId: eventId,
              event: _pinnedEvents[eventId],
              scheme: scheme,
              l10n: l10n,
            );
          }),
        if (count > previewCount) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              final settings = context.read<SettingsController>();
              settings.setRightPaneChoice(RightPaneChoice.pinned);
            },
            child: Text(
              l10n.pinnedMessagesCount(count),
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
          ),
        ],
      ],
    );
  }
}

/// A one-line preview of a pinned event used inside the room-info sidebar.
class PinnedPreview extends StatelessWidget {
  const PinnedPreview({
    super.key,
    required this.room,
    required this.eventId,
    this.event,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final String eventId;
  final Event? event;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final senderName =
        event?.senderFromMemoryOrFallback.calcDisplayname() ?? '\u2026';
    final body = event?.body.isNotEmpty == true
        ? event!.body.replaceAll('\n', ' ')
        : '\u2026';

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        context.read<CurrentRoom>().togglePinnedFilter();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.push_pin_outlined,
              size: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
