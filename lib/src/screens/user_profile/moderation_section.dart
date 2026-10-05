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
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/common/feedback.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

class ModerationSection extends StatelessWidget {
  const ModerationSection({
    super.key,
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
        InfoSectionLabel(
            icon: LucideIcons.slash, title: l10n.sectionModeration),
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
                  ModerationChip(
                    icon: LucideIcons.userPlus,
                    label: l10n.actionInvite,
                    color: scheme.primary,
                    onPressed: () => _inviteUser(context),
                  ),
                if (canKick)
                  ModerationChip(
                    icon: LucideIcons.userX,
                    label: l10n.actionKick,
                    color: scheme.tertiary,
                    onPressed: () => _kickUser(context),
                  ),
                if (canBan && user.membership != Membership.ban)
                  ModerationChip(
                    icon: LucideIcons.ban,
                    label: l10n.actionBan,
                    color: scheme.error,
                    onPressed: () => _banUser(context),
                  ),
                if (canBan && user.membership == Membership.ban)
                  ModerationChip(
                    icon: LucideIcons.userCheck,
                    label: l10n.actionUnban,
                    color: scheme.primary,
                    onPressed: () => _unbanUser(context),
                  ),
                if (canChangePower && user.membership == Membership.join) ...[
                  if (user.powerLevel.level < 50)
                    ModerationChip(
                      icon: LucideIcons.shield,
                      label: l10n.actionSetModerator,
                      color: scheme.secondary,
                      onPressed: () => _setPower(context, 50),
                    ),
                  if (user.powerLevel.level < 100)
                    ModerationChip(
                      icon: LucideIcons.shield,
                      label: l10n.actionSetAdmin,
                      color: scheme.secondary,
                      onPressed: () => _setPower(context, 100),
                    ),
                  if (user.powerLevel.level >= 50)
                    ModerationChip(
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

class ModerationChip extends StatelessWidget {
  const ModerationChip({
    super.key,
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
