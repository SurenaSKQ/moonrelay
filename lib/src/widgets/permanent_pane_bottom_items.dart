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

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class PermanentPaneBottomItems extends StatefulWidget {
  const PermanentPaneBottomItems({super.key});

  @override
  State<PermanentPaneBottomItems> createState() =>
      _PermanentPaneBottomItemsState();
}

class _PermanentPaneBottomItemsState extends State<PermanentPaneBottomItems> {
  @override
  Widget build(BuildContext context) {
    Client client = Provider.of<Client>(context);
    final FlyoutController ownProfileFlyoutsController = FlyoutController();
    return Column(
      children: [
        FlyoutTarget(
          controller: ownProfileFlyoutsController,
          child: OutlinedButton(
            child: Row(
              children: [
                const CircleAvatar(),
                const SizedBox(
                  width: 8.0,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "[username will show here]",
                      style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      client.userID!,
                      style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ],
            ),
            onPressed: () {
              ownProfileFlyoutsController.showFlyout(
                autoModeConfiguration: FlyoutAutoConfiguration(
                  preferredMode: FlyoutPlacementMode.topCenter,
                ),
                barrierDismissible: true,
                dismissOnPointerMoveAway: true,
                dismissWithEsc: true,
                builder: (context) {
                  return MenuFlyout(
                    items: [
                      MenuFlyoutItem(
                        text: const Text("Account"),
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        text: const Text("Settings"),
                        onPressed: () {
                          context.push('/settings');
                        },
                      ),
                      MenuFlyoutItem(
                        text: const Text("Logout"),
                        onPressed: () {
                          Provider.of<Client>(context).logout();
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
