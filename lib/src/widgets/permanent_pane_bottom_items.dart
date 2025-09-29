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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class PermanentPaneBottomItems extends StatefulWidget {
  const PermanentPaneBottomItems({super.key});

  @override
  State<PermanentPaneBottomItems> createState() =>
      _PermanentPaneBottomItemsState();
}

class _PermanentPaneBottomItemsState extends State<PermanentPaneBottomItems> {
  void _logout() async {
    if (context.mounted) {
      final client = Provider.of<Client>(context, listen: false);
      final log = Provider.of<Logger>(context, listen: false);
      try {
        await client.logout();
        context.go('/');
      } catch (e) {
        log.e("Logout error, maybe network failure",
            error: e, time: DateTime.now(), stackTrace: StackTrace.current);
        // ignore: use_build_context_synchronously
        // FIXME This can cause build exception
        // await displayInfoBar(context, builder: (context, close) {
        //   return InfoBar(
        //     title: Text(AppLocalizations.of(context)!.error),
        //     content: Text(e.toString()),
        //     action: IconButton(
        //       icon: const Icon(FluentIcons.clear),
        //       onPressed: close,
        //     ),
        //     severity: InfoBarSeverity.error,
        //   );
        // });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Client client = Provider.of<Client>(context);
    final MenuController ownProfileMenuController = MenuController();
    return MenuAnchor(
      controller: ownProfileMenuController,
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(LucideIcons.user),
          onPressed: () => context.push('/main/myprofile'),
          child: Text("Your Profile"),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.settings),
          onPressed: () => context.push('/settings'),
          child: Text("Settings"),
        ),
        MenuItemButton(
          leadingIcon: Icon(LucideIcons.logOut),
          onPressed: () => _logout(),
          child: Text("Log Out"),
        )
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          child: OwnProfileBar(client: client),
          onSecondaryTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class OwnProfileBar extends StatefulWidget {
  const OwnProfileBar({
    super.key,
    required this.client,
  });
  final Client client;
  @override
  State<OwnProfileBar> createState() => _OwnProfileBarState();
}

class _OwnProfileBarState extends State<OwnProfileBar> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.client.getProfileFromUserId(widget.client.userID!),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Builder(
            builder: (context) => SpinKitCubeGrid(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: snapshot.data?.avatarUrl == null
                      ? Text(
                          snapshot.data?.displayName == null
                              ? "You"
                              : snapshot.data!.displayName!
                                  .toUpperCase()
                                  .split(RegExp(' +'))
                                  .map((s) => s[0])
                                  .take(2)
                                  .join(),
                        )
                      : CircleAvatar(
                          foregroundImage: NetworkImage(
                            snapshot.data!.avatarUrl!
                                .getThumbnailUri(
                                  widget.client,
                                  animated: true,
                                  height: 56,
                                  width: 56,
                                )
                                .toString(),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                ),
                const SizedBox(
                  width: 69.0,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.data?.displayName ?? "View your profile",
                      style: const TextStyle(fontSize: 18, fontFamily: 'Rubik'),
                    ),
                    Text(
                      snapshot.data!.userId,
                      style: const TextStyle(fontSize: 16, fontFamily: 'Rubik'),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
