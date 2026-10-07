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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Submits the enclosing sign-in or register form.
///
/// Bound to Enter and the numpad Enter, for the case where focus is on
/// something that is not a text field: the mode links, the card, the page
/// background. Enter inside a field is handled by that field's
/// `onSubmitted`, because a single-line [TextField] consumes the key before
/// a shortcut above it can see it.
class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

/// Wraps a form so Tab follows the visual order and Enter submits it.
///
/// Tab already works in a Flutter app, but it walks the focus tree, which
/// for a form built out of conditionals is not the same thing as the order
/// the fields appear in. The explicit group makes the order the one the
/// user is reading.
class FormKeyboard extends StatelessWidget {
  const FormKeyboard({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    required this.child,
  });

  /// Runs the form's primary action.
  final VoidCallback onSubmit;

  /// Whether the Enter shortcut is armed.
  ///
  /// False while a request is in flight. Without this, a user who holds
  /// Enter down while the homeserver is slow fires a second sign-in
  /// attempt on top of the first.
  final bool enabled;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): SubmitFormIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): SubmitFormIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SubmitFormIntent: CallbackAction<SubmitFormIntent>(
            onInvoke: (_) {
              if (enabled) onSubmit();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }
}

/// The text fields currently on screen, in the order Tab visits them and
/// Enter advances through them.
///
/// The list is rebuilt whenever the form changes shape, because a sign-in
/// form shows a different set of fields per mode. Enter on the last visible
/// field submits; on any other it moves down one, which is what a user
/// filling the form in order expects and is why this is not simply "the
/// field after this one in the State".
class FormFieldOrder {
  FormFieldOrder();

  /// The visible nodes, top to bottom. Assigned during build.
  List<FocusNode> nodes = const <FocusNode>[];

  /// Whether the form currently has no visible text field, in which case
  /// Enter should submit rather than try to move anywhere.
  bool get isEmpty => nodes.isEmpty;

  /// Handles Enter in the field at [index]: move to the next visible field,
  /// or run [onLast] when [index] is already the last one.
  void submitAt(int index, {required VoidCallback onLast}) {
    if (index + 1 < nodes.length) {
      nodes[index + 1].requestFocus();
    } else {
      onLast();
    }
  }

  /// The `onSubmitted` handler for the field at [index], shaped for
  /// [TextField.onSubmitted] (which passes the field's text).
  ValueChanged<String> submittedAt(int index, {required VoidCallback onLast}) {
    return (_) => submitAt(index, onLast: onLast);
  }

  /// The text-input action to show on a soft keyboard for the field at
  /// [index]: continue for anything but the last field, done on the last.
  TextInputAction getActionAt(int index) {
    return index + 1 < nodes.length
        ? TextInputAction.next
        : TextInputAction.done;
  }
}
