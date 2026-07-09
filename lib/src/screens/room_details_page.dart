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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_members_view.dart';
import 'package:moonrelay/src/screens/room_threads_view.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/room_notification_sheet.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/screens/encryption/user_devices_screen.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:provider/provider.dart';

/// A full room information page built with Material 3 design tokens.
///
/// Displays:
/// - Room avatar, display name, topic, and room ID
/// - Room actions (leave room, copy ID, open in browser)
/// - Room details (type, encryption, creation date, canonical alias)
/// - Top members (by power level) with a "Load all members" button
///
/// The page wraps its scrolled content in a [Scaffold] so it works both as a
/// pushed route and as an embedded page on wide screens.
class RoomInformations extends StatefulWidget {
  const RoomInformations({super.key, required this.room});

  final Room room;

  @override
  State<RoomInformations> createState() => _RoomInformationsState();
}

class _RoomInformationsState extends State<RoomInformations> {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Human-friendly room type label.
  String _roomTypeLabel(Room room) {
    final l10n = AppLocalizations.of(context)!;
    if (room.isDirectChat) return l10n.directMessage;
    if (room.isSpace) return l10n.spaceType;
    return switch (room.joinRules) {
      JoinRules.public => l10n.publicRoom,
      JoinRules.knock || JoinRules.knockRestricted => l10n.roomTypeKnock,
      JoinRules.restricted => l10n.roomTypeRestricted,
      JoinRules.invite || JoinRules.private => l10n.roomTypeInviteOnly,
      null => l10n.publicRoom,
    };
  }

  /// Whether the room is encrypted.
  bool _isEncrypted(Room room) {
    try {
      return room.encrypted;
    } catch (_) {
      return false;
    }
  }

  /// Friendly creation date string.
  String _creationDate(Room room) {
    final createEvent =
        room.getState(EventTypes.RoomCreate)?.content.tryGet('created_at');
    if (createEvent is String && createEvent.isNotEmpty) {
      final dt = DateTime.tryParse(createEvent);
      if (dt != null) {
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }
    return AppLocalizations.of(context)!.unknownDate;
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: widget.room.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.roomIdCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Room editing helpers
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Room deletion / forgetting
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final room = widget.room;
    final isEncrypted = _isEncrypted(room);
    final roomType = _roomTypeLabel(room);
    final creationDate = _creationDate(room);

    final canonicalAlias =
        room.canonicalAlias.isNotEmpty ? room.canonicalAlias : null;

    final totalMembers = (room.summary.mInvitedMemberCount ?? 0) +
        (room.summary.mJoinedMemberCount ?? 0);

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.roomInfoTitle,
          style: textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: l10n.copyRoomIdTooltip,
            onPressed: _copyRoomId,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Room identity card ────────────────────────────────────────
          _RoomIdentityCard(
            room: room,
            roomType: roomType,
            totalMembers: totalMembers,
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),

          // ── Room actions ─────────────────────────────────────────────
          _SectionHeader(title: l10n.actionsSection, scheme: scheme),
          const SizedBox(height: 8),
          _ActionTile(
            icon: LucideIcons.settings,
            label: l10n.roomSettings,
            description: l10n.roomSettingsDescription,
            onTap: () => context.push('/main/rooms/${room.id}/settings'),
            scheme: scheme,
          ),
          _ActionTile(
            icon: LucideIcons.copy,
            label: l10n.copyRoomId,
            description: room.id,
            onTap: _copyRoomId,
            scheme: scheme,
          ),

          const SizedBox(height: 16),

          // ── Room details ─────────────────────────────────────────────
          _SectionHeader(title: l10n.detailsSection, scheme: scheme),
          const SizedBox(height: 8),
          _DetailRow(
            icon: room.joinRules == JoinRules.public
                ? LucideIcons.globe
                : room.joinRules == JoinRules.knock ||
                        room.joinRules == JoinRules.knockRestricted
                    ? LucideIcons.logIn
                    : LucideIcons.lock,
            label: l10n.typeLabel,
            value: roomType,
            scheme: scheme,
          ),
          _DetailRow(
            icon: isEncrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            label: l10n.encryptionLabel,
            value: isEncrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            scheme: scheme,
          ),
          if (canonicalAlias != null)
            _DetailRow(
              icon: LucideIcons.hash,
              label: l10n.addressLabel,
              value: canonicalAlias,
              scheme: scheme,
            ),
          _DetailRow(
            icon: LucideIcons.calendar,
            label: l10n.createdLabel,
            value: creationDate,
            scheme: scheme,
          ),
          const SizedBox(height: 16),

          // ── Security ─────────────────────────────────────────────────
          _SectionHeader(title: l10n.securitySection, scheme: scheme),
          const SizedBox(height: 8),
          _buildSecuritySection(context, scheme, room, isEncrypted),
          const SizedBox(height: 16),

          // ── Top members ──────────────────────────────────────────────
          _SectionHeader(title: l10n.membersSection, scheme: scheme),
          const SizedBox(height: 8),
          _TopMembersSection(
            room: room,
            totalMembers: totalMembers,
            scheme: scheme,
          ),
          const SizedBox(height: 16),

          // ── Threads ─────────────────────────────────────────────────
          _SectionHeader(title: l10n.threads, scheme: scheme),
          const SizedBox(height: 8),
          _TopThreadsSection(
            room: room,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(
    BuildContext context,
    ColorScheme scheme,
    Room room,
    bool isEncrypted,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!isEncrypted) {
      return _DetailRow(
        icon: LucideIcons.lockOpen,
        label: l10n.encryptionLabel,
        value: l10n.notEnabled,
        scheme: scheme,
      );
    }
    final participants = room.getParticipants();

    return Column(
      children: [
        _DetailRow(
          icon: LucideIcons.shieldCheck,
          label: l10n.encryptionLabel,
          value: room.encryptionAlgorithm ?? 'Megolm',
          scheme: scheme,
        ),
        if (participants.length <= 10)
          ...participants.map((member) {
            if (member.id == room.client.userID) return const SizedBox.shrink();
            return _DetailRow(
              icon: LucideIcons.user,
              label: member.calcDisplayname(),
              value: '',
              trailing: VerificationIconButton(
                userId: member.id,
                room: room,
              ),
              scheme: scheme,
            );
          }),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class VerificationIconButton extends StatelessWidget {
  const VerificationIconButton({
    super.key,
    required this.userId,
    required this.room,
  });

  final String userId;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final enc = context.watch<EncryptionService>();
    final isUserVerified = enc.isUserVerifiedById(userId);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        isUserVerified ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
        size: 18,
        color: isUserVerified ? scheme.primary : scheme.error,
      ),
      tooltip: isUserVerified ? l10n.userIsVerified : l10n.userIsNotVerified,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserDevicesScreen(userId: userId),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Internal widgets
// ═════════════════════════════════════════════════════════════════════════════

class _RoomIdentityCard extends StatelessWidget {
  const _RoomIdentityCard({
    required this.room,
    required this.roomType,
    required this.totalMembers,
    required this.scheme,
    required this.textTheme,
  });

  final Room room;
  final String roomType;
  final int totalMembers;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = room.getLocalizedDisplayname();
    final topic = room.topic;
    final hasTopic = topic.isNotEmpty;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Large avatar
            SizedBox(
              width: 80,
              height: 80,
              child: AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: room.avatar,
              ),
            ),
            const SizedBox(height: 16),

            // Display name
            Text(
              displayName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Topic
            if (hasTopic)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  topic,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 12),

            // Badge row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: room.joinRules == JoinRules.public
                      ? Icons.public_rounded
                      : room.joinRules == JoinRules.knock ||
                              room.joinRules == JoinRules.knockRestricted
                          ? Icons.meeting_room_rounded
                          : Icons.lock_rounded,
                  label: roomType,
                  scheme: scheme,
                ),
                _InfoChip(
                  icon: Icons.people_rounded,
                  label: '$totalMembers ${l10n.members}',
                  scheme: scheme,
                ),
                if (room.isDirectChat)
                  _InfoChip(
                    icon: Icons.person_rounded,
                    label: 'Direct Chat',
                    scheme: scheme,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small chip used for room metadata badges.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section header label.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// A tappable action row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.description,
    required this.onTap,
    required this.scheme,
  }) : color = null;

  final IconData icon;
  final String label;
  final String? description;
  final Color? color;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? scheme.primary;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: effectiveColor),
        title: Text(
          label,
          style: TextStyle(color: effectiveColor),
        ),
        subtitle: description != null
            ? Text(
                description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// A read-only detail row with icon, label, and value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Top members section
// ═════════════════════════════════════════════════════════════════════════════

/// Displays the top members of a room (sorted by power level) and a button
/// to navigate to the full member list.
class _TopMembersSection extends StatelessWidget {
  const _TopMembersSection({
    required this.room,
    required this.totalMembers,
    required this.scheme,
  });

  final Room room;
  final int totalMembers;
  final ColorScheme scheme;

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

      return _MemberTile(
        member: member,
        displayName: displayName,
        permissionLabel: permissionLabel,
        scheme: scheme,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                        borderRadius: BorderRadius.circular(12),
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

// ═════════════════════════════════════════════════════════════════════════════
// Top threads section
// ═════════════════════════════════════════════════════════════════════════════

/// Displays recent thread roots in the room and a button to open the full
/// thread list in the sidebar.
class _TopThreadsSection extends StatefulWidget {
  const _TopThreadsSection({
    required this.room,
    required this.scheme,
  });

  final Room room;
  final ColorScheme scheme;

  @override
  State<_TopThreadsSection> createState() => _TopThreadsSectionState();
}

class _TopThreadsSectionState extends State<_TopThreadsSection> {
  List<Event> _threadRoots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreadRoots();
  }

  Future<void> _loadThreadRoots() async {
    try {
      final response = await widget.room.client.getThreadRoots(
        widget.room.id,
        include: Include.all,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _threadRoots = response.chunk
            .map((m) => Event.fromMatrixEvent(m, widget.room))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        ..._threadRoots.map((event) {
          final sender = event.senderFromMemoryOrFallback;
          return _ThreadRootTile(
            event: event,
            sender: sender,
            room: widget.room,
            scheme: widget.scheme,
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.messageSquare, size: 18),
              label: Text(
                l10n.showAllThreads(_threadRoots.length),
              ),
              onPressed: () => _openFullThreadList(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.scheme.primary,
                side: BorderSide(color: widget.scheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullThreadList(BuildContext context) {
    // If the right sidebar is visible and already showing threads, navigate
    // back to the room page with the threads sidebar active.
    final settings = context.read<SettingsController>();
    if (settings.rightSidebarVisible &&
        settings.rightPaneChoice == RightPaneChoice.threads) {
      Navigator.of(context).pop();
      return;
    }

    // Otherwise, open the dedicated full-screen threads list.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullRoomThreadsList(room: widget.room),
      ),
    );
  }
}

/// A single thread root tile in the room details page.
class _ThreadRootTile extends StatelessWidget {
  const _ThreadRootTile({
    required this.event,
    required this.sender,
    required this.room,
    required this.scheme,
  });

  final Event event;
  final User sender;
  final Room room;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openThread(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.transparent,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openThread(context),
          child: Row(
            children: [
              // Avatar
              SizedBox(
                width: 36,
                height: 36,
                child: AvatarFromUriOrFallbackImage(
                  client: room.client,
                  avatarUri: sender.avatarUrl,
                ),
              ),
              const SizedBox(width: 12),
              // Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender.calcDisplayname(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.body.isNotEmpty ? event.body : '(image or file)',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.originServerTs.localizedTimeShort(context),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openThread(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadViewPage(
          room: room,
          threadRootEventId: event.eventId,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Member tile (reused in both top members and full list)
// ═════════════════════════════════════════════════════════════════════════════

/// A single member tile with avatar, display name, matrix ID, permission badge,
/// and a context menu handler.
///
/// On desktop this widget responds to right-click; on mobile a long press
/// triggers the context menu.
class _MemberTile extends StatefulWidget {
  const _MemberTile({
    required this.member,
    required this.displayName,
    this.permissionLabel,
    required this.scheme,
  });

  final User member;
  final String displayName;
  final String? permissionLabel;
  final ColorScheme scheme;

  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  CachedPresence? _presence;

  @override
  void initState() {
    super.initState();
    _fetchPresence();
  }

  Future<void> _fetchPresence() async {
    try {
      final presence = await widget.member.room.client
          .fetchCurrentPresence(widget.member.id);
      if (mounted) setState(() => _presence = presence);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final membershipLabel = switch (widget.member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    final lastSeenText = _buildLastSeenText(context);

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.transparent,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showContextMenu(context),
            onSecondaryTap: () => _showContextMenu(context),
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
                const SizedBox(width: 12),

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
                                color: widget.scheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.permissionLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.scheme.onPrimaryContainer,
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
                          color: widget.scheme.onSurfaceVariant,
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
                              color: widget.scheme.onSurfaceVariant
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
                      color: widget.scheme.tertiaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      membershipLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.scheme.onTertiaryContainer,
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

  /// Shows a context menu with actions for this member.
  void _showContextMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 200, // roughly the tile width
        offset.dy,
        offset.dx + 400,
        offset.dy + 60,
      ),
      items: [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_rounded),
            title: Text(AppLocalizations.of(context)!.viewProfile),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'message',
          child: ListTile(
            leading: Icon(Icons.chat_rounded),
            title: Text(AppLocalizations.of(context)!.sendMessage),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'profile':
          _openProfile(context);
        case 'message':
          _sendMessage(context);
      }
    });
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
    final goRouter = GoRouter.of(context);
    final navigator = Navigator.of(context);
    widget.member.startDirectChat().then((roomId) {
      // Pop this page first, then navigate via GoRouter.
      navigator.pop();
      goRouter.go('/main/rooms/$roomId');
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

  String? _buildLastSeenText(BuildContext context) {
    final ts = _presence?.lastActiveTimestamp;
    if (ts == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final timeStr = ts.relativeTimeShort(context);
    return switch (_presence!.presence) {
      PresenceType.online => l10n.activeAgo(timeStr),
      _ => l10n.lastSeenAgo(timeStr),
    };
  }
}

/// A tile that toggles notification mute for the current room.
class _RoomNotificationTile extends StatefulWidget {
  const _RoomNotificationTile({required this.room});

  final Room room;

  @override
  State<_RoomNotificationTile> createState() => _RoomNotificationTileState();
}

class _RoomNotificationTileState extends State<_RoomNotificationTile> {
  bool _muted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMutedState();
  }

  Future<void> _loadMutedState() async {
    final notif = context.read<NotificationService>();
    final muted = await notif.isRoomMuted(widget.room.id);
    if (mounted) {
      setState(() {
        _muted = muted;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final notif = context.read<NotificationService>();
    final newMuted = !_muted;
    await notif.setRoomMuted(widget.room.id, newMuted);
    if (mounted) {
      setState(() => _muted = newMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMuted
                ? AppLocalizations.of(context)!.roomMuted
                : AppLocalizations.of(context)!.roomUnmuted,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final client = context.read<Client>();
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              _muted ? LucideIcons.bellOff : LucideIcons.bell,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(l10n.muteRoom),
            subtitle: Text(l10n.muteRoomDescription),
            value: _muted,
            onChanged: _loading ? null : (_) => _toggle(),
          ),
          const Divider(height: 0),
          ListTile(
            leading: Icon(
              LucideIcons.settings,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(l10n.notificationSettings),
            trailing: Icon(
              LucideIcons.chevronRight,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => showRoomNotificationSheet(
              context,
              client: client,
              room: widget.room,
            ),
          ),
        ],
      ),
    );
  }
}
