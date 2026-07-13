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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';

/// Settings page that lists all blocked (ignored) users and allows unblocking
/// them.
class HubBlockedUsersPage extends StatefulWidget {
  const HubBlockedUsersPage({super.key});

  @override
  State<HubBlockedUsersPage> createState() => _HubBlockedUsersPageState();
}

class _HubBlockedUsersPageState extends State<HubBlockedUsersPage> {
  bool _loading = true;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // The SDK populates client.ignoredUsers from account data.
      // Nothing extra to load  just wait a frame.
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final client = context.read<Client>();
      await client.unignoreUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userUnblocked(userId))),
      );
      setState(() {}); // refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final client = context.watch<Client>();
    final ignoredUsers = client.ignoredUsers;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(l10n.blockedUsersLoadError),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.blockedUsers,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.blockedUsersDescription,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (ignoredUsers.isEmpty)
            HubSettingsSection(
              title: l10n.blockedUsers,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(LucideIcons.eyeOff,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.blockedUsersEmpty,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            HubSettingsSection(
              title: l10n.blockedUsers,
              children: [
                for (final userId in ignoredUsers)
                  _BlockedUserTile(
                    userId: userId,
                    onUnblock: () => _unblock(userId),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.userId,
    required this.onUnblock,
  });

  final String userId;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.errorContainer,
        child: Text(
          userId.replaceAll(RegExp(r'@'), '').substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: scheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        userId,
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: onUnblock,
        icon: const Icon(LucideIcons.eyeOff, size: 16),
        label: Text(
          AppLocalizations.of(context)!.actionUnblockUser,
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
