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
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Accounts Page
// ─────────────────────────────────────────────────────────────────────────────

class HubAccountsPage extends StatelessWidget {
  const HubAccountsPage({
    super.key,
    required this.onLogout,
    required this.onAddAccount,
  });

  final VoidCallback onLogout;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final client = Provider.of<Client>(context, listen: false);
    final theme = Theme.of(context);

    return FutureBuilder<Profile>(
      future: client.getProfileFromUserId(client.userID!),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final initials = (profile?.displayName ?? client.userID ?? '?')
            .toUpperCase()
            .split(RegExp(' +'))
            .map((s) => s[0])
            .take(2)
            .join();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.accounts,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.manageAccounts,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Account card ─────────────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      profile?.avatarUrl == null
                          ? CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )
                          : AvatarFromUriOrFallbackImage(
                              client: client,
                              avatarUri: profile!.avatarUrl,
                              radius: 28,
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? l10n.unknown,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              client.userID ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.checkCircle2,
                        color: Colors.green,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign-out section ─────────────────────────────────────
              Text(
                l10n.sessions,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // An account row with a sign-out action (future-proofed
              // for multi-account — each account gets its own row).
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.errorContainer,
                      child: Icon(
                        LucideIcons.logOut,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      l10n.logOut,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      client.userID ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: onLogout,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Add account section ─────────────────────────────────
              Text(
                l10n.appSettings,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        theme.colorScheme.secondaryContainer,
                    child: Icon(
                      LucideIcons.userPlus,
                      size: 20,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    l10n.addAccount,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    l10n.addAccountDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    LucideIcons.chevronRight,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: onAddAccount,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
