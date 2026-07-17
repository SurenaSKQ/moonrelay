// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2026 Surena Karimpour Ghannadi

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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Keybinds Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubKeybindSettings extends StatelessWidget {
  const HubKeybindSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.keybinds,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.keybindsDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Send shortcut ─────────────────────────────────────────
              HubSettingsSection(
                title: l10n.sendShortcut,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sendShortcutDescription,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final s in SendShortcut.values)
                              ChoiceChip(
                                label: Text(localizedSendShortcut(s, l10n)),
                                selected: s == controller.sendShortcut,
                                onSelected: (_) =>
                                    controller.updateSendShortcut(s),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Global shortcuts reference ────────────────────────────
              HubSettingsSection(
                title: l10n.shortcutsTitle,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'Shift', 'P'],
                      description: l10n.shortcutOpenCommandPalette,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'F'],
                      description: l10n.shortcutInRoomSearch,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'Shift', 'M'],
                      description: l10n.shortcutToggleLeftSidebar,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'Shift', 'R'],
                      description: l10n.shortcutToggleRightSidebar,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'Shift', '?'],
                      description: l10n.shortcutShowShortcuts,
                      cs: cs,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Composer shortcuts reference ──────────────────────────
              HubSettingsSection(
                title: l10n.composer,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'B'],
                      description: l10n.shortcutBold,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'I'],
                      description: l10n.shortcutItalic,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Ctrl', 'E'],
                      description: l10n.shortcutCode,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Enter'],
                      description: l10n.shortcutSendMessage,
                      cs: cs,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _ShortcutRow(
                      keys: ['Shift', 'Enter'],
                      description: l10n.shortcutNewline,
                      cs: cs,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.keys,
    required this.description,
    required this.cs,
  });

  final List<String> keys;
  final String description;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 4,
          children: [
            for (final k in keys)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
