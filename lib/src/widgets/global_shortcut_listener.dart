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

// Global keyboard shortcut handler.
//
// Mount this widget above the dashboard so the following shortcuts fire
// from anywhere in the room page tree:
//   - `Ctrl+K`        → command palette
//   - `Ctrl+Shift+K`  → global search overlay
//   - `?` (Shift+/)   → keyboard shortcuts cheat sheet
//
// Shortcuts are swallowed when a text field has focus so users can still
// type the letters without triggering the overlay.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonrelay/src/widgets/command_palette.dart';
import 'package:moonrelay/src/widgets/global_search_overlay.dart';
import 'package:moonrelay/src/widgets/keyboard_shortcuts_overlay.dart';

class GlobalShortcutListener extends StatelessWidget {
  const GlobalShortcutListener({super.key, required this.child});
  final Widget child;

  static bool _isTextFieldFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final focused = primary?.context?.widget;
    return focused is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true):
            _OpenGlobalSearchIntent(),
        // `?` is Shift+/ on US layouts; CharacterActivator matches the
        // resulting character regardless of layout. We also bind
        // Shift+/ directly as a fallback for layouts where the
        // CharacterActivator does not fire.
        CharacterActivator('?'): _ShowShortcutsIntent(),
        SingleActivator(LogicalKeyboardKey.slash, shift: true):
            _ShowShortcutsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              showCommandPalette(context);
              return null;
            },
          ),
          _OpenGlobalSearchIntent: CallbackAction<_OpenGlobalSearchIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              showDialog(
                context: context,
                builder: (_) => const GlobalSearchOverlay(),
              );
              return null;
            },
          ),
          _ShowShortcutsIntent: CallbackAction<_ShowShortcutsIntent>(
            onInvoke: (_) {
              if (_isTextFieldFocused()) return null;
              showKeyboardShortcutsOverlay(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _OpenGlobalSearchIntent extends Intent {
  const _OpenGlobalSearchIntent();
}

class _ShowShortcutsIntent extends Intent {
  const _ShowShortcutsIntent();
}