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
import 'package:moonrelay/src/localization/app_localizations.dart';

/// The privacy policy, displayed inline.
///
/// Explains what data Moonrelay collects, how it is used, and what rights
/// users have.  The policy is displayed inline so it remains accurate
/// regardless of the user's locale selection.
class PrivacyPolicyPopupScreen extends StatelessWidget {
  const PrivacyPolicyPopupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.privacyPolicy),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Summary banner ──────────────────────────────────────────
          Card(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.shield,
                    color: colors.onSecondaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.privacyPolicyText,
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.onSecondaryContainer,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Sections ───────────────────────────────────────────────
          _Section(
            icon: LucideIcons.info,
            title: 'Introduction',
            children: [
              'Moonrelay is a Matrix chat client built with a '
                  'strong commitment to user privacy and data minimisation. '
                  'This policy describes how the application handles your '
                  'information when you use it to communicate over the '
                  'Matrix network.',
              'Moonrelay itself does not operate any servers. '
                  'All communication flows through Matrix homeservers that '
                  'you or your organisation choose.  Those servers are '
                  'governed by their own privacy policies.',
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            icon: LucideIcons.database,
            title: 'What Information We Access',
            children: [
              'Moonrelay stores locally on your device:',
              '• Your Matrix account credentials (access tokens)\n'
                  '• Room history and message content you have received\n'
                  '• User profiles, avatars, and display names\n'
                  '• Encryption keys for end-to-end encrypted rooms\n'
                  '• Application preferences (theme, layout, notification '
                  'settings)',
              'No data is transmitted to us or any third party beyond '
                  'what is required for the Matrix protocol to function. '
                  'The application does not include telemetry, analytics, '
                  'or crash reporting.',
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            icon: LucideIcons.share2,
            title: 'How Your Data Is Shared',
            children: [
              'When you send a message, upload a file, or update your '
                  'profile, that data is sent to the Matrix homeserver you '
                  'are connected to.  Depending on the room settings, it '
                  'may be further replicated to other homeservers that '
                  'participate in the same room.',
              'Moonrelay does not have access to that data.  The '
                  'application simply relays your input to the homeserver '
                  'you specify at login.',
              'If you join end-to-end encrypted rooms, message content '
                  'is encrypted on your device before it leaves, and can '
                  'only be decrypted by the intended recipients.  Even the '
                  'homeserver cannot read it.',
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            icon: LucideIcons.lock,
            title: 'Data Storage & Security',
            children: [
              'All locally cached data is stored in the application\'s '
                  'sandboxed directory on your device.  Encryption keys are '
                  'kept in an isolated key store where the platform allows.',
              'You can clear all locally stored data at any time by '
                  'logging out or by uninstalling the application.  '
                  'Persistent room data held on homeservers must be deleted '
                  'through the server\'s own administration tools.',
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            icon: LucideIcons.fileText,
            title: 'Your Rights',
            children: [
              'Under applicable data protection law (including the GDPR '
                  'for users in the European Economic Area), you have the '
                  'right to:',
              '• Access the personal data the application holds locally\n'
                  '• Rectify or erase your locally stored data\n'
                  '• Export your data (the local database can be copied '
                  'from the application directory)\n'
                  '• Lodge a complaint with your local data protection '
                  'authority',
              'Because Moonrelay is a client that only stores data '
                  'locally, most rights (access, erasure, portability) can '
                  'be exercised directly within the application or by '
                  'uninstalling it.',
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            icon: LucideIcons.code2,
            title: 'Open Source',
            children: [
              'Moonrelay is free and open-source software released under '
                  'the GNU Affero General Public License v3 or later.  You '
                  'can inspect, audit, and modify the source code at any '
                  'time.  The complete source is available at the '
                  'project\'s repository.',
              'We encourage security researchers and privacy advocates '
                  'to review the code and report any concerns.',
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            icon: LucideIcons.mail,
            title: 'Contact',
            children: [
              'If you have questions about this privacy policy or the '
                  'application\'s data practices, please open an issue on '
                  'the project repository or contact the maintainer '
                  'directly via the Matrix network.',
            ],
          ),
          const SizedBox(height: 32),

          // ── Footer note ────────────────────────────────────────────
          Text(
            'Last updated: June 2025',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A titled card section used repeatedly in the privacy policy.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final paragraph in children) ...[
              Text(
                paragraph,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
