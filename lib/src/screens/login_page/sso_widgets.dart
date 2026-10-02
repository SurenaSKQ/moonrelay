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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/form_field_label.dart';

/// The SSO section's read-only display of where the browser was sent.
///
/// Shown in the automatic flow while the callback is pending, and kept in
/// the manual fallback so a user whose automatic attempt failed can copy
/// the same URL and retry it in another window.
class SsoUrlDisplay extends StatelessWidget {
  const SsoUrlDisplay({super.key, required this.url});

  /// The destination to show, or null before the flow has produced one.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildFormFieldLabel(context, l10n.ssoUrlLabel),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Text(
            url ?? l10n.ssoStartingHint,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The "waiting for the browser" notice, shown while the local callback
/// server is waiting for the redirect.
class SsoAwaitingBanner extends StatelessWidget {
  const SsoAwaitingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(t.radiusLg),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.ssoWaitingForBrowser,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The notice explaining that the automatic flow stopped and the rest has to
/// be finished by hand.
///
/// This was previously rendered inside the awaiting banner, which is only
/// built while the callback is still pending, and every path that raised
/// the failure also cleared the pending flag. The message could therefore
/// never appear.
class SsoFailureNotice extends StatelessWidget {
  const SsoFailureNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        l10n.ssoAutomaticFailed,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The action button that abandons the automatic flow for the manual
/// fallback.
class SsoSwitchToManualButton extends StatelessWidget {
  const SsoSwitchToManualButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.arrowLeft, size: 18),
      label: Text(l10n.ssoSwitchToManual),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusLg),
        ),
      ),
    );
  }
}
