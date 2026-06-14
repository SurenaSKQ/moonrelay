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
import 'package:provider/provider.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/licenses.dart';
import 'package:moonrelay/src/screens/privacy_policy.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

/// Welcome screen shown before authentication.
///
/// Uses a responsive two‑column layout:
/// - **Wide** (≥880px): a left pane with branding and a footer row of
///   Licenses / Privacy Policy / theme toggle, and a right pane of stacked
///   cards (login/register, project news, supporters).
/// - **Narrow** (<880px): branding at top, then the cards, then footer at
///   the very bottom.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SettingsController settings =
        Provider.of<SettingsController>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 880;

        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
            child: SizedBox(
              // Fill the viewport so the left column can use spacers to
              // vertically centre the branding and place the footer at bottom.
              height: constraints.maxHeight > 600
                  ? constraints.maxHeight - 96
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildLeftPane(
                      context,
                      colors,
                      l10n,
                      settings,
                    ),
                  ),
                  const SizedBox(width: 48),
                  SizedBox(
                    width: 400,
                    child: _buildRightPane(
                      context,
                      colors,
                      l10n,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Narrow layout — single column, footer pinned at bottom.
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight > 600 ? constraints.maxHeight - 96 : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildBranding(context, colors, l10n),
                  const SizedBox(height: 48),
                  _buildRightPane(context, colors, l10n),
                  const Spacer(),
                  const SizedBox(height: 32),
                  _buildFooter(context, colors, l10n, settings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Left pane ────────────────────────────────────────────────────────────

  /// The left column used in the wide layout. Branding is centred vertically
  /// while the footer row sits at the bottom.
  Widget _buildLeftPane(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
    SettingsController settings,
  ) {
    return Column(
      children: [
        const Spacer(),
        _buildBranding(context, colors, l10n),
        const Spacer(),
        _buildFooter(context, colors, l10n, settings),
      ],
    );
  }

  // ── Branding ─────────────────────────────────────────────────────────────

  Widget _buildBranding(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/moonrelay_logo.png',
          width: 100,
          height: 100,
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
        const SizedBox(height: 16),
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

  // ── Footer row ───────────────────────────────────────────────────────────

  Widget _buildFooter(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
    SettingsController settings,
  ) {
    final bool isDark = settings.themeMode == ThemeMode.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LicensesScreen(),
            ),
          ),
          child: Text(l10n.thirdPartyLicense),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PrivacyPolicyPopupScreen(),
            ),
          ),
          child: Text(l10n.privacyPolicy),
        ),
        IconButton(
          icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
          tooltip: isDark ? l10n.welcomeToggleLight : l10n.welcomeToggleDark,
          onPressed: () {
            settings.updateThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
          },
        ),
      ],
    );
  }

  // ── Right pane ───────────────────────────────────────────────────────────

  Widget _buildRightPane(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionCard(context, colors, l10n),
        const SizedBox(height: 16),
        _buildProjectNewsCard(context, colors, l10n),
        const SizedBox(height: 16),
        _buildDonatorsCard(context, colors, l10n),
      ],
    );
  }

  // ── Action card (login / register / SSO) ─────────────────────────────────

  Widget _buildActionCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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

  // ── Project News card ────────────────────────────────────────────────────

  Widget _buildProjectNewsCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.newspaper,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.welcomeProjectNews,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.welcomeProjectNewsContent,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Donators / Supporters card ───────────────────────────────────────────

  Widget _buildDonatorsCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.heart,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.welcomeDonators,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.welcomeDonatorsContent,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
