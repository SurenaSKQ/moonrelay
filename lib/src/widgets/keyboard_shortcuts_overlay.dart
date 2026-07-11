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

// Global keyboard shortcuts cheat sheet.
//
// Pressed `?` (Shift+/) anywhere in the app, this overlay pops up with
// every documented key binding. The overlay is wrapped in a short handler
// in [DashboardLayout] so it's reachable from any route under the main
// shell.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Show the keyboard shortcuts overlay as a modal bottom sheet.
Future<void> showKeyboardShortcutsOverlay(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const KeyboardShortcutsOverlay(),
  );
}

class KeyboardShortcutsOverlay extends StatelessWidget {
  const KeyboardShortcutsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final shortcuts = <_ShortcutEntry>[
      _ShortcutEntry(
        keys: const ['Ctrl', 'Shift', 'P'],
        description: loc.shortcutOpenCommandPalette,
      ),
      _ShortcutEntry(
        keys: const ['Ctrl', 'F'],
        description: loc.shortcutInRoomSearch,
      ),
      _ShortcutEntry(
        keys: const ['Ctrl', 'Shift', 'M'],
        description: loc.shortcutToggleLeftSidebar,
      ),
      _ShortcutEntry(
        keys: const ['Ctrl', 'Shift', 'R'],
        description: loc.shortcutToggleRightSidebar,
      ),
      _ShortcutEntry(
        keys: const ['Ctrl', 'B'],
        description: loc.shortcutBold,
      ),
      _ShortcutEntry(
        keys: const ['Ctrl', 'I'],
        description: loc.shortcutItalic,
      ),
      _ShortcutEntry(
        keys: const ['Ctrl', 'E'],
        description: loc.shortcutCode,
      ),
      _ShortcutEntry(
        keys: const ['Enter'],
        description: loc.shortcutSendMessage,
      ),
      _ShortcutEntry(
        keys: const ['Shift', 'Enter'],
        description: loc.shortcutNewline,
      ),
      _ShortcutEntry(
        keys: const ['Esc'],
        description: loc.shortcutCloseOverlay,
      ),
      _ShortcutEntry(
        keys: const ['?'],
        description: loc.shortcutShowShortcuts,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.keyboard, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  loc.shortcutsTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc.shortcutsSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    for (final entry in shortcuts)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16, top: 6),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final k in entry.keys) _KeyCap(label: k),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(entry.description),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                loc.shortcutsHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutEntry {
  const _ShortcutEntry({required this.keys, required this.description});
  final List<String> keys;
  final String description;
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}