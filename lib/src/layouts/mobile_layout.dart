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
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/encryption/incoming_verification_listener.dart';
import 'package:moonrelay/src/widgets/encryption/post_login_setup_checker.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/screens/room_page.dart';

/// Single-pane layout shell used for very narrow windows and for users
/// who opt into the [LayoutMode.mobile] experience.
///
/// This is a focus mode rather than a phone mode: the same shell serves a
/// 400px window on a phone and a user who asked for one conversation at a
/// time on a 1600px desktop. That framing is why it carries its own
/// navigation. The dashboard can put a sidebar beside the chat; a
/// single-pane shell has no such luxury, so if the bar and the chrome were
/// not here the destinations would simply be unreachable.
///
/// It renders three things, and which of them appear is derived from the
/// route:
///
///   * a top bar, on the routes the shell decorates. Every other route
///     supplies an `AppBar` of its own, so stacking one on top produced a
///     doubled header and a second, competing back arrow.
///   * the route content, always. A route the shell does not decorate is
///     not a route the shell refuses to render.
///   * a bottom navigation bar, on the top-level destinations only. A
///     conversation is not a tab, so the bar is hidden inside a room and
///     the chat gets the full height.
class MobileLayout extends StatelessWidget {
  /// The route's content widget.
  final Widget child;

  const MobileLayout({super.key, required this.child});

  /// True if the current route is the room chat page.
  ///
  /// Matches the declared route pattern exactly rather than testing for
  /// the presence of a `roomid` parameter. The parameter test was true for
  /// every child of the room route too, so `RoomSettingsPage`,
  /// `ThreadViewPage` and `RoomInformations` each got a second back arrow
  /// from the shell stacked above the one their own `AppBar` already
  /// renders, and `/main/room_preview/:roomid` was misread as a room.
  static bool isRoomRoute(BuildContext context) =>
      isRoomChatLocation(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final FocusDestination? destination = focusDestinationOf(context);
    final double width = MediaQuery.sizeOf(context).width;

    // Provided here because the dashboard provides it too, and a descendant
    // that measures itself falls back to `_RootLayoutScope` without one,
    // which reports `availableWidth: double.infinity` and a hard-coded
    // `LayoutSize.expanded`. That is not a harmless default: it is what
    // made the in-room search panel render at a fixed 320px beside a ~180px
    // timeline in this shell, because its compact branch could never fire.
    // Window width rather than the inner constraints, so mounting and
    // unmounting the bar above does not change what the content believes
    // about its own width.
    final LayoutSize size = LayoutBreakpoints.sizeForWidth(width);

    return LayoutScope(
      size: size,
      availableWidth: width,
      child: Column(
        children: [
          if (isShellDestination(context)) _MobileTopBar(l10n: l10n),
          Expanded(
            // The shortcut listener is mounted here as well as in the
            // dashboard. It was dashboard-only, which meant a desktop user
            // who opted into this shell lost the command palette they had
            // just used to get here.
            child: GlobalShortcutListener(
              child: PostLoginSetupChecker(
                child: IncomingVerificationListener(child: child),
              ),
            ),
          ),
          if (destination != null)
            _MobileNavigationBar(destination: destination),
        ],
      ),
    );
  }
}

/// Identifies the shell's top bar, so a widget test can assert on the bar
/// itself rather than on text that also appears in the navigation bar
/// directly below it. The two intentionally share their labels.
const Key kMobileShellTopBar = Key('mobileShellTopBar');

/// Identifies the shell's bottom navigation bar.
const Key kMobileShellNavigationBar = Key('mobileShellNavigationBar');

/// Top bar shown above the single-pane shell's content.
///
/// On the room chat it supplies a back button, because [RoomPage] renders
/// its timeline directly into a `Scaffold` body and has no `AppBar` of its
/// own. On a top-level destination it shows that destination's title, and
/// carries the two actions the dashboard puts in its sidebar header: search
/// and the profile. Those two were the gap this shell had. The dashboard
/// reaches them through `SidebarProfilePill` and
/// `SidebarCommandPaletteButton`, both of which live in a sidebar this
/// shell does not mount, so global search and the user's own profile were
/// unreachable here and there was no way to reach settings, accounts,
/// devices, logs or logout at all.
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final inRoom = MobileLayout.isRoomRoute(context);
    final destination = focusDestinationOf(context);
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;

    // On a destination the bar names the destination rather than the app:
    // the navigation bar directly below already says where you are, and a
    // second "Moonrelay" above it is noise. In a room the room's own header
    // supplies the name, so the shell leaves the space alone.
    final String title = switch (destination) {
      FocusDestination.chats => l10n.chats,
      FocusDestination.spaces => l10n.spaces,
      FocusDestination.search => l10n.search,
      FocusDestination.you => l10n.myProfile,
      null => '',
    };

    return Container(
      key: kMobileShellTopBar,
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: t.opacityDisabled,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          if (inRoom)
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              tooltip: l10n.back,
              // [backToRoomList] rather than a local canPop check: the room
              // list is reached with `push` in this shell, so the pop is a
              // real history step and the list keeps its scroll position
              // and any search text on it. The `go` branch only fires on a
              // cold deep link, where there is genuinely nothing to pop.
              //
              // This lands on the list, not on the previously opened room.
              // That is not a property of this button; it is a property of
              // [openRoom], which replaces rather than pushes when the
              // user is already inside a room, so the stack under a
              // conversation is the list and nothing else. Without that,
              // Back here is strictly a navigator's Back and it walks the
              // user backwards through rooms they have already read.
              onPressed: () => backToRoomList(context),
            )
          else
            SizedBox(width: t.spaceSm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (destination == FocusDestination.search)
            // The page is a search field already, so a bar button that
            // opens the same thing would be noise. Trailing padding keeps
            // the title off the edge, which the button otherwise provided.
            SizedBox(width: t.spaceSm)
          else
            IconButton(
              icon: const Icon(LucideIcons.search, size: 18),
              tooltip: l10n.search,
              onPressed: () => context.go(FocusDestination.search.path),
            ),
        ],
      ),
    );
  }
}

/// Bottom navigation for the single-pane shell's top-level destinations.
///
/// The destinations are routes, so the selected index is read off the
/// matched location rather than held in state. That is the whole reason
/// for making them routes: a bar driven by a second source of truth has to
/// be told when to desync from the URL, and a deep link or a cold start
/// into the middle of one is exactly when it would not be.
///
/// Hidden inside a conversation, where there is nothing to switch between.
class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({required this.destination});

  final FocusDestination destination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NavigationBar(
      key: kMobileShellNavigationBar,
      selectedIndex: destination.index,
      onDestinationSelected: (int index) {
        final FocusDestination target = FocusDestination.values[index];
        if (target == destination) return;
        // `go`, not `push`: a destination switch is a lateral move, not a
        // step the user should be able to walk back through one tab at a
        // time.
        context.go(target.path);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(LucideIcons.messageCircle),
          selectedIcon: const Icon(LucideIcons.messageCircle),
          label: l10n.chats,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.layoutGrid),
          selectedIcon: const Icon(LucideIcons.layoutGrid),
          label: l10n.spaces,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.search),
          selectedIcon: const Icon(LucideIcons.search),
          label: l10n.search,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.user),
          selectedIcon: const Icon(LucideIcons.user),
          label: l10n.you,
        ),
      ],
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
    // Spaces are excluded: [RoomResolver] turns whatever room id lands in
    // the URL into a chat view, so listing a space here opened a space as
    // if it were a room.  The compact shell already routed spaces to
    // /main/space/, which is the route that actually renders them.
    return const RoomsPane(roomFilter: roomIsChat);
  }
}