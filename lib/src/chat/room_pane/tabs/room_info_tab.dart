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
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/common/status_card.dart';

// --- Room info tab ----------------------------------------------------------

/// Shows a concise room-information panel as one tab of the room's side pane.
///
/// All derived strings (display name, topic, room type, canonical alias,
/// encryption flag, member count) are recomputed only when the room's
/// state actually changes, not on every parent rebuild. Previously every
/// parent build called `room.getLocalizedDisplayname()`,
/// `room.summary.mJoinedMemberCount`, `room.joinRules`, etc., which do
/// non-trivial SDK work; during a window resize the entire sidebar rebuilt
/// dozens of times per second. The cached fields also let the parent's
/// rebuild (e.g. from a `CurrentRoom` notification) skip the expensive
/// recompute when nothing relevant has changed.
class RoomInfoTab extends StatefulWidget {
  const RoomInfoTab({
    super.key,
    required this.room,
    required this.pinnedEventIds,
    this.onTogglePinnedFilter,
    this.pinnedFilterActive = false,
    this.onOpenPinnedTab,
  });

  final Room room;

  /// This room's pinned event ids, resolved by [RoomPage].
  ///
  /// Passed in rather than read from CurrentRoom: the tab that shows the pins
  /// and the timeline filter that applies them were reading the same global and
  /// could disagree about which room they belonged to.
  final List<String> pinnedEventIds;

  /// Toggles the timeline's pinned-only filter.
  final VoidCallback? onTogglePinnedFilter;

  /// Switches the pane to the pinned tab.
  ///
  /// Null when the info tab is mounted somewhere that cannot switch tabs, which
  /// today is only a test.
  final VoidCallback? onOpenPinnedTab;

  /// Whether the timeline is currently filtered to pinned messages.
  ///
  /// A constructor parameter rather than a read of CurrentRoom, whose
  /// pinnedFilterActive was a single global flag: toggling it in one room and
  /// switching to another used to leave the flag set for the new room too.
  final bool pinnedFilterActive;

  @override
  State<RoomInfoTab> createState() => RoomInfoTabState();
}

class RoomInfoTabState extends State<RoomInfoTab> {
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshFromRoom(force: true);
  }

  @override
  void didUpdateWidget(RoomInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      // Room changed: the bus tick is
      // already keyed by room id, so listeners automatically pick
      // up the new room.
      _refreshFromRoom(force: true);
    }
  }

  /// Refreshes the cached fields from the underlying room. Only
  /// called when the room-state bus ticks; cheap when nothing
  /// actually changed. Returns `true` when at least one field
  /// differs from the previous value (a rebuild is needed).
  ///
  /// [force] skips the comparison and always writes. The first build has no
  /// cached values to compare against, so it passes `true`; every later tick
  /// takes the comparing path, which is what makes a chatty room cheap.
  bool _refreshFromRoom({bool force = false}) {
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
      // The re-read has to happen here, in the tick handler. This widget
      // subscribed to the bus precisely so a renamed room or a changed topic
      // would show up, but the cached fields were only ever refreshed from
      // `didChangeDependencies` and `didUpdateWidget`. Without this line a tick
      // rebuilt the pane from stale values and the subscription was decoration:
      // rename a room and this tab kept showing the old name until you switched
      // rooms and came back.
      //
      // Mutating the cache inside `build` is safe and is what
      // `didChangeDependencies` already does; the values are read immediately
      // below by `_buildContent`.
      builder: (context, _, __) {
        _refreshFromRoom();
        return _buildContent(context);
      },
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
    final t = MoonrelayThemeExtension.of(context).tokens;
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
                SizedBox(height: t.spaceMd),
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
          RoomInfoRow(
            icon: LucideIcons.alignLeft,
            label: topicText,
            scheme: scheme,
          ),
          SizedBox(height: t.spaceSm),

          // Room type
          RoomInfoRow(
            icon: LucideIcons.hash,
            label: _roomType,
            scheme: scheme,
          ),
          SizedBox(height: t.spaceSm),

          // Room ID
          RoomInfoRow(
            icon: LucideIcons.tag,
            label: widget.room.id,
            scheme: scheme,
            mono: true,
          ),
          SizedBox(height: t.spaceSm),

          // Member count
          RoomInfoRow(
            icon: LucideIcons.users,
            label: l10n.membersCount(_memberCount),
            scheme: scheme,
          ),
          if (_canonicalAlias.isNotEmpty) ...[
            SizedBox(height: t.spaceSm),
            RoomInfoRow(
              icon: LucideIcons.atSign,
              label: _canonicalAlias,
              scheme: scheme,
              mono: true,
            ),
          ],

          SizedBox(height: t.spaceXl),

          // Encryption status
          StatusCard(
            icon: _encrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            label: _encrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            color: _encrypted ? scheme.primary : scheme.error,
            scheme: scheme,
          ),

          SizedBox(height: t.spaceXl),

          // -- Pinned messages ----------------------------------------
          // A summary row, not a second pinned list.
          //
          // This tab used to embed a full pinned section with its own fetch,
          // its own cache reads and its own pinned-filter toggle, twenty pixels
          // below a dedicated pinned tab doing the same job with different
          // filter state. Two pinned lists in one pane is the same mistake as
          // two panes, one level down: the user could not tell which one a
          // count came from. The row says how many there are and hands off to
          // the tab that owns them.
          _PinnedSummary(
            count: widget.pinnedEventIds.length,
            filterActive: widget.pinnedFilterActive,
            onOpen: widget.onOpenPinnedTab,
          ),
        ],
      ),
    );
  }
}

/// A single key-value row in the room-info sidebar.
class RoomInfoRow extends StatelessWidget {
  const RoomInfoRow({
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: t.iconSizeSmall, color: scheme.onSurfaceVariant),
        SizedBox(width: t.spaceSm),
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

/// How many messages are pinned, and a way to go and look at them.
class _PinnedSummary extends StatelessWidget {
  const _PinnedSummary({
    required this.count,
    required this.filterActive,
    required this.onOpen,
  });

  final int count;
  final bool filterActive;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Material(
      color: filterActive
          ? scheme.primary.withValues(alpha: t.opacitySubtle)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(t.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceSm,
            vertical: t.spaceSm,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.push_pin_outlined,
                size: t.iconSizeSmall,
                color: filterActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
              SizedBox(width: t.spaceSm),
              Expanded(
                child: Text(
                  l10n.pinnedMessagesCount(count),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: t.iconSizeSmall,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
