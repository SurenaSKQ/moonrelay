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
import 'package:logger/logger.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// How long a transient confirmation snackbar stays up.
///
/// Used for the "copied to clipboard" family, where the message is purely
/// informational and the user is still doing something else. Anything that
/// reports a failure or a state change keeps the default duration so the
/// user has time to read it.
const Duration kFeedbackDuration = Duration(seconds: 2);

/// How long a snackbar stays up when the caller has no opinion.
///
/// Mirrors the Material default. [SnackBar.duration] is not nullable, so a
/// helper that wants "use whatever the framework thinks is right" has to
/// name a value; this is that value.
const Duration kDefaultFeedbackDuration = Duration(seconds: 4);

/// Snackbar helpers that fold in the `mounted` guard every async UI action
/// needs.
///
/// The pattern this replaces is repeated verbatim a few hundred times across
/// the app: `try`, `await` something, check the context is still alive, show a
/// `SnackBar`, then repeat the whole thing in the `catch`. Writing it by hand
/// is easy, easy to get subtly wrong (a missing guard after the first `await`
/// throws in debug and silently does nothing in release), and impossible to
/// read at a glance once it is four levels deep inside a callback.
extension FeedbackContext on BuildContext {
  /// Shows [text] in a snackbar.
  ///
  /// Returns without touching the messenger if the context has been torn
  /// down, so callers on the far side of an `await` do not need their own
  /// guard. Errors go through the theme's error colour so the user can tell
  /// them apart from confirmations at a glance.
  ///
  /// Snackbars are docked rather than floating by default, which is what
  /// most of the app uses; pass [floating] where a screen has already
  /// settled on the floating look.
  void showMessage(
    String text, {
    bool isError = false,
    bool floating = false,
    Duration? duration,
  }) {
    if (!mounted) return;
    final scheme = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: isError ? TextStyle(color: scheme.onErrorContainer) : null,
        ),
        backgroundColor: isError ? scheme.errorContainer : null,
        behavior: floating
            ? SnackBarBehavior.floating
            : SnackBarBehavior.fixed,
        duration: duration ?? kDefaultFeedbackDuration,
      ),
    );
  }

  /// Runs [action], then reports the outcome as a snackbar.
  ///
  /// On success [successMessage] is shown, unless it is `null`, which is how
  /// an action that is its own feedback (the timeline redrawing behind it,
  /// say) opts out of a confirmation. On failure the exception is rendered
  /// through [formatError] and shown as an error. Returns whether the action
  /// completed, so callers that need to branch afterwards can use the result
  /// instead of a second `mounted` check.
  ///
  /// Both snackbars are suppressed if the context died while [action] was in
  /// flight, which is the common case for a user who navigates away mid-send.
  Future<bool> showActionResult({
    required Future<void> Function() action,
    required String? successMessage,
    String Function(Object error)? formatError,
    bool floating = false,
    Duration? duration,
    Logger? log,
    String logLabel = 'action',
  }) async {
    try {
      await action();
      if (successMessage != null) {
        showMessage(successMessage, floating: floating, duration: duration);
      }
      return true;
    } catch (e) {
      log?.w('Failed to $logLabel', error: e);
      showMessage(
        formatError?.call(e) ?? AppLocalizations.of(this)!.actionFailed('$e'),
        isError: true,
        floating: floating,
        duration: duration,
      );
      return false;
    }
  }

  /// Asks the user to confirm a destructive action, returning `true` only on
  /// an explicit yes.
  ///
  /// Returns `false` without showing a dialog when the context is already
  /// gone. [confirmLabel] defaults to the destructive word the dialog title
  /// is built from, so the button never reads "OK" on a delete flow.
  Future<bool> confirmDestructive({
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
  }) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(this)!;
    final result = await showDialog<bool>(
      context: this,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel ?? l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
