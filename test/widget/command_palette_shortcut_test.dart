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

// The palette's keyboard chord, and the fact that four surfaces used to state
// it independently.
//
// The title bar rendered a hardcoded `Ctrl K`, which was never bound to
// anything, while the chord actually wired up was `Ctrl+Shift+P`. The cheat
// sheet and the settings page each had their own copy of a third chord list.
// Nothing compared any of them to the binding, and no test pressed a key, so
// the wrong chord sat in the most visible position in the window indefinitely.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/widgets/command_palette/command_palette.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  group('the chord itself', () {
    test('is Ctrl+Shift+P', () {
      expect(ShortcutChord.commandPalette.label, 'Ctrl+Shift+P');
      // Compared field by field because `SingleActivator` does not override
      // `==`, so two instances of the same chord are not equal.
      final SingleActivator activator = ShortcutChord.commandPalette.activator;
      expect(activator.trigger, LogicalKeyboardKey.keyP);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
      expect(activator.alt, isFalse);
      expect(activator.meta, isFalse);
    });

    test('draws one chip per key, in order', () {
      expect(ShortcutChord.commandPalette.keys, <String>['Ctrl', 'Shift', 'P']);
      expect(ShortcutChord.commandPalette.label,
          ShortcutChord.commandPalette.keys.join('+'));
    });

    test('is not the chord that used to be advertised', () {
      // The regression, stated as an assertion rather than as a comment. If a
      // future edit puts `Ctrl K` back into the label, or binds keyK, this fails
      // instead of shipping another chord that does nothing.
      expect(ShortcutChord.commandPalette.keys, isNot(contains('K')));
      expect(
        ShortcutChord.commandPalette.activator.trigger,
        isNot(LogicalKeyboardKey.keyK),
      );
    });

    test('the cheat sheet chord is bound on slash and drawn as a question mark',
        () {
      // Deliberately not derivable from the key: `?` is Shift+/ on a US layout
      // and something else on most others. Recording both halves here means the
      // next edit that tries to derive one from the other has to say so.
      expect(ShortcutChord.showShortcuts.activator.trigger,
          LogicalKeyboardKey.slash);
      expect(ShortcutChord.showShortcuts.label, 'Ctrl+Shift+?');
    });
  });

  group('the binding', () {
    Future<void> pumpListener(
      WidgetTester tester, {
      required Widget child,
    }) async {
      // The shared wrapper rather than a bare `MaterialApp`: the palette reads
      // `AppLocalizations` and `MoonrelayThemeExtension`, and without them the
      // route builds far enough to push and then throws on a null check, which
      // looks exactly like the shortcut not having fired.
      await tester.pumpWidget(
        wrapWithProviders(
          child: GlobalShortcutListener(
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('Ctrl+Shift+P opens the palette', (tester) async {
      await pumpListener(tester, child: const Text('body'));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(CommandPalettePage), findsOneWidget);
    });

    testWidgets('Ctrl+K opens nothing, because nothing binds it', (
      tester,
    ) async {
      // The chord the title bar used to advertise. Asserting that it does
      // nothing is how a reader of this file learns it is not the chord, rather
      // than having to notice the absence of a test.
      await pumpListener(tester, child: const Text('body'));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(CommandPalettePage), findsNothing);
    });

    testWidgets('a bare P with no modifiers does not open it', (tester) async {
      // The guard exists so typing the letter does not summon the palette, and
      // that only holds if the activator really requires the modifiers.
      await pumpListener(tester, child: const Text('body'));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(CommandPalettePage), findsNothing);
    });

    testWidgets('and it still opens while a text field has focus',
        (tester) async {
      // The composer is the normal state of a room, so this is the case a user
      // actually hits.
      //
      // There used to be a guard here that refused both chords whenever an
      // `EditableText` held focus, on the reasoning that users should be able to
      // type the letters without summoning the palette. It never fired: the node
      // holding focus inside a focused `EditableText` is an internal `Focus`
      // widget, so `primaryFocus?.context?.widget is EditableText` was false
      // even with the caret blinking in the composer. A guard that does not guard
      // is worse than no guard, because it documents protection that is not
      // there, so it is deleted rather than repaired.
      //
      // Nothing is lost by deleting it. Both chords require Ctrl and Shift to be
      // held, and no text input produces either of them, so plain typing cannot
      // summon the palette. The next test is the assertion for that.
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      // `GlobalShortcutListener` wraps its child in `Focus(autofocus: true)`,
      // which wins the autofocus race against a `TextField`'s own, so the field
      // is focused explicitly rather than by `autofocus: true`.
      final FocusNode fieldFocus = FocusNode();
      addTearDown(fieldFocus.dispose);

      await pumpListener(
        tester,
        child: TextField(controller: controller, focusNode: fieldFocus),
      );
      fieldFocus.requestFocus();
      await tester.pump();
      // The assertion that makes this test mean anything. Without it the chord
      // could be opening because focus never reached the text field, in which
      // case the guard under test was never consulted.
      //
      // Asked of the field's own focus node rather than of
      // `FocusManager.instance.primaryFocus`: the node that actually holds focus
      // inside a focused `EditableText` is an internal `Focus` widget, not the
      // `EditableText`, which is the whole reason the deleted guard below never
      // fired.
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
        reason: 'the text field must actually hold focus',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(CommandPalettePage), findsOneWidget);
    });
  });
}
