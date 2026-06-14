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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/widgets/window_buttons.dart';

/// this should NOT be used anywhere! Que for removal
class NavigationViewMainFrame extends StatefulWidget {
  const NavigationViewMainFrame({
    super.key,
    required this.child,
    required this.shellContext,
  });

  final Widget child;
  final BuildContext? shellContext;
  @override
  State<NavigationViewMainFrame> createState() =>
      _NavigationViewMainFrameState();
}

class _NavigationViewMainFrameState extends State<NavigationViewMainFrame>
    with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Custom title bar
        Container(
          color: theme.brightness == Brightness.light
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          child: GestureDetector(
            onPanStart: (_) => windowManager.startDragging(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: const TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    "{${GoRouterState.of(context).uri.toString()}}",
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => context.push('/settings'),
                    ),
                    const WindowButtons(),
                  ],
                )
              ],
            ),
          ),
        ),
        // Content area
        Expanded(child: widget.child),
      ],
    );
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.confirmClose),
            content: Text(AppLocalizations.of(context)!.areYouSureExit),
            actions: [
              FilledButton(
                child: Text(AppLocalizations.of(context)!.yesOrAffirmitive),
                onPressed: () {
                  Navigator.pop(context);
                  windowManager.destroy();
                },
              ),
              OutlinedButton(
                child: Text(AppLocalizations.of(context)!.noOrCancellation),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    }
  }
}
