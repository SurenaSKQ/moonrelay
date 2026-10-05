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
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/presence_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/member_context_menu.dart';
import 'package:moonrelay/src/screens/room_members_view/room_members_view.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

class TopMembersSection extends StatelessWidget {
  const TopMembersSection({
    super.key,
    required this.room,
    required this.totalMembers,
  });

  final Room room;
  final int totalMembers;

  /// Build the list of top member tiles (up to 10, sorted by power level).
  List<Widget> _buildTopMemberTiles(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final members = room.getParticipants().toList()
      ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));
    final top = members.take(10).toList();

    return top.map((member) {
      final displayName = member.calcDisplayname();
      final permissionLabel = member.powerLevel.level >= 100
          ? l10n.adminBadge
          : member.powerLevel.level >= 50
              ? l10n.moderatorBadge
              : null;

      return MemberTile(
        member: member,
        displayName: displayName,
        permissionLabel: permissionLabel,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return StreamBuilder(
      stream: room.client.onRoomState.stream
          .where((event) => event.roomId == room.id),
      builder: (context, snapshot) {
        final tiles = _buildTopMemberTiles(context);
        final canLoadMore = tiles.length < totalMembers;

        return Column(
          children: [
            ...tiles,
            if (canLoadMore)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.users, size: 18),
                    label: Text(
                      l10n.showAllMembers(totalMembers),
                    ),
                    onPressed: () => _openFullMemberList(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      side: BorderSide(color: scheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusMd),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openFullMemberList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullRoomMembersList(room: room),
      ),
    );
  }
}

class MemberTile extends StatefulWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.displayName,
    this.permissionLabel,
  });

  final User member;
  final String displayName;
  final String? permissionLabel;

  @override
  State<MemberTile> createState() => MemberTileState();
}

class MemberTileState extends State<MemberTile> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final membershipLabel = switch (widget.member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    // Watched rather than fetched once, so a member coming online
    // updates this row as the event arrives over sync. Absent bus (a test
    // with no provider) renders no presence line.
    final bus = context.read<PresenceBus?>();
    if (bus == null) {
      return _buildTile(context, l10n, t, membershipLabel, null);
    }
    return ValueListenableBuilder<CachedPresence?>(
      valueListenable: bus.listenTo(widget.member.id),
      builder: (context, live, __) => _buildTile(
        context,
        l10n,
        t,
        membershipLabel,
        live ?? bus.presenceOf(widget.member.id),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
    String? membershipLabel,
    CachedPresence? presence,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final lastSeenText = _buildLastSeenText(context, presence);

    // Long press used to sit on a GestureDetector wrapped around this InkWell,
    // which meant the long press got no ink and the tile was not focusable
    // as a whole. InkWell takes onLongPress itself.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusMd),
          color: Colors.transparent,
        ),
        child: MemberContextMenu(
          member: widget.member,
          onOpenProfile: () => _openProfile(context),
          onSendMessage: () => _sendMessage(context),
          child: InkWell(
            borderRadius: BorderRadius.circular(t.radiusMd),
            // A plain click opens the profile; it used to open the popup.
            onTap: () => _openProfile(context),
            child: Row(
              children: [
                // Avatar
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AvatarFromUriOrFallbackImage(
                    client: widget.member.room.client,
                    avatarUri: widget.member.avatarUrl,
                  ),
                ),
                SizedBox(width: t.spaceMd),

                // Name + ID + last seen
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.permissionLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(t.radiusSm),
                              ),
                              child: Text(
                                widget.permissionLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        widget.member.id,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lastSeenText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            lastSeenText,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // Membership badge (if not joined)
                if (membershipLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer
                          .withValues(alpha: t.opacitySubtle),
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                    child: Text(
                      membershipLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          client: widget.member.room.client,
          userID: widget.member.id,
          room: widget.member.room,
        ),
      ),
    );
  }

  void _sendMessage(BuildContext context) {
    // Open a direct chat with this user, or navigate to an existing one.
    final navigator = Navigator.of(context);
    widget.member.startDirectChat().then((roomId) {
      // The seam needs a context, and the one passed in is only safe to
      // touch after checking we are still mounted: startDirectChat is a
      // network round trip and this row can be rebuilt out from under it.
      if (!mounted) return;
      navigator.pop();
      openRoom(this.context, roomId);
    }).catchError((e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couldNotOpenChat('$e')),
          ),
        );
      }
    });
  }

  String? _buildLastSeenText(BuildContext context, CachedPresence? presence) {
    final ts = presence?.lastActiveTimestamp;
    if (ts == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final timeStr = ts.relativeTimeShort(context);
    return switch (presence!.presence) {
      PresenceType.online => l10n.activeAgo(timeStr),
      _ => l10n.lastSeenAgo(timeStr),
    };
  }
}