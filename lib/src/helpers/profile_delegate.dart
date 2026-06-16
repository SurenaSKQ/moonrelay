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
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/user_profile.dart';

/// Routing delegate that resolves a user ID to a [ProfilePage].
///
/// Validates that:
/// - [userid] is non-null and non-empty.
/// - [userid] looks like a valid Matrix user ID (`@user:domain`).
/// - If the provided ID matches the logged-in user, redirects to the
///   hub screen instead of opening a self-profile.
///
/// If validation fails, an error is logged and a snackbar is shown.
class ProfileDelegate extends StatelessWidget {
  const ProfileDelegate({super.key, required this.userid});
  final String? userid;

  /// Valid Matrix user IDs start with `@` and contain a `:` (server part).
  static final _userIdPattern = RegExp(r'^@.+:.+');

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // ── Null / empty check ──────────────────────────────────────
    if (userid == null || userid!.isEmpty) {
      _showError(context, log, l10n.profileIdNullError);
      return const SizedBox.shrink();
    }

    // ── Format validation ────────────────────────────────────────
    if (!_userIdPattern.hasMatch(userid!)) {
      _showError(context, log, l10n.profileIdInvalid('$userid'));
      return const SizedBox.shrink();
    }

    // ── Own profile → redirect to hub ───────────────────────────
    if (userid == client.userID) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.pushReplacement('/main/myprofile');
      });
      return const SizedBox.shrink();
    }

    // ── Look up the user to verify they exist ────────────────────
    // `getUserFromMemory` returns null if the user has never been seen
    // in any joined room, but a valid Matrix ID may still exist on the
    // server.  We use the cached profile as a best-effort existence check.
    return ProfilePage(client: client, userID: userid!);
  }

  void _showError(BuildContext context, Logger log, String message) {
    log.e(
      'ProfileDelegate: $message',
      stackTrace: StackTrace.current,
      time: DateTime.now(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.error),
              Text(message),
            ],
          ),
        ),
      );
    });
  }
}
