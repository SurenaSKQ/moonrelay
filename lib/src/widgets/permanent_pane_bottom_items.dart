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

import 'package:azhi_main/src/localization/app_localizations.dart';
import 'package:azhi_main/src/widgets/blur_background.dart';
import 'package:fluent_ui/fluent_ui.dart';
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
        // NOTE - Ignored because this problem is handled with the global key.
        // ignore: use_build_context_synchronously
        context.go('/');
      } catch (e) {
        log.e("Logout error, maybe network failure",
            error: e, time: DateTime.now(), stackTrace: StackTrace.current);
        // ignore: use_build_context_synchronously
        // FIXME This can cause build exception
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text(AppLocalizations.of(context)!.error),
            content: Text(e.toString()),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Client client = Provider.of<Client>(context);
    final FlyoutController ownProfileFlyoutsController = FlyoutController();
    return Column(
      children: [
        FlyoutTarget(
          controller: ownProfileFlyoutsController,
          child: GestureDetector(
            child: BlurBackground(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: OwnProfileBar(client: client),
              ),
            ),
            onTap: () {
              ownProfileFlyoutsController.showFlyout(
                autoModeConfiguration: FlyoutAutoConfiguration(
                  preferredMode: FlyoutPlacementMode.topCenter,
                ),
                barrierDismissible: true,
                dismissOnPointerMoveAway: false,
                dismissWithEsc: true,
                builder: (context) {
                  return MenuFlyout(
                    items: [
                      MenuFlyoutItem(
                        leading: const Icon(FluentIcons.account_management),
                        text: const Text("Account"),
                        onPressed: () {
                          context.push('/main/myprofile');
                        },
                      ),
                      MenuFlyoutItem(
                        leading: const Icon(FluentIcons.settings),
                        text: const Text("Settings"),
                        onPressed: () {
                          context.push('/settings');
                        },
                      ),
                      MenuFlyoutItem(
                        leading: const Icon(FluentIcons.leave_user),
                        text: const Text("Logout"),
                        onPressed: () {
                          _logout();
                        },
                      )
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
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
              color: FluentTheme.of(context).accentColor,
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
                          backgroundColor: FluentTheme.of(context).accentColor,
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
