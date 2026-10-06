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
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/licenses.dart';
import 'package:moonrelay/src/screens/privacy_policy.dart';
import 'package:moonrelay/src/screens/startup_screen/account_card.dart';
import 'package:moonrelay/src/screens/startup_screen/credits_screen.dart';
import 'package:moonrelay/src/screens/startup_screen/welcome_settings.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The first thing a user sees, and the last thing they see again on logout.
///
/// Composed entirely from [auth_surface.dart], which is where the decision
/// about what this screen looks like now lives. What is left here is what is
/// actually specific to it: which three ways in, which saved accounts, and which
/// four sub-pages the footer reaches.
///
/// The shape is one raised [AuthCard] holding the ways in, and every other
/// block a well ([AuthPanel]) beside or below it. That was not the arrangement
/// before: four cards, all with `elevation:`, all the same weight, which meant
/// the thing you came to do was no louder than the project news.
///
/// Wide windows put the brand on the left and the column of panels on the
/// right, because a 480-wide form centred in 1600 pixels is a form the eye has
/// to hunt for, and because the brand is the one thing here worth leaving room
/// for.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  /// Below this the brand above the column and the column below it is the only
  /// arrangement that fits, and the two never sit beside each other.
  static const double _twoColumnBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
        final double gutter = twoColumn ? t.spaceXxl : t.spaceXl;

        final Widget brand = AuthBrandLockup(
          name: l10n.projectName,
          tagline: l10n.startupTagline,
        );

        if (twoColumn) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.spaceXxl,
              vertical: t.spaceXl,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // The brand is vertically centred against the column of panels
                // rather than pinned to the top, so at rest the two halves
                // balance instead of the left one looking like a header.
                Expanded(
                  child: Center(child: brand),
                ),
                SizedBox(width: gutter),
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _panels(context, l10n),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceXl,
            vertical: t.spaceXl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kAuthFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  brand,
                  SizedBox(height: t.spaceXxl),
                  ..._panels(context, l10n),
                  SizedBox(height: t.spaceXl),
                  _buildFooter(context, l10n),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The column of blocks, in the order they should be read.
  ///
  /// Saved accounts first when there are any, because on a second visit the
  /// fastest thing the user can do is tap the account they used last, and
  /// burying that under a heading and two buttons is the reason people open the
  /// sign-in form for an account they are already signed in to.
  List<Widget> _panels(BuildContext context, AppLocalizations l10n) {
    final List<Widget> blocks = <Widget>[
      _buildActionCard(context, l10n),
      const AuthStackGap(),
      _buildProjectNews(context, l10n),
      const AuthStackGap(),
      _buildDonators(context, l10n),
    ];
    // The accounts panel carries its own bottom margin, because it is the one
    // block that can be absent and would otherwise leave a trailing gap where
    // itself used to be.
    return <Widget>[
      if (context.watch<AccountManager>().hasAccounts)
        _buildSavedAccounts(context, l10n),
      ...blocks,
    ];
  }

  // -- The ways in ----------------------------------------------------------

  Widget _buildActionCard(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return AuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.getStarted,
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.titleMedium?.fontFamily,
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          AuthBody(l10n.signInDescription),
          SizedBox(height: MoonrelayThemeExtension.of(context).tokens.spaceXl),
          AuthButton(
            label: l10n.signIn,
            icon: LucideIcons.logIn,
            onPressed: () => context.push('/welcome/login'),
          ),
          SizedBox(height: MoonrelayThemeExtension.of(context).tokens.spaceSm),
          AuthButton(
            label: l10n.createAccount,
            icon: LucideIcons.userPlus,
            filled: false,
            onPressed: () => context.push('/welcome/register'),
          ),
          // SSO is a link, not a third button. Two ways in are primary and the
          // third is an alternative you arrive at deliberately; three stacked
          // full-width buttons make the third one read as the least likely
          // rather than as a different kind of thing.
          SizedBox(height: MoonrelayThemeExtension.of(context).tokens.spaceSm),
          AuthLinks(
            links: <(String, VoidCallback)>[
              (
                l10n.signInWithSso,
                () => context.push('/welcome/login', extra: 'sso'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Saved accounts -------------------------------------------------------

  Widget _buildSavedAccounts(BuildContext context, AppLocalizations l10n) {
    final AccountManager accountManager = context.watch<AccountManager>();
    if (!accountManager.hasAccounts) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AuthPanel(
        title: l10n.savedAccounts,
        leading: LucideIcons.users,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final StoredAccount account in accountManager.accounts)
              AccountCard(
                account: account,
                isActive:
                    account.userId == accountManager.activeAccount?.userId,
                onTap: () => _switchToAccount(context, accountManager, account),
              ),
          ],
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

  // -- Reference material ---------------------------------------------------

  Widget _buildProjectNews(BuildContext context, AppLocalizations l10n) {
    return AuthPanel(
      title: l10n.welcomeProjectNews,
      leading: LucideIcons.newspaper,
      child: AuthBody(l10n.welcomeProjectNewsContent),
    );
  }

  Widget _buildDonators(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return AuthPanel(
      title: l10n.welcomeDonators,
      leading: LucideIcons.heart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AuthBody(l10n.welcomeDonatorsContent),
          const SizedBox(height: 4),
          // The one link on this screen. Underlined rather than accent-coloured
          // alone, because a colour is not the only way a reader finds a link
          // and this one points off the app entirely.
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: scheme.onSurfaceVariant,
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'CritBase111 ('),
                TextSpan(
                  text: 'https://codeberg.org/CritBase111',
                  style: TextStyle(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary.withValues(alpha: 0.5),
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
    );
  }

  // -- Footer ---------------------------------------------------------------

  /// The four sub-pages, as quiet links.
  ///
  /// Pushed imperatively rather than through the router, which is a small
  /// inconsistency with every other navigation in the app and is left alone
  /// here: these four screens have no routes, they have no deep links, and
  /// adding a route per page to fix an inconsistency nobody can reach is not a
  /// trade worth making in a redesign.
  Widget _buildFooter(BuildContext context, AppLocalizations l10n) {
    void push(Widget page) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );

    return AuthLinks(
      links: <(String, VoidCallback)>[
        (l10n.thirdPartyLicense, () => push(const LicensesScreen())),
        (l10n.privacyPolicy, () => push(const PrivacyPolicyPopupScreen())),
        (l10n.appSettings, () => push(const WelcomeSettingsScreen())),
        (l10n.credits, () => push(const CreditsScreen())),
      ],
    );
  }
}
