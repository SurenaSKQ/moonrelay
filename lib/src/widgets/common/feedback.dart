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

import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a floating snackbar with a brief message.
/// Safe to call from inside async continuations (guards [context.mounted]).
void showFloatingSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Shows a floating error snackbar.
void showErrorSnackBar(BuildContext context, String message) {
  showFloatingSnackBar(context, message);
}

/// Shows a floating success snackbar.
void showSuccessSnackBar(BuildContext context, String message) {
  showFloatingSnackBar(context, message);
}

/// Executes [action] and shows a snackbar with [successMessage] on success
/// or an error snackbar on failure. Guards [context.mounted] throughout.
Future<void> runWithSnackbar(
  BuildContext context, {
  required Future<void> Function() action,
  String? successMessage,
  String? errorPrefix,
}) async {
  try {
    await action();
    if (!context.mounted) return;
    if (successMessage != null) {
      showFloatingSnackBar(context, successMessage);
    }
  } catch (e) {
    if (!context.mounted) return;
    showFloatingSnackBar(context, '$errorPrefix$e');
  }
}

/// Shows a confirmation dialog and invokes [onConfirmed] if the user
/// accepts. Safely guards [context.mounted] after the dialog and after
/// the async gap.
Future<void> confirmAndRun(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  required Future<void> Function() onConfirmed,
  String? successMessage,
  String? errorPrefix,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await runWithSnackbar(
    context,
    action: onConfirmed,
    successMessage: successMessage,
    errorPrefix: errorPrefix,
  );
}
