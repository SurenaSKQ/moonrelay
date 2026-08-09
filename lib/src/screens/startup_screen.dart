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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/licenses.dart';
import 'package:moonrelay/src/screens/privacy_policy.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

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
          return Padding(
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
                    child: SingleChildScrollView(
                      child: _buildRightPane(
                        context,
                        colors,
                        l10n,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Narrow layout  single column, footer pinned at bottom.
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: t.spaceLg),
        Text(
          l10n.projectName,
          style: TextStyle(
            fontFamily: 'Oxanium',
            fontWeight: FontWeight.bold,
            fontSize: 36,
            color: colors.onSurface,
          ),
        ),
        SizedBox(height: t.spaceSm),
        Text(
          l10n.startupTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: t.spaceLg),
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
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _WelcomeSettingsScreen(),
              ),
            );
          },
          child: Text(l10n.appSettings),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _CreditsScreen(),
              ),
            );
          },
          child: const Text('Credits'),
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSavedAccounts(context, colors, l10n),
        _buildActionCard(context, colors, l10n),
        SizedBox(height: t.spaceLg),
        _buildProjectNewsCard(context, colors, l10n),
        SizedBox(height: t.spaceLg),
        _buildDonatorsCard(context, colors, l10n),
      ],
    );
  }

  // ── Saved accounts ───────────────────────────────────────────────────────

  /// Shows a list of previously-logged-in accounts that the user can tap to
  /// switch to.  Hidden when there are no saved accounts.
  Widget _buildSavedAccounts(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final accountManager = context.watch<AccountManager>();
    if (!accountManager.hasAccounts) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: t.elevationMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusLg),
        ),
        child: Padding(
          padding: EdgeInsets.all(t.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.users, size: 18, color: colors.primary),
                  SizedBox(width: t.spaceSm),
                  Text(
                    l10n.savedAccounts,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceMd),
              ...accountManager.accounts.map(
                (account) => _AccountCard(
                  account: account,
                  isActive:
                      account.userId == accountManager.activeAccount?.userId,
                  onTap: () =>
                      _switchToAccount(context, accountManager, account),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchToAccount(
    BuildContext context,
    AccountManager accountManager,
    StoredAccount account,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // If it's already the active account, just go to rooms
    // (but only if the session is still valid).
    if (account.userId == accountManager.activeAccount?.userId) {
      if (accountManager.isLoggedIn) {
        context.go('/main/rooms');
      } else {
        // Session was lost (e.g. DB wipe) → prompt re-login.
        context.go('/welcome/login', extra: {
          'homeserver': account.homeserver,
          'username': account.userId,
        });
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.switchToAccount(account.userId)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // The actual client switch happens in AccountManager.
    // If the new session isn't valid, route to the login page.
    final loggedIn = await accountManager.switchToAccount(account.userId);
    if (!loggedIn && context.mounted) {
      context.go('/welcome/login', extra: {
        'homeserver': account.homeserver,
        'username': account.userId,
      });
    }
  }

  // ── Action card (login / register / SSO) ─────────────────────────────────

  Widget _buildActionCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      elevation: t.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusLg),
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
            SizedBox(height: t.spaceSm),
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
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
              ),
            ),
            SizedBox(height: t.spaceMd),
            OutlinedButton.icon(
              onPressed: () => context.push('/welcome/register'),
              icon: const Icon(LucideIcons.userPlus),
              label: Text(l10n.createAccount),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
              ),
            ),
            SizedBox(height: t.spaceMd),
            TextButton.icon(
              onPressed: () => context.push('/welcome/login', extra: 'sso'),
              icon: const Icon(LucideIcons.fingerprint, size: 18),
              label: Text(l10n.signInWithSso),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      elevation: t.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.newspaper,
                  size: t.iconSizeMedium,
                  color: colors.primary,
                ),
                SizedBox(width: t.spaceSm),
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
            SizedBox(height: t.spaceMd),
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      elevation: t.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.heart,
                  size: t.iconSizeMedium,
                  color: colors.primary,
                ),
                SizedBox(width: t.spaceSm),
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
            SizedBox(height: t.spaceMd),
            Text(
              l10n.welcomeDonatorsContent,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            SizedBox(height: t.spaceSm),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'CritBase111 ('),
                  TextSpan(
                    text: 'https://codeberg.org/CritBase111',
                    style: TextStyle(
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse('https://codeberg.org/CritBase111'),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                  const TextSpan(text: ')'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account card for the saved-accounts list on the welcome screen
// ─────────────────────────────────────────────────────────────────────────────

/// A tappable row showing a saved Matrix account.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.isActive,
    required this.onTap,
  });

  final StoredAccount account;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primaryContainer.withValues(alpha: 0.3)
                : colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(t.radiusMd),
            border: isActive
                ? Border.all(
                    color: colors.primary.withValues(alpha: t.opacityDisabled))
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isActive
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                child: Text(
                  account.userId
                      .replaceAll(RegExp(r'@'), '')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isActive
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(width: t.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.userId,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      account.homeserver,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  LucideIcons.checkCircle2,
                  size: 18,
                  color: Colors.green,
                )
              else
                Text(
                  context.watch<AppLocalizations>().tapToSwitch,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome settings screen (theme-only subset of the hub settings)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Credits screen
// ─────────────────────────────────────────────────────────────────────────────

/// A screen that displays developer and project information to build user trust.
class _CreditsScreen extends StatelessWidget {
  const _CreditsScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Credits'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Project identity card ────────────────────────────────
          Card(
            child: Padding(
              padding: EdgeInsets.all(t.spaceXl),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.moon,
                    size: 48,
                    color: colors.primary,
                  ),
                  SizedBox(height: t.spaceMd),
                  Text(
                    l10n.projectName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  SizedBox(height: t.spaceXs),
                  Text(
                    'Version 0.2.0+1',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.spaceLg),

          // ── Author ───────────────────────────────────────────────
          _CreditsSection(
            icon: LucideIcons.user,
            title: l10n.author,
            children: [
              Text(
                'Surena Karimpour Ghannadi is the creator and primary '
                'maintainer of Moonrelay.',
              ),
              Text(
                'You can reach the project via Matrix or by opening an '
                'issue on the project repository.',
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),

          // ── License ──────────────────────────────────────────────
          _CreditsSection(
            icon: LucideIcons.scrollText,
            title: 'License',
            children: [
              Text(
                'Moonrelay is free software released under the GNU Affero '
                'General Public License version 3 or later.',
              ),
              Text(l10n.appLicenseNotice),
            ],
          ),
          SizedBox(height: t.spaceLg),

          // ── Open Source Credits ──────────────────────────────────
          _CreditsSection(
            icon: LucideIcons.code2,
            title: 'Open Source Acknowledgements',
            children: [
              Text(
                'Moonrelay builds on the Matrix Dart SDK and many other '
                'open-source packages. See the Third Party Licenses '
                'screen for the full list.',
              ),
              Text(
                'Portions of the date/time formatting and colour utilities '
                'are derived from FluffyChat, used under the terms of '
                'the AGPLv3.',
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),

          // ── Repository ───────────────────────────────────────────
          _CreditsSection(
            icon: LucideIcons.gitBranch,
            title: 'Repository',
            children: [
              Text(
                'The complete source code is available for inspection, '
                'audit, and contribution at the project repository:',
              ),
              Padding(
                padding: EdgeInsets.only(top: t.spaceSm),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'https://codeberg.org/SurenaSKQ/moonrelay/',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => launchUrl(
                                Uri.parse(
                                  'https://codeberg.org/SurenaSKQ/moonrelay/',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// A card section used in the credits screen.
class _CreditsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _CreditsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                SizedBox(width: t.spaceMd),
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
            SizedBox(height: t.spaceMd),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple settings page accessible from the welcome screen.
///
/// Exposes a subset of theming options:
/// - Theme mode (System / Light / Dark)
/// - Look & feel (MoonrelayThemeSpec)
/// - Accent colour (MoonrelayAccent)
class _WelcomeSettingsScreen extends StatelessWidget {
  const _WelcomeSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appSettings),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<SettingsController>(
        builder: (context, controller, _) {
          return ListView(
            padding: EdgeInsets.all(t.spaceXl),
            children: [
              Text(
                l10n.appearance,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                l10n.customizeExperience,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.spaceXl),

              // Theme mode
              _SettingsSection(
                title: l10n.themeMode,
                children: [
                  RadioGroup<ThemeMode>(
                    groupValue: controller.themeMode,
                    onChanged: (v) => controller.updateThemeMode(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.system),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.light),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.dark),
                          value: ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Theme (look and feel)
              _SettingsSection(
                title: l10n.lookAndFeel,
                children: [
                  RadioGroup<String>(
                    groupValue: controller.selectedThemeId,
                    onChanged: (v) {
                      if (v != null) controller.updateSelectedTheme(v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final look in MoonrelayThemes.all)
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: controller.selectedAccent.seedColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                SizedBox(width: t.spaceMd),
                                Text(look.label),
                              ],
                            ),
                            value: look.id,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Accent colour
              _SettingsSection(
                title: l10n.accentColor,
                children: [
                  RadioGroup<String>(
                    groupValue: controller.selectedAccentId,
                    onChanged: (v) {
                      if (v != null) controller.updateSelectedAccent(v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final accent in MoonrelayAccents.all)
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: accent.seedColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: t.spaceMd),
                                Text(accent.label),
                              ],
                            ),
                            value: accent.id,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Language
              _SettingsSection(
                title: l10n.language,
                children: [
                  RadioGroup<String?>(
                    groupValue: controller.locale,
                    onChanged: (v) => controller.updateLocale(v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String?>(
                          title: Text(l10n.languageSystem),
                          value: null,
                        ),
                        RadioListTile<String?>(
                          title: Text(l10n.languageEnglish),
                          value: 'en',
                        ),
                        RadioListTile<String?>(
                          title: Text(l10n.languagePersian),
                          value: 'fa',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A labelled card section used in settings pages.
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: t.spaceSm),
        Card(
          elevation: t.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusMd),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
