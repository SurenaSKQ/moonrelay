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
import 'package:moonrelay/src/screens/startup_screen/welcome_settings.dart';
import 'package:moonrelay/src/screens/startup_screen/credits_screen.dart';
import 'package:moonrelay/src/screens/startup_screen/account_card.dart';
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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Welcome screen shown before authentication.
///
/// Uses a responsive two-column layout:
/// - Wide (≥880px): a left pane with branding and a footer row of
///   Licenses / Privacy Policy / theme toggle, and a right pane of stacked
///   cards (login/register, project news, supporters).
/// - Narrow (<880px): branding at top, then the cards, then footer at
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

        // Narrow layout: single column, footer pinned at bottom.
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

  // -- Left pane ------------------------------------------------------------

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

  // -- Branding -------------------------------------------------------------

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

  // -- Footer row -----------------------------------------------------------

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
                builder: (_) => const WelcomeSettingsScreen(),
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
                builder: (_) => const CreditsScreen(),
              ),
            );
          },
          child: const Text('Credits'),
        ),
      ],
    );
  }

  // -- Right pane -----------------------------------------------------------

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

  // -- Saved accounts -------------------------------------------------------

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
                (account) => AccountCard(
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
        // Session was lost (e.g. DB wipe), so prompt re-login.
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

  // -- Action card (login / register / SSO) ---------------------------------

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

  // -- Project News card ----------------------------------------------------

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

  // -- Donators / Supporters card -------------------------------------------

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

// -----------------------------------------------------------------------------
// Account card for the saved-accounts list on the welcome screen
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Welcome settings screen (theme-only subset of the hub settings)
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Credits screen
// -----------------------------------------------------------------------------
