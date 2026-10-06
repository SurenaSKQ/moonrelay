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
import 'package:moonrelay/src/widgets/auth_surface.dart';

/// The SSO section's read-only display of where the browser was sent.
///
/// Shown in the automatic flow while the callback is pending, and kept in the
/// manual fallback so a user whose automatic attempt failed can copy the same
/// URL and retry it in another window.
///
/// It is a well rather than a field, so it reads as output. It used to be a
/// full `surfaceContainerHighest` block with no border, sitting directly under
/// the homeserver input, and the two were hard to tell apart: one is something
/// you type, the other is something you copy.
class SsoUrlDisplay extends StatelessWidget {
  const SsoUrlDisplay({super.key, required this.url});

  /// The destination to show, or null before the flow has produced one.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        // `surfaceContainerHighest` with no alpha over it, rather than the same
        // colour at 30%. On the dark ramp this colour is already the composer's
        // step, so at full strength a read-only URL reads as the input it is
        // not, and at 30% over the card it reads as a wash.
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: ext.layers.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.spaceMd),
        child: Text(
          url ?? l10n.ssoStartingHint,
          style: TextStyle(
            // The app's mono family, not a hardcoded 'SpaceMono'. That
            // family is bundled and declared, but nothing reads it from one
            // place, so a user who changed the mono family in settings
            // would still get SpaceMono here and nowhere else.
            fontFamily: ext.monoFontFamily,
            fontSize: 12,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The "waiting for the browser" notice, shown while the local callback
/// server is waiting for the redirect.
///
/// It is an [AuthNotice] in the pending tone, because it is the same kind of
/// thing as the sign-in form's failure banner: something the user must read
/// before they can decide what to do next. It had its own container with its
/// own 30%-alpha accent fill and its own radius.
class SsoAwaitingBanner extends StatelessWidget {
  const SsoAwaitingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(top: t.spaceSm),
      child: AuthNotice(
        message: l10n.ssoWaitingForBrowser,
        tone: AuthNoticeTone.pending,
        busy: true,
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.spaceSm),
      child: Text(
        l10n.ssoAutomaticFailed,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: Theme.of(context).colorScheme.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The action button that abandons the automatic flow for the manual
/// fallback.
///
/// An [AuthButton] like every other button in the form. It was the only one of
/// the seven in the login page that used `t.radiusLg` while the rest used a
/// literal 12 or `t.radiusMd`, so the four buttons a user can see at once had
/// three different corner radii.
class SsoSwitchToManualButton extends StatelessWidget {
  const SsoSwitchToManualButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AuthButton(
      label: l10n.ssoSwitchToManual,
      icon: LucideIcons.arrowLeft,
      filled: false,
      onPressed: onPressed,
    );
  }
}
