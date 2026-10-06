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
//   - `Ctrl+Shift+P`: command palette (also reachable via the
//                      button; there is no separate "search overlay"
//                      any more; the palette absorbs every search mode)
//   - `Ctrl+Shift+?`: keyboard shortcuts cheat sheet
//
// Both chords require two modifiers, so neither can be produced by typing and
// neither needs a text-field guard. There was one anyway, and it never fired:
// the node holding focus inside a focused `EditableText` is an internal `Focus`
// widget, so `primaryFocus?.context?.widget is EditableText` was false with the
// caret sitting in the composer. Deleted rather than repaired, because a guard
// that documents protection it does not provide is the more expensive half of
// the bug. `test/widget/command_palette_shortcut_test.dart` covers both chords
// with a text field focused and with neither modifier held.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonrelay/src/widgets/command_palette/command_palette.dart';
import 'package:moonrelay/src/widgets/keyboard_shortcuts_overlay.dart';

/// One shortcut chord, written down once.
///
/// This exists because the palette's chord was bound as `Ctrl+Shift+P` and
/// advertised as a hardcoded `Ctrl K` in the title bar, with two further
/// hardcoded chord lists in the cheat sheet and the settings page. Four
/// surfaces, three of them plain strings, and nothing that checked any of them
/// against the binding, so a chord that had never worked sat in the most
/// visible position in the window. Anything that binds a chord or shows it now
/// reads it from here, so the two cannot disagree without the disagreement
/// being the edit itself.
@immutable
class ShortcutChord {
  const ShortcutChord({
    required this.logicalKey,
    required this.keys,
    this.control = false,
    this.shift = false,
  });

  /// The key the activator listens for.
  final LogicalKeyboardKey logicalKey;

  /// The keys to draw, in order, as individual chips.
  ///
  /// A list rather than one string because the cheat sheet and the settings
  /// page both render one chip per key. It is not always derivable from
  /// [logicalKey]: the cheat sheet's chord is bound on `slash` and displayed
  /// as `?`, which is a difference of keyboard layout rather than of taste.
  final List<String> keys;

  final bool control;
  final bool shift;

  /// The chord as one label, `Ctrl+Shift+P`.
  String get label => keys.join('+');

  /// What to bind, so the chord on screen is the chord that fires.
  SingleActivator get activator =>
      SingleActivator(logicalKey, control: control, shift: shift);

  /// Opens the command palette.
  static const ShortcutChord commandPalette = ShortcutChord(
    logicalKey: LogicalKeyboardKey.keyP,
    keys: <String>['Ctrl', 'Shift', 'P'],
    control: true,
    shift: true,
  );

  /// Opens the cheat sheet.
  ///
  /// `?` is Ctrl+Shift+/ on a US layout. `CharacterActivator` would conflict
  /// with the literal `?` character during text input, so the chord is matched
  /// on the physical key instead: it only fires when both modifiers are held,
  /// never during normal typing. That also makes it layout-dependent, on every
  /// layout where `?` is not Shift+/. `Ctrl+Shift+P` has no such problem,
  /// which is part of why it is the better of the two.
  static const ShortcutChord showShortcuts = ShortcutChord(
    logicalKey: LogicalKeyboardKey.slash,
    keys: <String>['Ctrl', 'Shift', '?'],
    control: true,
    shift: true,
  );
}

class GlobalShortcutListener extends StatelessWidget {
  const GlobalShortcutListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        ShortcutChord.commandPalette.activator:
            const _OpenCommandPaletteIntent(),
        ShortcutChord.showShortcuts.activator: const _ShowShortcutsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              showCommandPalette(context);
              return null;
            },
          ),
          _ShowShortcutsIntent: CallbackAction<_ShowShortcutsIntent>(
            onInvoke: (_) {
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

class _ShowShortcutsIntent extends Intent {
  const _ShowShortcutsIntent();
}
