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

  /// Resolves a room from the route's :roomid parameter.
  static Room _roomFromState(BuildContext context, GoRouterState state) {
    final roomId = state.pathParameters['roomid']!;
    return Provider.of<Client>(context, listen: false).getRoomById(roomId)!;
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
            // Mobile mode does not need the far-left rail, the
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
                            // room route — redirect any deep link with
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
                  final client =
                      Provider.of<Client>(context, listen: false);
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
            // Hub screen — opened exclusively as a modal overlay
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
                      return _notFoundPage(
                          context, state, 'Space not found');
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
  /// Both layouts share the same route — the difference is purely in
  /// how the URL `/main/rooms` is presented.  Keeping the URL stable
  /// means the existing deep-link handling, command-palette routing,
  /// and back-button logic continue to work without modification.
  ///
  /// The mobile branch fires when the user has explicitly opted in to
  /// mobile mode *or* the window is too narrow for the compact shell.
  /// The latter is what lets the shell switch from dashboard to mobile
  /// smoothly as the user resizes the window down past
  /// [LayoutBreakpoints.mobileMax].
  static Page _roomsListPageBuilder(
    BuildContext context,
    GoRouterState state,
  ) {
    final settings = context.read<SettingsController>();
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = settings.layoutMode == LayoutMode.mobile ||
        LayoutBreakpoints.shouldUseMobile(width);
    final child = isMobile
        ? const MobileRoomsListPage()
        : RoomDelegate(
            roomID: state.pathParameters['roomid'],
            threadRootEventId: state.uri.queryParameters['threadRoot'],
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
/// The mobile layout is used when:
/// 1. The user explicitly opted in via [LayoutMode.mobile], OR
/// 2. The current viewport is too narrow for even the unified
///    compact sidebar (below [LayoutBreakpoints.mobileMax]).
///
/// The second rule is what handles window resizes — a user who
/// gradually shrinks the window sees the shell transition
/// full → compact → mobile as horizontal space runs out.
class _AdaptiveMainLayout extends StatefulWidget {
  const _AdaptiveMainLayout({required this.child});

  final Widget child;

  @override
  State<_AdaptiveMainLayout> createState() => _AdaptiveMainLayoutState();
}

class _AdaptiveMainLayoutState extends State<_AdaptiveMainLayout> {
  /// The shell the previous build chose.  Tracked so we can detect
  /// transitions and force a route navigation to a clean default
  /// page — without it, the dashboard inherits the [MobileRoomsListPage]
  /// (or vice versa) and ends up rendering the previous shell's
  /// content in a pane that wasn't designed for it (e.g. a rooms list
  /// showing up in the right sidebar).
  bool? _lastUseMobile;

  /// Resolves whether the active shell should be the mobile layout
  /// for the current [LayoutMode] + viewport width.
  ///
  /// Extracted so the layout-transition check and the render branch
  /// stay in sync — both call the same helper and the threshold logic
  /// lives in exactly one place.
  bool _resolveUseMobile() {
    final settings = context.watch<SettingsController>();
    final width = MediaQuery.sizeOf(context).width;
    return settings.layoutMode == LayoutMode.mobile ||
        LayoutBreakpoints.shouldUseMobile(width);
  }

  /// Re-navigates to the active room (or to the rooms list when no
  /// room is open) so the new shell renders a clean default state.
  ///
  /// Why this is needed: when the shell switches from mobile to
  /// dashboard (or vice versa), the route's `child` widget — built
  /// by [MoonRouter._roomsListPageBuilder] — may be stale for one
  /// frame.  The dashboard's right sidebar in particular happily
  /// accepts any widget and renders it, so the previous shell's
  /// `MobileRoomsListPage` can end up displayed in the right pane
  /// for a frame, looking like a content glitch.  Forcing a
  /// navigation rebuilds the route child with the new shell's
  /// default and clears the stale state.
  ///
  /// The target URL is derived from [CurrentRoom] so the user keeps
  /// the room they were looking at — the navigation just rebuilds
  /// the page from a clean slate instead of leaving the previous
  /// shell's widget in place.
  void _navigateToActiveRoom() {
    final room = context.read<CurrentRoom>().room;
    final target = room == null
        ? '/main/rooms'
        : '/main/rooms/${room.id}';
    // `context.go` is a no-op when the URL is unchanged, so when
    // the user is already sitting on the target URL (the common
    // case after a layout-mode change) we need a different
    // mechanism to force the page child to rebuild.  Pushing the
    // target and immediately popping is GoRouter's documented way
    // to refresh the current route's child widget — the push
    // creates a new page entry, the pop drops it, and the resulting
    // rebuild produces a fresh [child] for the new shell.
    final router = GoRouter.of(context);
    final currentPath = router.routeInformationProvider.value.uri.path;
    if (_pathsEqual(currentPath, target)) {
      router.push(target).whenComplete(() {
        if (!mounted) return;
        if (router.canPop()) router.pop();
      });
    } else {
      router.go(target);
    }
  }

  /// True when two GoRouter paths are equal (segment-wise, ignoring
  /// a trailing slash).  Used to decide whether the user is
  /// already on the target URL before we trigger the push/pop
  /// "refresh" trick.
  bool _pathsEqual(String a, String b) {
    final aSegs = a.split('/').where((s) => s.isNotEmpty).toList();
    final bSegs = b.split('/').where((s) => s.isNotEmpty).toList();
    if (aSegs.length != bSegs.length) return false;
    for (var i = 0; i < aSegs.length; i++) {
      if (aSegs[i] != bSegs[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final useMobile = _resolveUseMobile();
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
