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
import 'package:moonrelay/src/screens/hub_screen/initials.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

// -----------------------------------------------------------------------------
// Accounts Page
// -----------------------------------------------------------------------------

/// The signed-in account, signing out, and adding another.
///
/// Three `Card`s at `theme.dividerColor` became three sections on the app's
/// one hairline, and two 18px headings that were not in the type scale became
/// section titles. The page no longer draws a heading of its own: the strip
/// above it says Accounts and gives it the sentence it used to repeat.
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
    final t = theme.moonrelay.tokens;

    // If the session has been torn down (userID is null) return an empty
    // placeholder; the overlay will be dismissed and the route will
    // redirect to /welcome on the next frame.
    if (client.userID == null) return const SizedBox.shrink();

    return FutureBuilder<Profile>(
      future: client.getProfileFromUserId(client.userID!),
      builder: (context, snapshot) {
        // Show a skeleton placeholder while the profile is in flight
        // so the account card does not flash empty for a beat.  Once
        // the data arrives we render the populated card; on error we
        // fall through to a minimal version using just the user id.
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading(theme);
        }
        final profile = snapshot.data;

        return HubPageBody(
          children: [
            // -- The account ---------------------------------------------
            HubSettingsSection(
              title: l10n.yourAccount,
              children: [
                Padding(
                  padding: EdgeInsets.all(t.spaceLg),
                  child: Row(
                    children: [
                      profile?.avatarUrl == null
                          ? CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                matrixInitials(profile?.displayName),
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
                      SizedBox(width: t.spaceLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? l10n.unknown,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: t.spaceXxs),
                            Text(
                              client.userID!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFamily: MoonrelayTypography.mono(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.checkCircle2,
                        // `primary`, not `Colors.green`.
                        //
                        // This is the app's only "you are here" tick, and it
                        // was a hardcoded Material green: a colour that is in
                        // no scheme the app ships, that reads as a different
                        // product's success state, and that has a different
                        // luminance relationship to the surface in light mode
                        // than it does in dark. The accent is already the one
                        // colour the app uses to mean "this is active".
                        color: theme.colorScheme.primary,
                        size: t.iconSizeMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // -- Sessions ---------------------------------------------------
            HubSettingsSection(
              title: l10n.sessions,
              children: [
                InfoPanelRow(
                  icon: LucideIcons.logOut,
                  label: l10n.logOut,
                  description: client.userID!,
                  destructive: true,
                  onTap: onLogout,
                ),
              ],
            ),

            // -- Another account --------------------------------------------
            HubSettingsSection(
              title: l10n.accounts,
              children: [
                InfoPanelRow(
                  icon: LucideIcons.userPlus,
                  label: l10n.addAccount,
                  description: l10n.addAccountDescription,
                  onTap: onAddAccount,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Renders a placeholder layout while [Profile] is being fetched.
  ///
  /// Mirrors the dimensions of the populated account card so the
  /// surrounding layout does not jump when the data arrives.  A
  /// shimmer-style accent (pulsing circle + grey bar) communicates
  /// the loading state without resorting to a spinner, which would
  /// clash with the rest of the hub's calm typography.
  Widget _buildLoading(ThemeData theme) {
    final scheme = theme.colorScheme;
    final t = theme.moonrelay.tokens;
    return HubPageBody(
      children: [
        HubSettingsSection(
          title: '',
          children: [
            Padding(
              padding: EdgeInsets.all(t.spaceLg),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: t.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerLine(scheme, t, height: 16, width: 180),
                        SizedBox(height: t.spaceSm),
                        _shimmerLine(scheme, t, height: 12, width: 240),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Renders a single rounded grey "shimmer" line used to suggest
  /// placeholder text.  Kept static-feeling (no animation) so it
  /// does not fight the rest of the hub's motion budget.
  ///
  /// [tokens] is passed in because this helper has no `BuildContext` of its
  /// own, and looking one up here would have meant either a context
  /// parameter on a private helper or, worse, reaching for the extension
  /// from a `Theme.of` call that a reader would mistake for the enclosing
  /// widget's theme.
  Widget _shimmerLine(
    ColorScheme scheme,
    MoonrelayDesignTokens tokens, {
    required double height,
    required double width,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
    );
  }
}
