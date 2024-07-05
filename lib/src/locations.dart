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

import 'package:azhi_main/src/layouts/empty_space.dart';
import 'package:azhi_main/src/layouts/main_frame.dart';
import 'package:azhi_main/src/screens/chat_main.dart';
import 'package:azhi_main/src/screens/home_screen.dart';
import 'package:azhi_main/src/screens/login_page.dart';
import 'package:azhi_main/src/settings/settings_view.dart';
import 'package:azhi_main/src/widgets/room_delegate.dart';
import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class AppRootLocation extends BeamLocation<BeamState> {
  AppRootLocation(RouteInformation routeInformation) : super(routeInformation);
  @override
  List<String> get pathPatterns => ['/*'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        BeamPage(
          key: ValueKey('home-${DateTime.now()}'),
          title: 'mainframe',
          child: const FluentMainFrame(),
        )
      ];
}

class MetaLocation extends BeamLocation<BeamState> {
  MetaLocation(RouteInformation routeInformation) : super(routeInformation);
  @override
  List<String> get pathPatterns => ['/main/*'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('/chat'),
          child: FluentChatMain(),
        ),
        const BeamPage(
          key: ValueKey('/login'),
          title: 'Login',
          child: FluentLoginPage(),
        ),
        const BeamPage(
          key: ValueKey('/welcome'),
          title: 'Welcome',
          child: FluentHomePage(),
        ),
        const BeamPage(
          key: ValueKey('/settings'),
          title: 'Settings',
          child: SettingsView(),
        ),
      ];

  @override
  List<BeamGuard> get guards => [
        BeamGuard(
          pathPatterns: ['*'],
          check: (context, location) =>
              !(Provider.of<Client>(context, listen: false).isLogged()),
          beamToNamed: (origin, target) => "/welcome",
        ),
        BeamGuard(
          pathPatterns: ['*'],
          check: (context, location) =>
              (Provider.of<Client>(context, listen: false).isLogged()),
          beamToNamed: (origin, target) => "/chat",
        ),
      ];
}

class RoomBeamer extends BeamLocation<BeamState> {
  RoomBeamer(RouteInformation routeInformation) : super(routeInformation);

  @override
  List<String> get pathPatterns => ['/main/chat/room/:roomID'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    if ((state.pathParameters['roomID']) != null) {
      return [
        BeamPage(
          key: ValueKey("Room-${state.pathParameters['roomID']}"),
          child: RoomDelegate(roomID: state.pathParameters['roomID']!),
        ),
      ];
    } else {
      return [
        const BeamPage(key: ValueKey("placeholder"), child: EmptySpace())
      ];
    }
  }
}
