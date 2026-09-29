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

import 'dart:async';

import 'package:moonrelay/src/layouts/app_frame.dart';
import 'package:moonrelay/src/layouts/dashboard_layout.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/layouts/mobile_layout.dart';
import 'package:moonrelay/src/layouts/startscreen_frame.dart';
import 'package:moonrelay/src/screens/register_page_inclient.dart';
import 'package:moonrelay/src/screens/startup_home_frame.dart';
import 'package:moonrelay/src/screens/login_page.dart';
import 'package:moonrelay/src/screens/add_room_from_id.dart';
import 'package:moonrelay/src/screens/room_details_page.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:moonrelay/src/screens/room_settings/room_settings_page.dart';
import 'package:moonrelay/src/screens/space_home_page.dart';
import 'package:moonrelay/src/screens/space_settings_page.dart';
import 'package:moonrelay/src/screens/startup_screen.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/profile_view.dart';
import 'package:moonrelay/src/widgets/room_resolver.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/screens/encryption/device_list_screen.dart';

/// The application's route table.
///
/// Every route uses `builder:` rather than `pageBuilder:`. `pageBuilder`
/// hands back a [Page], which buys per-route transitions and
/// `NoTransitionPage`, but in practice it was only ever used to funnel every
/// widget through `genericPageBuilder`, and that put three things in the
/// router that did not belong there: the user's animation preference, a
/// hand-rolled fade, and a mid-build call to `LayoutShellController.update`.
/// Transitions are now a theme concern
/// (`MoonrelayPageTransitionsBuilder`), so routes only describe what they
/// render.
///
/// It also means route widgets are ordinary widgets again. The old
/// `RoomDelegate` / `ProfileDelegate` wrappers existed to do work a
/// `builder:` closure can do inline; see [RoomResolver] and [ProfileView].
class MoonRouter {
  MoonRouter();

  /// Returns `true` when the active account has a valid Matrix session.
  static bool _isLoggedIn(BuildContext context) {
    try {
      final client = Provider.of<Client>(context, listen: false);
      return client.isLogged();
    } catch (_) {
      // Not in the tree yet, which during boot means no session either.
      return false;
    }
  }

  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) {
    return _isLoggedIn(context) ? '/main/rooms' : null;
  }

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) {
    return _isLoggedIn(context) ? null : '/welcome';
  }

  // -- Route param helpers ----------------------------------------------

  /// Reads a path parameter, or an empty string when it is absent.
  ///
  /// GoRouter has already percent-decoded matched segments by the time they
  /// reach [GoRouterState.pathParameters], so this deliberately does *not*
  /// decode again. Decoding twice is not a no-op: a user ID containing a
  /// literal `%` (which is legal in a Matrix localpart) would throw a
  /// [FormatException] on the second pass. The old router decoded in some
  /// places and not others, which is how a `redirect` came to compare a
  /// decoded value while the neighbouring `builder` passed an undecoded one.
  static String _param(GoRouterState state, String name) {
    return state.pathParameters[name] ?? '';
  }

  /// Resolves a space room from the `:spaceid` parameter, or null.
  static Room? _spaceFromState(BuildContext context, GoRouterState state) {
    final spaceId = _param(state, 'spaceid');
    if (spaceId.isEmpty) return null;
    return Provider.of<Client>(context, listen: false).getRoomById(spaceId);
  }

  /// Resolves a room from the `:roomid` parameter, or null when the room is
  /// not in the sync cache yet (e.g. a cold deep link to a room that has not
  /// been synced). Callers render a not-found page instead of throwing.
  static Room? _roomFromState(BuildContext context, GoRouterState state) {
    final roomId = _param(state, 'roomid');
    if (roomId.isEmpty) return null;
    return Provider.of<Client>(context, listen: false).getRoomById(roomId);
  }

  /// A not-found page for a room or space that could not be resolved.
  static Widget _notFound(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.search_off,
      title: l10n?.error ?? 'Error',
      message: l10n?.roomNotFound ?? 'Room not found',
    );
  }

  // -- Routes ------------------------------------------------------------

  static final List<RouteBase> routes = [
    ShellRoute(
      builder: (context, state, child) => StartscreenFrame(child: child),
      routes: [
        ShellRoute(
          builder: (context, state, child) => StartupHomeFrame(child: child),
          redirect: loggedInRedirect,
          routes: [
            GoRoute(
              path: '/welcome',
              builder: (context, state) => const StartupScreen(),
              routes: [
                GoRoute(
                  path: 'login',
                  builder: (context, state) => const LoginPage(),
                ),
                GoRoute(
                  path: 'register',
                  builder: (context, state) => const RegisterInClientPage(),
                ),
              ],
            ),
          ],
        ),
        // Unauthenticated route for adding a new account while another is
        // already active.  Bypasses the loggedInRedirect on the welcome
        // shell by living outside that shell route hierarchy.  Also guards
        // against being navigated to while logged out (e.g. a stale link
        // resolved before logout completed) by redirecting to /welcome so
        // the user is never stranded on a bare LoginPage without its frame.
        GoRoute(
          path: '/add-account',
          redirect: loggedOutRedirect,
          builder: (context, state) => const LoginPage(),
        ),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => AppFrame(child: child),
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) =>
              _isLoggedIn(context) ? '/main/rooms' : '/welcome',
        ),
        ShellRoute(
          builder: (context, state, child) => _AdaptiveMainLayout(child: child),
          routes: [
            GoRoute(
              path: '/main/rooms',
              redirect: loggedOutRedirect,
              builder: (context, state) => const RoomsListRoute(),
              routes: [
                GoRoute(
                  path: ':roomid',
                  redirect: loggedOutRedirect,
                  builder: (context, state) => RoomResolver(
                    roomId: _param(state, 'roomid'),
                    threadRootEventId: state.uri.queryParameters['threadRoot'],
                  ),
                  routes: [
                    GoRoute(
                      path: 'profile',
                      builder: (context, state) => ProfileView(
                        userId: _param(state, 'userid'),
                      ),
                      routes: [
                        // IMPORTANT: literal paths must come before
                        // parameterized ones so GoRouter matches them
                        // first (e.g. "roomDetails" must precede :userid).
                        GoRoute(
                          path: 'roomDetails',
                          builder: (context, state) {
                            final room = _roomFromState(context, state);
                            if (room == null) return _notFound(context);
                            return RoomInformations(room: room);
                          },
                        ),
                        GoRoute(
                          path: ':userid',
                          redirect: (context, state) {
                            final userid = _param(state, 'userid');
                            if (userid.isEmpty) return '/main/rooms';
                            // Own profile has its own route so the existing
                            // self-profile flow keeps working.
                            try {
                              final client =
                                  Provider.of<Client>(context, listen: false);
                              if (userid == client.userID) {
                                return '/main/myprofile';
                              }
                            } catch (_) {
                              // No session in the tree: fall through and
                              // let the profile view report the failure.
                            }
                            // Profile viewing is decoupled from the
                            // room route; redirect any deep link with
                            // the form /main/rooms/.../profile/<userid>
                            // to the top-level /profile/<userid> so it
                            // works even when the user isn't joined to
                            // the originating room. The value arrives
                            // decoded, so it has to be re-encoded to go
                            // back into a path segment.
                            return '/profile/${Uri.encodeComponent(userid)}';
                          },
                          builder: (context, state) =>
                              ProfileView(userId: _param(state, 'userid')),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'thread/:threadRootId',
                      builder: (context, state) {
                        final room = _roomFromState(context, state);
                        if (room == null) return _notFound(context);
                        return ThreadViewPage(
                          room: room,
                          threadRootEventId: _param(state, 'threadRootId'),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'settings',
                      builder: (context, state) {
                        final room = _roomFromState(context, state);
                        if (room == null) return _notFound(context);
                        return RoomSettingsPage(room: room);
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/main/myprofile',
              builder: (context, state) => ProfileView(
                userId: _ownUserId(context),
              ),
            ),
            // Stand-alone profile route.  Decoupled from the room tree
            // so opening a user profile from a matrix link, deep link,
            // command palette, or inline mention doesn't require the
            // user to be inside a particular room.  When the userid is
            // the active account we redirect to `/main/myprofile` so
            // the existing self-profile flow keeps working.
            GoRoute(
              path: '/profile/:userid',
              redirect: (context, state) {
                final userid = _param(state, 'userid');
                if (userid.isEmpty) return null;
                try {
                  final client = Provider.of<Client>(context, listen: false);
                  if (userid == client.userID) {
                    return '/main/myprofile';
                  }
                } catch (_) {
                  // No session in the tree; let the view report it.
                }
                return null;
              },
              builder: (context, state) =>
                  ProfileView(userId: _param(state, 'userid')),
            ),
            // Hub screen: opened exclusively as a modal overlay
            // (see [showHubOverlay] in `hub_screen.dart`).  It is
            // *not* registered as a GoRouter route because the
            // hub-as-full-page behaviour used to replace the room
            // page in the navigator stack.  Going through the
            // overlay preserves the chat underneath.
            //
            // The `/hub/...` deep-link paths still exist in code
            // (e.g. command palette `>`-mode entries) but are now
            // intercepted and routed through the overlay instead
            // of the GoRouter.
            GoRoute(
              path: '/main/encryption',
              builder: (context, state) => const EncryptionOverviewScreen(),
            ),
            GoRoute(
              path: '/main/devices',
              builder: (context, state) => const DeviceListScreen(),
            ),
            GoRoute(
              path: '/main/space/:spaceid',
              redirect: loggedOutRedirect,
              builder: (context, state) {
                final space = _spaceFromState(context, state);
                if (space == null) return _notFound(context);
                return SpaceHomePage(space: space);
              },
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) {
                    final space = _spaceFromState(context, state);
                    if (space == null) return _notFound(context);
                    return SpaceSettingsPage(space: space);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/main/room_preview/:roomid',
              redirect: loggedOutRedirect,
              builder: (context, state) => RoomPreviewScreen(
                roomId: _param(state, 'roomid'),
              ),
            ),
            GoRoute(
              path: '/main/addroom',
              builder: (context, state) => const AddRoomPage(),
            ),
          ],
        ),
      ],
    ),
  ];

  /// The signed-in account's own user ID, or an empty string when there is
  /// no session yet.
  ///
  /// `/main/myprofile` exists precisely to mean "my profile", so it resolves
  /// the ID here instead of handing a null down to a widget that had to
  /// guess whether null meant "use mine" or "this is broken".
  static String _ownUserId(BuildContext context) {
    try {
      return Provider.of<Client>(context, listen: false).userID ?? '';
    } catch (_) {
      return '';
    }
  }
}

/// The content behind `/main/rooms` when no room is selected.
///
/// This page is always on the stack: when a room *is* open, the `:roomid`
/// page sits on top of it, so what renders here only matters when the user
/// has backed out to the room list. On mobile that is a full page; on the
/// dashboard it is the main pane beside the room sidebar, where the old
/// code rendered a `RoomDelegate` with a null room ID and produced a
/// "Room not found" error card.
///
/// Deliberately reads no room ID: the child route owns that, and this page
/// reaching into the matched child parameters is how the two used to
/// disagree about which shell was showing.
class RoomsListRoute extends StatelessWidget {
  const RoomsListRoute({super.key});

  @override
  Widget build(BuildContext context) {
    // Reads the shell resolved by _AdaptiveMainLayout earlier in this same
    // build pass: it is an ancestor, so its decision is already committed.
    // A descendant reading a resolved value needs no listener.
    final shell = context.read<LayoutShellController>();
    if (shell.isMobile) return const MobileRoomsListPage();
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.forum_outlined,
      title: l10n?.noRoomSelected ?? 'No room selected',
      message: l10n?.noRoomSelectedHint ??
          'Pick a room from the sidebar to start reading or chatting.',
    );
  }
}

/// Selects between the multi-pane [DashboardLayout] and the single-pane
/// [MobileLayout] for the main chat surface.
///
/// Both layouts live inside the same [ShellRoute] so they share the
/// `/main/rooms` route tree; the only difference is how the route's
/// `child` is wrapped.
///
/// The shell decision itself belongs to [LayoutShellController], which every
/// layout consumer reads, so the frame and the route pages cannot disagree.
/// This widget renders the committed shell and nothing else. It does *not*
/// mutate the controller during build: committing from `build` forced
/// `notifyListeners` to be deferred to a post-frame callback, which in turn
/// made it look safe to also drive navigation from the same place. The
/// commit happens in [didChangeDependencies], which is outside the build
/// pass, so a shell flip now rebuilds the layout and leaves the route stack
/// exactly as it was.
class _AdaptiveMainLayout extends StatefulWidget {
  const _AdaptiveMainLayout({required this.child});

  final Widget child;

  @override
  State<_AdaptiveMainLayout> createState() => _AdaptiveMainLayoutState();
}

class _AdaptiveMainLayoutState extends State<_AdaptiveMainLayout> {
  /// The controller whose `layoutMode` drives the shell, held so a
  /// settings change can re-resolve without rebuilding this widget.
  SettingsController? _settings;

  /// Latest window width, refreshed on every resize. Kept as a field so
  /// the settings listener does not have to read MediaQuery outside the
  /// dependency phase.
  double _width = 0;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the shell from scratch whenever the main chat surface
    // mounts (e.g. after a fresh login): the window may have been
    // resized while the dashboard was unmounted, so the committed shell
    // should be re-derived from the current width instead of inheriting
    // a stale one from the previous session.
    context.read<LayoutShellController>().reset();
    _settings = context.read<SettingsController>()..addListener(_onSettings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `MediaQuery.sizeOf` is the resize dependency. Reading the width here
    // rather than in build is what lets the shell decision happen exactly
    // once per frame, before any descendant reads it.
    _width = MediaQuery.sizeOf(context).width;
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettings);
    super.dispose();
  }

  /// Re-renders after a settings change so a forced layout mode takes
  /// effect. Cheap and idempotent: [LayoutShellController.resolve] only
  /// commits when the target actually differs past the dead band, so an
  /// unrelated preference change cannot move the shell.
  void _onSettings() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();

    // The one and only writer. Every consumer of the shell is a descendant
    // of this widget, so they all read this frame's decision below without
    // needing a notification.
    final shell = context.read<LayoutShellController>()
      ..resolve(rawWidth: _width, layoutMode: settings.layoutMode);

    if (shell.isMobile) {
      return MobileLayout(child: widget.child);
    }
    return DashboardLayout(child: widget.child);
  }
}
