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

import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/profile_delegate.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
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
import 'package:moonrelay/src/screens/room_settings_page.dart';
import 'package:moonrelay/src/screens/space_home_page.dart';
import 'package:moonrelay/src/screens/space_settings_page.dart';
import 'package:moonrelay/src/screens/startup_screen.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/helpers/room_delegate.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/screens/encryption/device_list_screen.dart';

class MoonRouter {
  /// Returns `true` when the active account has a valid Matrix session.
  static bool _isLoggedIn(BuildContext context) {
    try {
      final client = Provider.of<Client>(context, listen: false);
      return client.isLogged();
    } catch (_) {
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

  MoonRouter();

  /// Resolves a space room from route parameters, or null if not found.
  static Room? _spaceFromState(BuildContext context, GoRouterState state) {
    final spaceId = state.pathParameters['spaceid'];
    if (spaceId == null) return null;
    return Provider.of<Client>(context, listen: false).getRoomById(spaceId);
  }

  /// Resolves a room from the route's :roomid parameter, or null when
  /// the room is not in the sync cache yet (e.g. a cold deep link to a
  /// room that hasn't been synced).  Callers render a not-found page
  /// instead of throwing on a null bang.
  static Room? _roomFromState(BuildContext context, GoRouterState state) {
    final roomId = state.pathParameters['roomid'];
    if (roomId == null) return null;
    return Provider.of<Client>(context, listen: false).getRoomById(roomId);
  }

  /// Builds a "not found" fallback page for missing rooms/spaces.
  static Page _notFoundPage(
    BuildContext context,
    GoRouterState state,
    String label,
  ) =>
      genericPageBuilder(context, state, Center(child: Text(label)));

  // TODO: If the user is on desktop use a frame, if the user is on mobile use mobile layout.
  static final List<RouteBase> routes = [
    ShellRoute(
      pageBuilder: (context, state, child) => genericPageBuilder(
        context,
        state,
        StartscreenFrame(child: child),
      ),
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => genericPageBuilder(
            context,
            state,
            StartupHomeFrame(
              child: child,
            ),
          ),
          redirect: loggedInRedirect,
          routes: [
            GoRoute(
              path: '/welcome',
              pageBuilder: (context, state) =>
                  genericPageBuilder(context, state, StartupScreen()),
              routes: [
                GoRoute(
                  path: 'login',
                  pageBuilder: (context, state) => genericPageBuilder(
                    context,
                    state,
                    const LoginPage(),
                  ),
                ),
                GoRoute(
                  path: 'register',
                  pageBuilder: (context, state) => genericPageBuilder(
                    context,
                    state,
                    const RegisterInClientPage(),
                  ),
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
          pageBuilder: (context, state) => genericPageBuilder(
            context,
            state,
            const LoginPage(),
          ),
        ),
      ],
    ),
    ShellRoute(
      pageBuilder: (context, state, child) => genericPageBuilder(
        context,
        state,
        AppFrame(child: child),
      ),
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) =>
              _isLoggedIn(context) ? '/main/rooms' : '/welcome',
        ),
        ShellRoute(
          pageBuilder: (context, state, child) => genericPageBuilder(
            context,
            state,
            // The DashboardLayout replaces the old TwoColumnLayout.
            // It reads sidebar visibility and pane choice from
            // SettingsController and uses LayoutBuilder for responsive
            // breakpoints. The user profile button is now rendered
            // in the AppFrame header bar.
            //
            // When the user opts into [LayoutMode.mobile] the shell
            // renders the dedicated single-pane [MobileLayout] instead.
            // Mobile mode does not need the navigation sidebar, the
            // multi-pane sidebars, or the resize handles, so it lives
            // outside the dashboard code path entirely.
            _AdaptiveMainLayout(child: child),
          ),
          routes: [
            GoRoute(
              path: '/main/rooms',
              redirect: loggedOutRedirect,
              pageBuilder: (context, state) => _roomsListPageBuilder(
                context,
                state,
              ),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => genericPageBuilder(
                    context,
                    state,
                    RoomDelegate(
                      roomID: state.pathParameters['roomid']!,
                      threadRootEventId:
                          state.uri.queryParameters['threadRoot'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: 'profile',
                      pageBuilder: (context, state) => genericPageBuilder(
                        context,
                        state,
                        ProfileDelegate(
                          userid: state.pathParameters['userid'],
                        ),
                      ),
                      routes: [
                        // IMPORTANT: literal paths must come before
                        // parameterized ones so GoRouter matches them
                        // first (e.g. "roomDetails" must precede :userid).
                        GoRoute(
                          path: 'roomDetails',
                          pageBuilder: (context, state) {
                            final room = _roomFromState(context, state);
                            if (room == null) {
                              return _notFoundPage(
                                  context, state, 'Room not found');
                            }
                            return genericPageBuilder(
                              context,
                              state,
                              RoomInformations(room: room),
                            );
                          },
                        ),
                        GoRoute(
                          path: ':userid',
                          redirect: (context, state) {
                            final raw = state.pathParameters['userid'];
                            if (raw == null) return null;
                            final userid = Uri.decodeComponent(raw);
                            try {
                              final client =
                                  Provider.of<Client>(context, listen: false);
                              if (userid == client.userID) {
                                return '/main/myprofile';
                              }
                            } catch (_) {}
                            // Profile viewing is decoupled from the
                            // room route; redirect any deep link with
                            // the form /main/rooms/.../profile/<userid>
                            // to the top-level /profile/<userid> so it
                            // works even when the user isn't joined to
                            // the originating room.
                            return '/profile/${Uri.encodeComponent(userid)}';
                          },
                          pageBuilder: (context, state) => genericPageBuilder(
                            context,
                            state,
                            ProfileDelegate(
                              userid: Uri.decodeComponent(
                                state.pathParameters['userid'] ?? '',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'thread/:threadRootId',
                      pageBuilder: (context, state) {
                        final room = _roomFromState(context, state);
                        if (room == null) {
                          return _notFoundPage(
                              context, state, 'Room not found');
                        }
                        final threadRootId =
                            state.pathParameters['threadRootId']!;
                        return genericPageBuilder(
                          context,
                          state,
                          ThreadViewPage(
                            room: room,
                            threadRootEventId: threadRootId,
                          ),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'settings',
                      pageBuilder: (context, state) {
                        final room = _roomFromState(context, state);
                        if (room == null) {
                          return _notFoundPage(
                              context, state, 'Room not found');
                        }
                        return genericPageBuilder(
                          context,
                          state,
                          RoomSettingsPage(room: room),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/main/myprofile',
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                ProfileDelegate(
                  userid: null,
                ),
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
                final raw = state.pathParameters['userid'];
                if (raw == null || raw.isEmpty) return null;
                final userid = Uri.decodeComponent(raw);
                try {
                  final client = Provider.of<Client>(context, listen: false);
                  if (userid == client.userID) {
                    return '/main/myprofile';
                  }
                } catch (_) {}
                return null;
              },
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                ProfileDelegate(
                  userid: Uri.decodeComponent(
                    state.pathParameters['userid'] ?? '',
                  ),
                ),
              ),
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
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                const EncryptionOverviewScreen(),
              ),
            ),
            GoRoute(
              path: '/main/devices',
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                const DeviceListScreen(),
              ),
            ),
            GoRoute(
              path: '/main/space/:spaceid',
              pageBuilder: (context, state) {
                final space = _spaceFromState(context, state);
                if (space == null) {
                  return _notFoundPage(context, state, 'Space not found');
                }
                return genericPageBuilder(
                  context,
                  state,
                  SpaceHomePage(space: space),
                );
              },
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'settings',
                  pageBuilder: (context, state) {
                    final space = _spaceFromState(context, state);
                    if (space == null) {
                      return _notFoundPage(context, state, 'Space not found');
                    }
                    return genericPageBuilder(
                      context,
                      state,
                      SpaceSettingsPage(space: space),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/main/room_preview/:roomid',
              pageBuilder: (context, state) {
                final String roomId = state.pathParameters['roomid']!;
                return genericPageBuilder(
                  context,
                  state,
                  RoomPreviewScreen(roomId: roomId),
                );
              },
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: '/main/addroom',
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                const AddRoomPage(),
              ),
            ),
          ],
        )
      ],
    ),
  ];

  static Page genericPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    // Honour the user's animation preference: when motion is enabled
    // we apply a soft fade to keep the navigation feeling responsive,
    // and we collapse back to [NoTransitionPage] when the user has
    // opted out (animations are off, accessibility reduced-motion).
    final motion = Motion.of(context);
    if (!motion.enableAnimations) {
      return NoTransitionPage(
        key: state.pageKey,
        restorationId: state.pageKey.value,
        child: child,
      );
    }
    return CustomTransitionPage(
      key: state.pageKey,
      restorationId: state.pageKey.value,
      transitionDuration: motion.duration(MotionDurations.medium),
      reverseTransitionDuration: motion.duration(MotionDurations.fast),
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Page builder for the `/main/rooms` route (no `:roomid`).
  ///
  /// Returns a [RoomDelegate] (which renders an empty space when the
  /// room ID is absent) for the dashboard layout, or a fully-rendered
  /// [MobileRoomsListPage] when the user is on the mobile layout.
  ///
  /// Both layouts share the same route; the difference is purely in
  /// how the URL `/main/rooms` is presented.  Keeping the URL stable
  /// means the existing deep-link handling, command-palette routing,
  /// and back-button logic continue to work without modification.
  ///
  /// The mobile branch fires when the user has explicitly opted in to
  /// mobile mode *or* the shared [LayoutShellController] committed the
  /// mobile shell because the window is too narrow.  The decision is
  /// read from the controller (never recomputed here) so this page
  /// builder and the surrounding shell always agree in the same frame.
  static Page _roomsListPageBuilder(
    BuildContext context,
    GoRouterState state,
  ) {
    final settings = Provider.of<SettingsController>(context, listen: false);
    final shell = Provider.of<LayoutShellController>(context, listen: false);
    final width = MediaQuery.sizeOf(context).width;
    shell.update(rawWidth: width, layoutMode: settings.layoutMode);

    // The page child depends on the committed shell (mobile vs
    // dashboard).  It must rebuild when the shell flips, so we subscribe
    // to the controller here rather than reading it once: GoRouter only
    // re-runs this builder when the route actually changes, so a shell
    // flip would otherwise leave the previous shell's page (e.g. a
    // MobileRoomsListPage) rendered inside the wrong layout.  Wrapping
    // the child in a [ListenableBuilder] makes the flip rebuild the
    // child on the same frame the shell commits, with no navigation.
    final child = ListenableBuilder(
      listenable: shell,
      builder: (context, _) {
        if (shell.isMobile) {
          return const MobileRoomsListPage();
        }
        return RoomDelegate(
          roomID: state.pathParameters['roomid'],
          threadRootEventId: state.uri.queryParameters['threadRoot'],
        );
      },
    );
    return genericPageBuilder(context, state, child);
  }
}

/// Selects between the multi-pane [DashboardLayout] and the single-pane
/// [MobileLayout] for the main chat surface.
///
/// Both layouts live inside the same [ShellRoute] so they share the
/// `/main/rooms` route tree; the only difference is how the route's
/// `child` is wrapped.  Switching modes at runtime rebuilds this
/// widget but does not change the route stack, so the chat the user
/// was looking at stays open.
///
/// The mobile layout is used when the shared [LayoutShellController]
/// commits the mobile shell: when the user explicitly opted in via
/// [LayoutMode.mobile], or when the current viewport is too narrow for
/// even the unified compact sidebar (below
/// [LayoutBreakpoints.mobileMax]).
///
/// The shell decision is never made here.  [LayoutShellController]
/// owns the width-to-shell mapping (with a sticky dead band) and is
/// read by every layout consumer, so the frame and the route pages
/// cannot disagree.  This widget merely renders the committed shell
/// and nudges navigation when the shell flips.
class _AdaptiveMainLayout extends StatefulWidget {
  const _AdaptiveMainLayout({required this.child});

  final Widget child;

  @override
  State<_AdaptiveMainLayout> createState() => _AdaptiveMainLayoutState();
}

class _AdaptiveMainLayoutState extends State<_AdaptiveMainLayout> {
  /// The shell the previous build chose.  Tracked so we can detect
  /// transitions and force a route navigation to a clean default
  /// page; without it, the dashboard inherits the [MobileRoomsListPage]
  /// (or vice versa) and ends up rendering the previous shell's
  /// content in a pane that wasn't designed for it (e.g. a rooms list
  /// showing up in the right sidebar).
  bool? _lastUseMobile;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the shell from scratch whenever the main chat surface
    // mounts (e.g. after a fresh login): the window may have been
    // resized while the dashboard was unmounted, so the committed shell
    // should be re-derived from the current width instead of inheriting
    // a stale one from the previous session.
    context.read<LayoutShellController>().reset();
  }

  /// Re-navigates to the active room (or to the rooms list when no
  /// room is open) so the new shell renders a clean default state.
  ///
  /// The page child itself rebuilds reactively through the
  /// [ListenableBuilder] in [_roomsListPageBuilder], so this only has
  /// to fix the *URL*: when the shell flipped the user may have been
  /// sitting on a room or the bare rooms list, and the new shell's
  /// default page should be re-derived from [CurrentRoom].  A plain
  /// [GoRouter.go] is enough; the old push/pop "refresh" hack leaked a
  /// page onto the route stack on every shell flip because the pushed
  /// page's future only completes when something pops it, which never
  /// happened, so every mobile/dashboard switch mounted a second live
  /// chat surface that was never disposed.
  void _navigateToActiveRoom() {
    final room = context.read<CurrentRoom>().room;
    final target = room == null ? '/main/rooms' : '/main/rooms/${room.id}';
    final router = GoRouter.of(context);
    router.go(target);
  }

  @override
  Widget build(BuildContext context) {
    // Only subscribe to the two values that actually drive the shell
    // decision: the user-forced layout mode and the window width.
    // Watching the entire SettingsController would rebuild this
    // widget on every preference change (theme, font size, density,
    // …) and could trigger spurious shell transitions.
    final layoutMode = context.select<SettingsController, LayoutMode>(
      (s) => s.layoutMode,
    );
    final width = MediaQuery.sizeOf(context).width;
    final shell = context.watch<LayoutShellController>();

    // The controller applies the sticky dead band around each
    // breakpoint, so the committed shell only changes when the width
    // has clearly crossed over, so no separate hysteresis is needed here.
    shell.update(rawWidth: width, layoutMode: layoutMode);
    final useMobile = shell.isMobile;

    if (_lastUseMobile != null && _lastUseMobile != useMobile) {
      // Shell transitioned.  Defer the navigation to a post-frame
      // callback so we never call [GoRouter.go] from inside a build
      // pass (which trips an assertion in newer Flutter versions).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigateToActiveRoom();
      });
    }
    _lastUseMobile = useMobile;

    if (useMobile) {
      return MobileLayout(child: widget.child);
    }
    return DashboardLayout(child: widget.child);
  }
}
