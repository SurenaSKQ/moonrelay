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

import 'package:moonrelay/src/helpers/profile_delegate.dart';
import 'package:moonrelay/src/layouts/app_frame.dart';
import 'package:moonrelay/src/layouts/dashboard_layout.dart';
import 'package:moonrelay/src/layouts/startscreen_frame.dart';
import 'package:moonrelay/src/screens/register_page_inclient.dart';
import 'package:moonrelay/src/screens/startup_home_frame.dart';
import 'package:moonrelay/src/screens/hub_screen.dart';
import 'package:moonrelay/src/screens/login_page.dart';
import 'package:moonrelay/src/screens/add_room_from_id.dart';
import 'package:moonrelay/src/screens/room_details_page.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:moonrelay/src/screens/space_home_page.dart';
import 'package:moonrelay/src/screens/space_settings_page.dart';
import 'package:moonrelay/src/screens/startup_screen.dart';
import 'package:moonrelay/src/helpers/room_delegate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/screens/encryption/device_list_screen.dart';

class MoonRouter {
  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) {
    try {
      return Provider.of<Client>(context, listen: false).isLogged()
          ? '/rooms'
          : null;
    } catch (_) {
      return null;
    }
  }

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) {
    try {
      return Provider.of<Client>(context, listen: false).isLogged()
          ? null
          : '/welcome';
    } catch (_) {
      return '/welcome';
    }
  }

  MoonRouter();
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
              Provider.of<Client>(context, listen: false).isLogged()
                  ? '/main/rooms'
                  : '/welcome',
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
            DashboardLayout(child: child),
          ),
          routes: [
            GoRoute(
              path: '/main/rooms',
              redirect: loggedOutRedirect,
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                RoomDelegate(
                  roomID: state.pathParameters['roomid'],
                ),
              ),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => genericPageBuilder(
                    context,
                    state,
                    RoomDelegate(
                      roomID: state.pathParameters['roomid']!,
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
                        GoRoute(
                          path: ':userid',
                          pageBuilder: (context, state) => genericPageBuilder(
                            context,
                            state,
                            ProfileDelegate(
                              userid: state.pathParameters['userid'],
                            ),
                          ),
                        ),
                        GoRoute(
                          path: 'roomDetails',
                          pageBuilder: (context, state) {
                            String roomid = state.pathParameters['roomid']!;
                            Client client = Provider.of<Client>(context);
                            return genericPageBuilder(
                              context,
                              state,
                              RoomInformations(
                                room: client.getRoomById(roomid)!,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/main/myprofile',
              pageBuilder: (context, state) {
                final Client client =
                    Provider.of<Client>(context, listen: false);
                return genericPageBuilder(
                    context, state, HubScreen(client: client));
              },
            ),
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
                final String spaceId = state.pathParameters['spaceid']!;
                final Client client =
                    Provider.of<Client>(context, listen: false);
                final Room? space = client.getRoomById(spaceId);
                if (space == null) {
                  return genericPageBuilder(
                    context,
                    state,
                    const Center(child: Text('Space not found')),
                  );
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
                    final String spaceId = state.pathParameters['spaceid']!;
                    final Client client =
                        Provider.of<Client>(context, listen: false);
                    final Room? space = client.getRoomById(spaceId);
                    if (space == null) {
                      return genericPageBuilder(
                        context,
                        state,
                        const Center(child: Text('Space not found')),
                      );
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
  ) =>
      NoTransitionPage(
        key: state.pageKey,
        restorationId: state.pageKey.value,
        child: child,
      );
}
