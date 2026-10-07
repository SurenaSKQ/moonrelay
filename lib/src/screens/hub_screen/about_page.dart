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
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:moonrelay/src/helpers/app_version.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

// About Page

/// What this is, where it lives, and where to ask.
///
/// The page with the most prose in the hub, and the one that most needed the
/// measure: a paragraph set to the full width of the content pane is the one
/// thing prose cannot do, because the eye loses the start of the next line
/// having not finished the last.
///
/// Its three blocks were `Card`s outlined in `theme.dividerColor`, which is
/// the app's second grey, and their padding was a literal 32 or 20 depending
/// on the card. They are [InfoPanel]s on the one hairline with the padding
/// from the token scale, which is what the room and space pages have used
/// since before the hub existed.
class HubAboutPage extends StatelessWidget {
  const HubAboutPage({super.key, required this.client});

  final Client client;

  /// The project's own repository. One place, because a URL written twice is a
  /// URL that is correct in one of them.
  static const String repositoryUrl = 'https://github.com/SurenaSKQ/moonrelay/';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = theme.moonrelay.tokens;

    return HubPageBody(
      children: [
        // -- App identity ---------------------------------------------
        InfoPanel(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceXl,
            vertical: t.spaceXl,
          ),
          children: [
            _AboutBlock(
              children: [
                Icon(LucideIcons.moon, size: 64, color: colors.primary),
                SizedBox(height: t.spaceLg),
                Text(
                  l10n.projectName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                SizedBox(height: t.spaceXs),
                Text(
                  l10n.aboutVersion(AppVersion.currentVersion),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: t.spaceMd),
                Text(
                  l10n.appLicenseNotice,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),

        // -- Repository -------------------------------------------------
        InfoPanel(
          title: l10n.aboutRepository,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spaceLg,
                t.spaceXs,
                t.spaceLg,
                t.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutRepositoryDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: t.spaceSm),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: repositoryUrl,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(
                                  Uri.parse(repositoryUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                          style: TextStyle(
                            color: colors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // -- Support -----------------------------------------------------
        InfoPanel(
          title: l10n.aboutSupport,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spaceLg,
                t.spaceXs,
                t.spaceLg,
                t.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutSupportDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: t.spaceLg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _joinSupportSpace(context),
                      icon: Icon(LucideIcons.messageSquare, size: 18),
                      label: Text(l10n.aboutJoinSupportSpace),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radiusMd),
                        ),
                      ),
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

  Future<void> _joinSupportSpace(BuildContext context) async {
    const spaceId = '!MFpGwhVEUITDRfTYrE:matrix.org';
    final log = context.read<Logger>();
    final scaffold = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Check if we're already in the space.
    final existing = client.getRoomById(spaceId);
    if (existing != null) {
      if (!context.mounted) return;
      context.go('/main/space/${Uri.encodeComponent(spaceId)}');
      return;
    }

    // Not joined; try to join first, then navigate.
    try {
      await client.joinRoom(spaceId);
      if (!context.mounted) return;
      context.go('/main/space/${Uri.encodeComponent(spaceId)}');
    } catch (e) {
      log.i('Could not join support space: $e');

      // Fallback: open matrix.to URL in browser.
      if (!context.mounted) return;
      final uri = Uri.parse(
        'https://matrix.to/#/$spaceId',
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.error),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Centres and stacks the contents of an [InfoPanel] that is one block rather
/// than a list of rows.
///
/// `InfoPanel` is a list of rows with a hairline between them, and the app's
/// mark is not a row. This is the one thing it needed and did not have.
class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
