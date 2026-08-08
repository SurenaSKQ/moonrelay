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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/encryption/incoming_verification_listener.dart';
import 'package:moonrelay/src/widgets/encryption/post_login_setup_checker.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';

/// Single-pane layout shell used for very narrow windows and for users
/// who opt into the [LayoutMode.mobile] experience.
///
/// Unlike [DashboardLayout]  which keeps the chat and the sidebar
/// side by side  the mobile layout only ever renders one of them at a
/// time and relies on the route stack to switch between them.  When the
/// user is at `/main/rooms` the room list is the page; tapping a room
/// pushes `/main/rooms/<id>` onto the stack and the chat fills the
/// screen with a back button.  This is the same mental model that the
/// rest of the app already uses for deep links and matrix.to URLs, so
/// mobile mode does not require any new routing primitives  the same
/// [ShellRoute] tree works, only the surrounding frame changes.
///
/// The mobile shell intentionally renders no left sidebar at all: the
/// navigation sidebar that [DashboardLayout] shows would consume too
/// much horizontal real estate on a phone-sized viewport and would
/// crowd the chat composer.
class MobileLayout extends StatelessWidget {
  /// The route's content widget.
  final Widget child;

  const MobileLayout({super.key, required this.child});

  /// True if the current route refers to a specific room (i.e. the
  /// chat should be rendered, not the rooms list).
  static bool isRoomRoute(BuildContext context) {
    final state = GoRouterState.of(context);
    return state.pathParameters.containsKey('roomid') &&
        (state.pathParameters['roomid'] ?? '').isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // On the rooms list route, expose a search/title header that fits
    // the mobile chrome.  On the chat route, prepend an automatic back
    // button so the user can return to the list without a hardware key.
    return Column(
      children: [
        _MobileTopBar(l10n: l10n),
        Expanded(
          child: PostLoginSetupChecker(
            child: IncomingVerificationListener(child: child),
          ),
        ),
      ],
    );
  }
}

/// Top bar shown above the mobile layout's content.
///
/// On the rooms list route it shows the title and a search affordance;
/// on a chat route it shows a back button that pops back to the list.
/// The bar is intentionally minimal so the chat area has as much vertical
/// space as possible.
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final inRoom = MobileLayout.isRoomRoute(context);
    final theme = Theme.of(context);

    return Container(
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          if (inRoom)
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              tooltip: l10n.back,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/main/rooms');
                }
              },
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              inRoom ? '' : l10n.appTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A stand-alone, single-pane list of rooms used as the landing page
/// of the mobile layout.
///
/// Mirrors what the navigation sidebar's rooms region would normally
/// render inside the dashboard, but without any sibling panes.  Tapping
/// a row pushes the chat route so the navigator stack reflects the
/// user's location.
class MobileRoomsListPage extends StatelessWidget {
  const MobileRoomsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoomsPane();
  }
}
