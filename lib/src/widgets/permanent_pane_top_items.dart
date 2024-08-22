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

class PermanentPaneTopItems extends StatefulWidget {
  const PermanentPaneTopItems({super.key});

  @override
  State<PermanentPaneTopItems> createState() => _PermanentPaneTopItemsState();
}

class _PermanentPaneTopItemsState extends State<PermanentPaneTopItems> {
  final _menuController = FlyoutController();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FlyoutTarget(
          controller: _menuController,
          child: OutlinedButton(
            child: const Row(
              children: [
                Icon(FluentIcons.expand_menu),
                Text("Actions"),
              ],
            ),
            onPressed: () {
              _menuController.showFlyout(
                autoModeConfiguration: FlyoutAutoConfiguration(
                    preferredMode: FlyoutPlacementMode.topLeft),
                barrierDismissible: true,
                dismissOnPointerMoveAway: false,
                dismissWithEsc: true,
                builder: (context) => MenuFlyout(
                  items: [
                    MenuFlyoutItem(
                        leading: const Icon(FluentIcons.add),
                        text: const Text("New room"),
                        onPressed: () {}),
                    MenuFlyoutItem(
                        leading: const Icon(FluentIcons.accounts),
                        text: const Text("Join room from ID"),
                        onPressed: () {}),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
