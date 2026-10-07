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

// The palette's keyboard chord, and where the thing that binds it is mounted.
//
// The chord was bound as `Ctrl+Shift+P` and advertised as a hardcoded `Ctrl K`
// in the title bar, with two further hardcoded chord lists in the cheat sheet and
// the settings page. Nothing compared any of them to the binding and no test
// pressed a key, so a chord that had never worked sat in the most visible
// position in the window.
//
// The listener was also mounted in the wrong place: inside the dashboard's
// `Expanded` content pane. A `Shortcuts` widget is consulted only by walking up
// from the node holding focus, so that made it an ancestor of the conversation
// and of nothing else. Not the rail beside it, not the room list beside that,
// not the hub, and not the window title bar, which is a sibling of
// `Scaffold.body` rather than a descendant of it. It is mounted in `AppFrame`
// now, wrapping the `Scaffold`, which is the only position that reaches both
// `appBar` and `body`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/layouts/app_frame.dart';
import 'package:moonrelay/src/layouts/window_title_bar.dart';
import 'package:moonrelay/src/widgets/command_palette/command_palette.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';

import '../helpers/widget_test_utils.dart';

void main() {
  /// Mounts the listener, optionally in the position production puts it.
  ///
  /// `wrapInShell` builds an `AppFrame` and lets *it* provide the listener,
  /// rather than wrapping one around it. Adding an outer one as well would be
  /// two listeners, which is a different arrangement from production's and
  /// would make the "not mounted twice" assertion below meaningless.
  Future<void> pumpListener(
    WidgetTester tester, {
    required Widget child,
    bool wrapInShell = false,
  }) async {
    // The shared wrapper rather than a bare `MaterialApp`: the palette reads
    // `AppLocalizations` and `MoonrelayThemeExtension`, and without them the
    // route builds far enough to push and then throws on a null check, which
    // looks exactly like the shortcut not having fired.
    final Widget inner = wrapInShell
        ? AppFrame(child: child)
        : GlobalShortcutListener(child: child);
    await tester.pumpWidget(
      wrapWithProviders(child: Scaffold(body: Center(child: inner))),
    );
    await tester.pump();
  }

  Future<void> pressChord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

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
      expect(
        ShortcutChord.commandPalette.label,
        ShortcutChord.commandPalette.keys.join('+'),
      );
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
      expect(
        ShortcutChord.showShortcuts.activator.trigger,
        LogicalKeyboardKey.slash,
      );
      expect(ShortcutChord.showShortcuts.label, 'Ctrl+Shift+?');
    });
  });

  group('the binding', () {
    testWidgets('Ctrl+Shift+P opens the palette', (tester) async {
      await pumpListener(tester, child: const Text('body'));

      await pressChord(tester, LogicalKeyboardKey.keyP);

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
      // The guard that used to refuse the chord whenever a text field had focus
      // was deleted rather than repaired. Its replacement is the activator
      // itself: both chords need two modifiers held, and no text input produces
      // either, so plain typing cannot fire them. This is that assertion.
      await pumpListener(tester, child: const Text('body'));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(CommandPalettePage), findsNothing);
    });

    testWidgets('and it opens while a text field has focus', (tester) async {
      // The composer is the normal state of a room, so this is the case a user
      // actually hits.
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
      // `EditableText`, which is the whole reason the deleted guard never fired.
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
        reason: 'the text field must actually hold focus',
      );

      await pressChord(tester, LogicalKeyboardKey.keyP);

      expect(find.byType(CommandPalettePage), findsOneWidget);
    });
  });

  group('where the listener is mounted', () {
    testWidgets('is inside AppFrame, above the Scaffold', (tester) async {
      await pumpListener(tester, wrapInShell: true, child: const Text('body'));

      expect(find.byType(GlobalShortcutListener), findsOneWidget);
      // Inside `AppFrame`, and above its `Scaffold`. `appBar` and `body` are
      // siblings in the Scaffold's layout, so only a wrapper around the Scaffold
      // reaches the title bar as well as the conversation.
      expect(
        find.descendant(
          of: find.byType(AppFrame),
          matching: find.byType(GlobalShortcutListener),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(Scaffold),
          matching: find.byType(GlobalShortcutListener),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.byType(WindowTitleBar),
          matching: find.byType(GlobalShortcutListener),
        ),
        findsOneWidget,
        reason: 'the title bar is appBar, not body, so it was the one surface '
            'no mount inside the shell could reach',
      );
    });

    testWidgets('is not mounted twice', (tester) async {
      // It used to be mounted once per shell, in `DashboardView` and again in
      // `MobileLayout`, which is two independent copies of one binding.
      await pumpListener(tester, wrapInShell: true, child: const Text('body'));

      expect(find.byType(GlobalShortcutListener), findsOneWidget);
    });

    testWidgets('the chord fires from inside the shell', (tester) async {
      await pumpListener(tester, wrapInShell: true, child: const Text('body'));

      await pressChord(tester, LogicalKeyboardKey.keyP);

      expect(find.byType(CommandPalettePage), findsOneWidget);
    });

    testWidgets('and it fires from the title bar, which it never could', (
      tester,
    ) async {
      // Focus lands on the title bar's search control, which is an
      // `InkResponse` and therefore focusable. Before the mount moved, the
      // event bubbled up through `appBar` to the `Scaffold` and stopped, never
      // reaching a `Shortcuts` node that lived in `body`.
      await pumpListener(tester, wrapInShell: true, child: const Text('body'));

      await tester.tap(find.byType(WindowTitleBar));
      await tester.pump();

      await pressChord(tester, LogicalKeyboardKey.keyP);

      expect(find.byType(CommandPalettePage), findsOneWidget);
    });
  });
}
