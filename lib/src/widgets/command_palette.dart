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

// Command palette (`Ctrl+K`).
//
// Wraps [GlobalSearchOverlay] in a shortcut-handling overlay entrypoint
// plus a list of static actions (toggle sidebars, open settings, sign
// out, …).  The palette is reachable from anywhere in the app via
// `Ctrl+K` and dismissed with `Esc`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/global_search_overlay.dart';
import 'package:provider/provider.dart';

/// Shows the command palette as a modal route.
Future<void> showCommandPalette(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => const _CommandPalettePage(),
    ),
  );
}

class _CommandPalettePage extends StatefulWidget {
  const _CommandPalettePage();

  @override
  State<_CommandPalettePage> createState() => _CommandPalettePageState();
}

class _CommandPalettePageState extends State<_CommandPalettePage> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _ctl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.removeListener(_onChanged);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _query = _ctl.text.trim().toLowerCase());
    });
  }

  void _runAction(CommandAction action) {
    Navigator.of(context).pop();
    action.callback(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final client = context.watch<Client?>();

    final actions = _buildActions(loc);
    final matchedActions = _query.isEmpty
        ? actions
        : actions
            .where((a) => a.label.toLowerCase().contains(_query))
            .toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ctl,
                      focusNode: _focus,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.command),
                        hintText: loc.commandPaletteHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        // Pressing Enter on a single-match query runs the
                        // top result; otherwise we delegate to the global
                        // search overlay.
                        if (matchedActions.length == 1) {
                          _runAction(matchedActions.first);
                        } else if (client != null) {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (_) => const GlobalSearchOverlay(),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: matchedActions.isEmpty
                          ? Center(child: Text(loc.commandPaletteNoResults))
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                if (matchedActions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        8, 4, 8, 4),
                                    child: Text(
                                      loc.commandPaletteActions,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                  ),
                                for (final action in matchedActions)
                                  ListTile(
                                    dense: true,
                                    leading: Icon(action.icon),
                                    title: Text(action.label),
                                    onTap: () => _runAction(action),
                                  ),
                                if (client != null) ...[
                                  const Divider(height: 24),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        8, 4, 8, 4),
                                    child: Text(
                                      loc.commandPaletteRooms,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                  ),
                                  ListTile(
                                    dense: true,
                                    leading:
                                        const Icon(LucideIcons.search),
                                    title: Text(
                                      loc.globalSearch,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            const GlobalSearchOverlay(),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<CommandAction> _buildActions(AppLocalizations loc) {
    return [
      CommandAction(
        label: loc.commandPaletteOpenSettings,
        icon: LucideIcons.settings,
        callback: (ctx) => ctx.go('/hub/settings'),
      ),
      CommandAction(
        label: loc.commandPaletteOpenAccounts,
        icon: LucideIcons.userRound,
        callback: (ctx) => ctx.go('/hub/accounts'),
      ),
      CommandAction(
        label: loc.commandPaletteOpenLogs,
        icon: LucideIcons.scrollText,
        callback: (ctx) => ctx.go('/hub/logs'),
      ),
      CommandAction(
        label: loc.commandPaletteToggleSidebar,
        icon: LucideIcons.panelLeft,
        callback: (ctx) {
          // SettingsController is provided above the dashboard layout;
          // the toggle only makes sense if a controller is in scope.
          try {
            final settings = ctx.read<SettingsController>();
            settings.setLeftSidebarVisible(!settings.leftSidebarVisible);
          } catch (_) {
            // ignore — action is best-effort outside dashboard
          }
        },
      ),
    ];
  }
}

class CommandAction {
  const CommandAction({
    required this.label,
    required this.icon,
    required this.callback,
  });
  final String label;
  final IconData icon;
  final void Function(BuildContext) callback;
}