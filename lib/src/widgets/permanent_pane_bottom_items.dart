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
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/own_profile_bar.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:provider/provider.dart';

/// A bottom bar for the sidebar pane that shows the user's profile and
/// a right-click context menu with navigation (Hub) and logout actions.
class PermanentPaneBottomItems extends StatefulWidget {
  const PermanentPaneBottomItems({super.key});

  @override
  State<PermanentPaneBottomItems> createState() =>
      _PermanentPaneBottomItemsState();
}

class _PermanentPaneBottomItemsState extends State<PermanentPaneBottomItems> {
  final MenuController _menuController = MenuController();

  Future<void> _logout() async {
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    final enc = context.read<EncryptionService>();
    try {
      await enc.onLogout();
      await client.logout();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      log.e(
        'Logout error',
        error: e,
        time: DateTime.now(),
        stackTrace: StackTrace.current,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.error),
              Text(e.toString()),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.layoutDashboard),
          onPressed: () => context.push('/main/myprofile'),
          child: Text(AppLocalizations.of(context)!.hub),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.logOut),
          onPressed: _logout,
          child: Text(AppLocalizations.of(context)!.logOut),
        ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          onSecondaryTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          onTap: () => context.push('/main/myprofile'),
          child: OwnProfileBar(client: client),
        );
      },
    );
  }
}
