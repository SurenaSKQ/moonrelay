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
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

/// What the app does with your data, in prose.
///
/// The chrome is now the app's: the standard page shell, the standard 680
/// measure, `InfoPanel` for each section, and the summary as a notice. It was
/// seven Material `Card`s with the default shape, 20px of padding on each, a
/// 22px accent glyph beside every heading, and a measure of its own.
///
/// **The body prose is still English, and that is deliberate.** A privacy policy
/// is a document somebody has read and agreed to. A machine translation of one
/// is not an improvement on an English one, it is a different and unreviewed
/// document wearing the same heading, and this file is the one place in the app
/// where shipping unreviewed prose to a user would be actively harmful. It is a
/// translation task for the project owner.
///
/// The `'Last updated: June 2025'` line was hardcoded and had been wrong for
/// two majors. It is a key now, and its value is whatever the owner last sets.
class PrivacyPolicyPopupScreen extends StatelessWidget {
  const PrivacyPolicyPopupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MoonrelayInfoPage(
      title: l10n.privacyPolicy,
      children: <Widget>[
        // A neutral notice rather than the summary card it was. The old one was
        // `secondaryContainer` at 20px padding with a 28px glyph, and the
        // paragraph inside it was the only thing on the page set at 15pt: the
        // summary of a privacy policy was the loudest text in it.
        //
        // `StatusCard` was the obvious substitute and is wrong here: it sets its
        // whole label at w600, which is right for "End-to-end encrypted" and not
        // for a paragraph of prose.
        AuthNotice(
          message: l10n.privacyPolicyText,
          icon: LucideIcons.shield,
          tone: AuthNoticeTone.neutral,
        ),
        const InfoSectionGap(first: true),
        _Section(
          icon: LucideIcons.info,
          title: 'Introduction',
          children: [
            'Moonrelay is a Matrix chat client built with a '
                'strong commitment to user privacy and data minimisation. '
                'This policy describes how the application handles your '
                'information when you use it to communicate over the '
                'Matrix network.',
            'Moonrelay itself does not operate any servers. '
                'All communication flows through Matrix homeservers that '
                'you or your organisation choose.  Those servers are '
                'governed by their own privacy policies.',
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          icon: LucideIcons.database,
          title: 'What Information We Access',
          children: [
            'Moonrelay stores locally on your device:',
            '• Your Matrix account credentials (access tokens)\n'
                '• Room history and message content you have received\n'
                '• User profiles, avatars, and display names\n'
                '• Encryption keys for end-to-end encrypted rooms\n'
                '• Application preferences (theme, layout, notification '
                'settings)',
            'No data is transmitted to us or any third party beyond '
                'what is required for the Matrix protocol to function. '
                'The application does not include telemetry, analytics, '
                'or crash reporting.',
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          icon: LucideIcons.share2,
          title: 'How Your Data Is Shared',
          children: [
            'When you send a message, upload a file, or update your '
                'profile, that data is sent to the Matrix homeserver you '
                'are connected to.  Depending on the room settings, it '
                'may be further replicated to other homeservers that '
                'participate in the same room.',
            'Moonrelay does not have access to that data.  The '
                'application simply relays your input to the homeserver '
                'you specify at login.',
            'If you join end-to-end encrypted rooms, message content '
                'is encrypted on your device before it leaves, and can '
                'only be decrypted by the intended recipients.  Even the '
                'homeserver cannot read it.',
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          icon: LucideIcons.lock,
          title: 'Data Storage & Security',
          children: [
            'All locally cached data is stored in the application\'s '
                'sandboxed directory on your device.  Encryption keys are '
                'kept in an isolated key store where the platform allows.',
            'You can clear all locally stored data at any time by '
                'logging out or by uninstalling the application.  '
                'Persistent room data held on homeservers must be deleted '
                'through the server\'s own administration tools.',
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          icon: LucideIcons.fileText,
          title: 'Your Rights',
          children: [
            'Under applicable data protection law (including the GDPR '
                'for users in the European Economic Area), you have the '
                'right to:',
            '• Access the personal data the application holds locally\n'
                '• Rectify or erase your locally stored data\n'
                '• Export your data (the local database can be copied '
                'from the application directory)\n'
                '• Lodge a complaint with your local data protection '
                'authority',
            'Because Moonrelay is a client that only stores data '
                'locally, most rights (access, erasure, portability) can '
                'be exercised directly within the application or by '
                'uninstalling it.',
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          icon: LucideIcons.code2,
          title: 'Open Source',
          children: [
            'Moonrelay is free and open-source software released under '
                'the GNU Affero General Public License v3 or later.  You '
                'can inspect, audit, and modify the source code at any '
                'time.  The complete source is available at the '
                'project\'s repository.',
            'We encourage security researchers and privacy advocates '
                'to review the code and report any concerns.',
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          icon: LucideIcons.mail,
          title: 'Contact',
          children: [
            'If you have questions about this privacy policy or the '
                'application\'s data practices, please open an issue on '
                'the project repository or contact the maintainer '
                'directly via the Matrix network.',
          ],
        ),
        const SizedBox(height: 32),

        const InfoSectionGap(),
        // The date this policy was last revised. A key rather than a literal,
        // because a hardcoded one that nobody updates is worse than none: it is a
        // claim about the document that quietly stops being true.
        Center(
          child: Text(
            l10n.privacyPolicyLastUpdated,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One titled section of the policy.
///
/// An `InfoPanel` with its glyph dropped: the app's own panels have a plain
/// title, and an accent-coloured icon on each of seven headings made this page
/// read as a table of contents with a lot of shouting in it.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  /// Kept so the seven call sites still say what the icon used to be, and so a
  /// future edit that wants it back knows the name. Not drawn: an
  /// accent-coloured glyph on every heading made this page read as a table of
  /// contents with a lot of shouting in it.
  final IconData icon;
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      title: title,
      children: <Widget>[
        for (final String paragraph in children) AuthBody(paragraph),
      ],
    );
  }
}
