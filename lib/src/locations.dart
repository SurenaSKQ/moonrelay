// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:azhi_main/src/layouts/main_frame.dart';
import 'package:azhi_main/src/layouts/two_column_layout.dart';
import 'package:azhi_main/src/screens/home_screen.dart';
import 'package:azhi_main/src/screens/login_page.dart';
import 'package:azhi_main/src/settings/settings_view.dart';
import 'package:azhi_main/src/helpers/room_delegate.dart';
import 'package:azhi_main/src/widgets/rooms_pane.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class AppLocationsHandler {
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

  AppLocationsHandler();

  static final List<RouteBase> routes = [
    ShellRoute(
        pageBuilder: (context, state, child) => azhiPageBuilder(
              context,
              state,
              Mica(
                child: FluentMainFrame(
                  shellContext: context,
                  child: child,
                ),
              ),
            ),
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) =>
                Provider.of<Client>(context, listen: false).isLogged()
                    ? '/rooms'
                    : '/welcome',
          ),
          GoRoute(
            path: '/welcome',
            pageBuilder: (context, state) =>
                azhiPageBuilder(context, state, const FluentHomePage()),
            redirect: loggedInRedirect,
            routes: [
              GoRoute(
                path: 'login',
                pageBuilder: (context, state) => azhiPageBuilder(
                  context,
                  state,
                  const FluentLoginPage(),
                ),
              ),
              GoRoute(
                path: 'register',
                redirect: (context, state) => '/welcome/login',
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => azhiPageBuilder(
              context,
              state,
              const SettingsView(),
            ),
          ),
          ShellRoute(
            pageBuilder: (context, state, child) => azhiPageBuilder(
              context,
              state,
              TwoColumnLayout(
                mainView: const RoomsPane(),
                sideView: child,
              ),
            ),
            routes: [
              GoRoute(
                path: '/rooms',
                redirect: loggedOutRedirect,
                pageBuilder: (context, state) => azhiPageBuilder(
                  context,
                  state,
                  RoomDelegate(
                    roomID: state.pathParameters['roomid'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':roomid',
                    pageBuilder: (context, state) => azhiPageBuilder(
                      context,
                      state,
                      RoomDelegate(
                        roomID: state.pathParameters['roomid']!,
                      ),
                    ),
                    redirect: loggedOutRedirect,
                  ),
                ],
              ),
            ],
          )
        ]),
  ];

  static Page azhiPageBuilder(
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
