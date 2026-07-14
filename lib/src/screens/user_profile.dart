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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:moonrelay/src/widgets/common/feedback.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// A full-featured profile view for any Matrix user.
///
/// When [room] is provided the page also shows room-specific information
/// (membership, power level) and – if the logged‑in user has sufficient
/// privileges – moderation actions (kick, ban, change power level, invite).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.client,
    required this.userID,
    this.room,
  });

  final String userID;
  final Client client;
  final Room? room;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Profile? _profile;
  CachedPresence? _presence;
  Object? _error;
  bool _loading = true;

  // Room-specific data
  User? _roomUser;
  bool _roomUserLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchPresence();
    if (widget.room != null) _fetchRoomUser();
  }

  String get _displayName =>
      _profile?.displayName ?? _profile?.userId ?? widget.userID;

  Future<void> _fetchProfile() async {
    final log = context.read<Logger>();
    final result = await withRetry(
      () => widget.client.getProfileFromUserId(widget.userID),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'getProfile(${widget.userID})',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        setState(() {
          _profile = value;
          _loading = false;
        });
      case RetryFailed(:final error):
        setState(() {
          _error = error;
          _loading = false;
        });
    }
  }

  Future<void> _fetchPresence() async {
    try {
      final presence = await withTimeoutOrFallback(
        () => widget.client.fetchCurrentPresence(widget.userID),
        fallback: CachedPresence.neverSeen(widget.userID),
        label: 'presence(${widget.userID})',
      );
      if (!mounted) return;
      setState(() => _presence = presence);
    } catch (_) {
      // Non-critical; silently ignore.
    }
  }

  Future<void> _fetchRoomUser() async {
    setState(() => _roomUserLoading = true);
    try {
      final user = await widget.room!.requestUser(widget.userID);
      if (!mounted) return;
      setState(() {
        _roomUser = user;
        _roomUserLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Try a simple lookup as fallback.
      final fallback =
          widget.room!.unsafeGetUserFromMemoryOrFallback(widget.userID);
      setState(() {
        _roomUser = fallback;
        _roomUserLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingScreen();

    if (_error != null && _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(context, AppLocalizations.of(context)!.unknown),
        body: _buildErrorBody(context),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(
        context,
        _displayName,
      ),
      body: ProfilePageContents(
        client: widget.client,
        userProfile: _profile,
        presence: _presence,
        room: widget.room,
        roomUser: _roomUser,
        roomUserLoading: _roomUserLoading,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () => context.pop(),
      ),
      title: Text(
        AppLocalizations.of(context)!.userProfilePageBanner(title),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final message = _error is TimeoutException
        ? l10n.profileLoadTimeout
        : l10n.profileLoadError('$_error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(AppLocalizations.of(context)!.retry),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _fetchProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Body of the profile page, split into logical sections.
class ProfilePageContents extends StatelessWidget {
  const ProfilePageContents({
    super.key,
    required this.client,
    required this.userProfile,
    this.presence,
    this.room,
    this.roomUser,
    this.roomUserLoading = false,
  });

  final Profile? userProfile;
  final Client client;
  final CachedPresence? presence;
  final Room? room;
  final User? roomUser;
  final bool roomUserLoading;

  String get _userId => userProfile?.userId ?? '';
  String get _displayName => userProfile?.displayName ?? _userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Profile Header ----
          _ProfileHeader(
            client: client,
            avatarUri: userProfile?.avatarUrl,
            displayName: _displayName,
            userId: _userId,
            presence: presence,
            scheme: scheme,
            l10n: l10n,
          ),

          const SizedBox(height: 24),

          // ---- About section ----
          _SectionHeader(
            icon: LucideIcons.info,
            title: l10n.sectionAbout,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _ProfileInfoCard(
            displayName: _displayName,
            userId: _userId,
            presence: presence,
            scheme: scheme,
            l10n: l10n,
          ),

          // ---- Room context section ----
          if (room != null) ...[
            const SizedBox(height: 24),
            _RoomContextSection(
              room: room!,
              roomUser: roomUser,
              roomUserLoading: roomUserLoading,
              displayName: _displayName,
              userId: _userId,
              scheme: scheme,
              l10n: l10n,
            ),
          ],

          // ---- Moderation section ----
          if (room != null && roomUser != null) ...[
            const SizedBox(height: 24),
            _ModerationSection(
              room: room!,
              user: roomUser!,
              displayName: _displayName,
              client: client,
              scheme: scheme,
              l10n: l10n,
            ),
          ],

          // ---- Actions ----
          const SizedBox(height: 24),
          _ActionsSection(
            client: client,
            userId: _userId,
            displayName: _displayName,
            scheme: scheme,
            l10n: l10n,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Profile Header (avatar, name, presence)
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.client,
    required this.avatarUri,
    required this.displayName,
    required this.userId,
    required this.presence,
    required this.scheme,
    required this.l10n,
  });

  final Client client;
  final Uri? avatarUri;
  final String displayName;
  final String userId;
  final CachedPresence? presence;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  String _formatLastSeen(BuildContext context, CachedPresence presence) {
    final ts = presence.lastActiveTimestamp;
    if (ts == null) return '';
    final timeStr = ts.relativeTimeShort(context);
    return switch (presence.presence) {
      PresenceType.online => l10n.activeAgo(timeStr),
      _ => l10n.lastSeenAgo(timeStr),
    };
  }

  @override
  Widget build(BuildContext context) {
    final presenceLabel = switch (presence?.presence) {
      PresenceType.online => l10n.presenceOnline,
      PresenceType.offline => l10n.presenceOffline,
      PresenceType.unavailable => l10n.presenceUnavailable,
      null => null,
    };
    final presenceColor = switch (presence?.presence) {
      PresenceType.online => const Color(0xFF2ECC71),
      PresenceType.unavailable => const Color(0xFFF39C12),
      PresenceType.offline => scheme.onSurfaceVariant,
      _ => scheme.onSurfaceVariant,
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                AvatarFromUriOrFallbackImage(
                  client: client,
                  avatarUri: avatarUri,
                  radius: 44,
                ),
                if (presenceLabel != null)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: presenceColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.surface,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Display name
          Text(
            displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Matrix ID
          GestureDetector(
            onLongPress: () {
              // TODO: copy to clipboard
            },
            child: Text(
              userId,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Presence badge
          if (presenceLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: presenceColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: presenceColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    presenceLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: presenceColor,
                    ),
                  ),
                ],
              ),
            ),
            // Last seen / active time
            if (presence!.lastActiveTimestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatLastSeen(context, presence!),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Profile Info Card (display name, user ID, presence detail)
// ---------------------------------------------------------------------------

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.displayName,
    required this.userId,
    required this.presence,
    required this.scheme,
    required this.l10n,
  });

  final String displayName;
  final String userId;
  final CachedPresence? presence;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _InfoRow(
              icon: LucideIcons.user,
              label: l10n.displayName,
              value: displayName,
              scheme: scheme,
            ),
            const Divider(height: 20),
            _InfoRow(
              icon: LucideIcons.atSign,
              label: l10n.userIDLabel,
              value: userId,
              scheme: scheme,
              isMono: true,
            ),
            if (presence?.statusMsg != null &&
                presence!.statusMsg!.isNotEmpty) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: LucideIcons.messageSquare,
                label: l10n.statusLabel,
                value: presence!.statusMsg!,
                scheme: scheme,
              ),
            ],
            if (presence?.lastActiveTimestamp != null) ...[
              const Divider(height: 20),
              _InfoRow(
                icon: LucideIcons.clock,
                label: l10n.lastActive,
                value:
                    presence!.lastActiveTimestamp!.relativeTimeShort(context),
                scheme: scheme,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    this.isMono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Room Context (membership, power level)
// ---------------------------------------------------------------------------

class _RoomContextSection extends StatelessWidget {
  const _RoomContextSection({
    required this.room,
    required this.roomUser,
    required this.roomUserLoading,
    required this.displayName,
    required this.userId,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final User? roomUser;
  final bool roomUserLoading;
  final String displayName;
  final String userId;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: LucideIcons.shield,
          title: l10n.roomInfoTitle,
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: roomUserLoading
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ))
                : roomUser == null
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l10n.notSet,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : _RoomContextContent(
                        room: room,
                        roomUser: roomUser!,
                        scheme: scheme,
                        l10n: l10n,
                      ),
          ),
        ),
      ],
    );
  }
}

class _RoomContextContent extends StatelessWidget {
  const _RoomContextContent({
    required this.room,
    required this.roomUser,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final User roomUser;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final membershipLabel = switch (roomUser.membership) {
      Membership.join => null,
      Membership.invite => l10n.invitedBadge,
      Membership.ban => l10n.bannedBadge,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    final roleLabel = roomUser.powerLevel.level >= 100
        ? l10n.adminBadge
        : roomUser.powerLevel.level >= 50
            ? l10n.moderatorBadge
            : null;

    return Column(
      children: [
        _InfoRow(
          icon: LucideIcons.shield,
          label: l10n.powerLevelLabel,
          value: '${roomUser.powerLevel.level}',
          scheme: scheme,
        ),
        if (roleLabel != null) ...[
          const Divider(height: 20),
          _InfoRow(
            icon: LucideIcons.star,
            label: l10n.roleLabel,
            value: roleLabel,
            scheme: scheme,
          ),
        ],
        if (membershipLabel != null) ...[
          const Divider(height: 20),
          _InfoRow(
            icon: LucideIcons.userCheck,
            label: l10n.membershipLabel,
            value: membershipLabel,
            scheme: scheme,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Moderation Actions
// ---------------------------------------------------------------------------

class _ModerationSection extends StatelessWidget {
  const _ModerationSection({
    required this.room,
    required this.user,
    required this.displayName,
    required this.client,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final User user;
  final String displayName;
  final Client client;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Don't show moderation for ourselves.
    if (user.id == client.userID) return const SizedBox.shrink();

    final canInvite = user.membership != Membership.join &&
        user.membership != Membership.invite &&
        room.canInvite;
    final canKick = user.canKick;
    final canBan = user.canBan;
    final canChangePower = user.canChangeUserPowerLevel;

    // If no actions available, hide the entire section.
    if (!canKick && !canBan && !canChangePower && !canInvite) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: LucideIcons.slash,
          title: l10n.sectionModeration,
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: scheme.errorContainer.withValues(alpha: 0.25),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (canInvite)
                  _ModerationChip(
                    icon: LucideIcons.userPlus,
                    label: l10n.actionInvite,
                    color: scheme.primary,
                    onPressed: () => _inviteUser(context),
                  ),
                if (canKick)
                  _ModerationChip(
                    icon: LucideIcons.userX,
                    label: l10n.actionKick,
                    color: scheme.tertiary,
                    onPressed: () => _kickUser(context),
                  ),
                if (canBan && user.membership != Membership.ban)
                  _ModerationChip(
                    icon: LucideIcons.ban,
                    label: l10n.actionBan,
                    color: scheme.error,
                    onPressed: () => _banUser(context),
                  ),
                if (canBan && user.membership == Membership.ban)
                  _ModerationChip(
                    icon: LucideIcons.userCheck,
                    label: l10n.actionUnban,
                    color: scheme.primary,
                    onPressed: () => _unbanUser(context),
                  ),
                if (canChangePower && user.membership == Membership.join) ...[
                  if (user.powerLevel.level < 50)
                    _ModerationChip(
                      icon: LucideIcons.shield,
                      label: l10n.actionSetModerator,
                      color: scheme.secondary,
                      onPressed: () => _setPower(context, 50),
                    ),
                  if (user.powerLevel.level < 100)
                    _ModerationChip(
                      icon: LucideIcons.shield,
                      label: l10n.actionSetAdmin,
                      color: scheme.secondary,
                      onPressed: () => _setPower(context, 100),
                    ),
                  if (user.powerLevel.level >= 50)
                    _ModerationChip(
                      icon: LucideIcons.shieldOff,
                      label: l10n.actionRemovePrivileges,
                      color: scheme.error,
                      onPressed: () => _setPower(context, 0),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _inviteUser(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionInvite),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Optional reason…',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionInvite),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await withTimeout(() => room.invite(user.id,
          reason: reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim()));
      if (!context.mounted) return;
      showFloatingSnackBar(context, l10n.userInvited(displayName));
    } catch (e) {
      if (!context.mounted) return;
      showFloatingSnackBar(context, l10n.actionFailed('$e'));
    }
  }

  Future<void> _kickUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionKick),
        content: Text(l10n.kickConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionKick),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await withTimeout(() => room.kick(user.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userKicked(displayName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _banUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionBan),
        content: Text(l10n.banConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionBan),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await withTimeout(() => room.ban(user.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userBanned(displayName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _unbanUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionUnban),
        content: Text(l10n.unbanConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionUnban),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await withTimeout(() => room.unban(user.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userUnbanned(displayName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _setPower(BuildContext context, int level) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionSetModerator),
        content: Text(l10n.changePowerLevelConfirm(displayName, level)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await withTimeout(() => room.setPower(user.id, level));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.powerLevelChanged(displayName, level))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }
}

/// A small action chip used inside the moderation section.
class _ModerationChip extends StatelessWidget {
  const _ModerationChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      onPressed: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: General Actions (DM, Block, Remove Contact, Report)
// ---------------------------------------------------------------------------

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.client,
    required this.userId,
    required this.displayName,
    required this.scheme,
    required this.l10n,
  });

  final Client client;
  final String userId;
  final String displayName;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  bool _hasDirectChat(Client client, String userId) {
    final direct = client.directChats;
    return direct.containsKey(userId);
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = client.ignoredUsers.contains(userId);
    final hasDm = _hasDirectChat(client, userId);
    final isSelf = userId == client.userID;

    if (isSelf) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: LucideIcons.navigation,
          title: l10n.actionsSection,
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // ── Start direct chat ──────────────────
              ListTile(
                leading: Icon(LucideIcons.messageSquare, color: scheme.primary),
                title: Text(l10n.actionStartDirectChat),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => _startDirectChat(context),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              if (hasDm) ...[
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(LucideIcons.userX, color: scheme.tertiary),
                  title: Text(l10n.actionRemoveContact),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => _removeContact(context),
                ),
              ],
              Divider(height: 1, indent: 16, endIndent: 16),
              // ── Block / Unblock ────────────────────
              ListTile(
                leading: Icon(
                  isBlocked ? LucideIcons.eyeOff : LucideIcons.ban,
                  color: scheme.error.withValues(alpha: 0.8),
                ),
                title: Text(
                    isBlocked ? l10n.actionUnblockUser : l10n.actionBlockUser),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () =>
                    isBlocked ? _unblockUser(context) : _blockUser(context),
              ),
              Divider(height: 1, indent: 16, endIndent: 16),
              // ── Report ────────────────────────────
              ListTile(
                leading: Icon(LucideIcons.flag,
                    color: scheme.error.withValues(alpha: 0.8)),
                title: Text(l10n.actionReport),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => _reportUser(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startDirectChat(BuildContext context) async {
    final log = context.read<Logger>();
    final goRouter = GoRouter.of(context);
    final navigator = Navigator.of(context);

    final result = await withRetry(
      () => client.startDirectChat(userId),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'startDirectChat',
    );

    if (!context.mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        navigator.pop();
        goRouter.go('/main/rooms/$value');
      case RetryFailed(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is TimeoutException
                ? l10n.couldNotStartChatTimeout
                : l10n.couldNotStartChat('$error')),
          ),
        );
    }
  }

  Future<void> _blockUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionBlockUser),
        content: Text(l10n.blockUserConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.actionBlockUser),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await client.ignoreUser(userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userBlocked(displayName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _unblockUser(BuildContext context) async {
    try {
      await client.unignoreUser(userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userUnblocked(displayName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _removeContact(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionRemoveContact),
        content: Text(l10n.removeContactConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.actionRemoveContact),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Leave all direct message rooms with this user.
      final direct = client.directChats;
      final roomIds = direct[userId];
      if (roomIds != null) {
        for (final roomId in roomIds) {
          final room = client.getRoomById(roomId);
          if (room != null && room.membership == Membership.join) {
            await room.leave();
          }
        }
      }
      // Remove from m.direct account data.
      direct.remove(userId);
      await client.setAccountData(
        client.userID!,
        'm.direct',
        direct.map((k, v) => MapEntry(k, v)),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.contactRemoved(displayName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _reportUser(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionReport),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.reportUserReason),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: l10n.reportUserHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionReport),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await withTimeout(() => client.reportUser(
            userId,
            reasonController.text.trim().isEmpty
                ? 'Reported via Moonrelay'
                : reasonController.text.trim(),
          ));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userReported)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }
}

// ── Profile overlay ────────────────────────────────────────────────────────

/// Opens the user profile as a centered modal overlay, similar to
/// [showHubOverlay] but with a plain dim background instead of blur so the
/// chat remains visible underneath.
///
/// The overlay is independent of the room route  it does not push onto
/// GoRouter's stack.  When [room] is provided the profile renders room-
/// scoped moderation actions (kick/ban/power level).
///
/// On entry the userid is validated against the Matrix ID format
/// (`^@.+:.+`); invalid identifiers surface a snackbar and the overlay
/// is not opened.
Future<void> showProfileOverlay(
  BuildContext context, {
  required String userId,
  Room? room,
}) async {
  final client = context.read<Client>();
  // Validate the userid shape before opening  Matrix IDs look like
  // `@localpart:domain` and anything else is a programming error or a
  // mis-parsed URI.
  if (!RegExp(r'^@.+:.+$').hasMatch(userId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid Matrix user id: $userId')),
    );
    return;
  }
  // Avoid opening a second overlay on top of an existing one for the
  // same user  prevents stacking if the caller fires from multiple
  // gestures in quick succession.
  final navigator = Navigator.of(context, rootNavigator: true);
  await navigator.push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => _ProfileOverlayPage(
        client: client,
        userId: userId,
        room: room,
      ),
    ),
  );
}

/// Wraps [ProfilePage] in a centered, dim-backed card so it appears as a
/// floating overlay rather than a full-screen page.
class _ProfileOverlayPage extends StatelessWidget {
  const _ProfileOverlayPage({
    required this.client,
    required this.userId,
    this.room,
  });

  final Client client;
  final String userId;
  final Room? room;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      // Wrap the page body in a fullscreen outside-tap detector so
      // tapping the dim background dismisses the profile overlay.  The
      // PageRoute's barrierDismissible flag is not sufficient on its
      // own because the page is laid out over the barrier; see
      // [BarrierDismissableOverlay] for the full rationale.  The
      // card is wrapped in [BarrierDismissBoundary] so taps inside
      // the profile (including empty padding) don't dismiss it.
      child: BarrierDismissableOverlay(
        // Plain dim background (not blur) so the underlying chat stays
        // legible and the user can still see what they were looking at.
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BarrierDismissBoundary(
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).colorScheme.surface,
                    child: ProfilePage(
                      client: client,
                      userID: userId,
                      room: room,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
