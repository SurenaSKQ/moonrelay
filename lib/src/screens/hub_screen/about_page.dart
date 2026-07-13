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

// ─────────────────────────────────────────────────────────────────────────────
// About Page
// ─────────────────────────────────────────────────────────────────────────────

/// A page in the hub showing app information, version, and support links.
class HubAboutPage extends StatelessWidget {
  const HubAboutPage({super.key, required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App identity card ─────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.moon,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.projectName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.aboutVersion(AppVersion.currentVersion),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.appLicenseNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Repository ───────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.gitBranch,
                          size: 20, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        l10n.aboutRepository,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.aboutRepositoryDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'https://github.com/SurenaSKQ/moonrelay/',
                          style: TextStyle(
                            color: colors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(
                                  Uri.parse(
                                    'https://github.com/SurenaSKQ/moonrelay/',
                                  ),
                                  mode: LaunchMode.externalApplication,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Moonrelay Support ────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.lifeBuoy,
                          size: 20, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        l10n.aboutSupport,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.aboutSupportDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _joinSupportSpace(context),
                      icon: const Icon(LucideIcons.messageSquare, size: 18),
                      label: Text(l10n.aboutJoinSupportSpace),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

    // Not joined  try to join first, then navigate.
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
