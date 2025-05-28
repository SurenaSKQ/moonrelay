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
import 'package:moonrelay/src/layouts/two_column_layout.dart';
import 'package:moonrelay/src/screens/startup_home_frame.dart';
import 'package:moonrelay/src/screens/login_page.dart';
import 'package:moonrelay/src/screens/own_user_profile.dart';
import 'package:moonrelay/src/screens/register_page.dart';
import 'package:moonrelay/src/screens/room_details_page.dart';
import 'package:moonrelay/src/screens/startup_screen.dart';
import 'package:moonrelay/src/settings/settings_view.dart';
import 'package:moonrelay/src/helpers/room_delegate.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/side_pane_handler.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class MoonRouter {
  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) =>
      Provider.of<Client>(context, listen: false).isLogged() ? '/rooms' : null;

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) =>
      Provider.of<Client>(context, listen: false).isLogged()
          ? null
          : '/welcome';

  MoonRouter();
  // TODO: If the user is on desktop use a frame, if the user is on mobile use mobile layout.
  static final List<RouteBase> routes = [
    ShellRoute(
      pageBuilder: (context, state, child) => genericPageBuilder(
        context,
        state,
        AppFrame(shellContext: context, child: child),
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
                      const RegisterNewUserAccountGuidancePage(),
                    ),
                  ),
                ]),
          ],
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => genericPageBuilder(
            context,
            state,
            const SettingsView(),
          ),
        ),
        ShellRoute(
          pageBuilder: (context, state, child) => genericPageBuilder(
            context,
            state,
            TwoColumnLayout(
              mainView: const SidePaneHandler(child: RoomsPane()),
              sideView: child,
            ),
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
                    context, state, OwnProfilePage(client: client));
              },
            )
          ],
        )
      ],
    ),
  ];

  static final Router panelRouter = Router.withConfig(
    config: GoRouter(
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => genericPageBuilder(
            context,
            state,
            SidePaneHandler(
              child: child,
            ),
          ),
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => genericPageBuilder(
                context,
                state,
                const RoomsPane(),
              ),
            )
          ],
        ),
      ],
    ),
  );

  static Page genericPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) =>
      CustomTransitionPage(
        key: state.pageKey,
        restorationId: state.pageKey.value,
        child: child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}
