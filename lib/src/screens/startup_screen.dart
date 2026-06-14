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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Welcome screen shown before authentication.
///
/// Displays the app branding, a tagline, and primary action buttons
/// to log in, register, or use SSO to sign in.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout: column for narrow, row for wide.
        final bool isWide = constraints.maxWidth > 720;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildBranding(context, colors, l10n)),
                    const SizedBox(width: 48),
                    SizedBox(
                      width: 400,
                      child: _buildActionCard(context, colors, l10n),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildBranding(context, colors, l10n),
                    const SizedBox(height: 48),
                    _buildActionCard(context, colors, l10n),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBranding(
      BuildContext context, ColorScheme colors, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Simple text-based logo to avoid asset dependency
        Icon(
          LucideIcons.moon,
          size: 64,
          color: colors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.projectName,
          style: TextStyle(
            fontFamily: 'Oxanium',
            fontWeight: FontWeight.bold,
            fontSize: 36,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.startupTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.startupDescription,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      BuildContext context, ColorScheme colors, AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.getStarted,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.signInDescription,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.push('/welcome/login'),
              icon: const Icon(LucideIcons.logIn),
              label: Text(l10n.signIn),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/welcome/register'),
              icon: const Icon(LucideIcons.userPlus),
              label: Text(l10n.createAccount),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/welcome/login', extra: 'sso'),
              icon: const Icon(LucideIcons.fingerprint, size: 18),
              label: Text(l10n.signInWithSso),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
