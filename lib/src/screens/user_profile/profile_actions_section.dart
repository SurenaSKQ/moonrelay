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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:provider/provider.dart';

class ProfileActionsSection extends StatelessWidget {
  const ProfileActionsSection({
    super.key,
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
        InfoSectionHeader(
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
              // -- Start direct chat ------------------
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
              // -- Block / Unblock --------------------
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
              // -- Report ----------------------------
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
