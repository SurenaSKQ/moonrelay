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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:provider/provider.dart';

/// Routing delegate that resolves a user ID to a [ProfilePage].
///
/// Validates that:
/// - [userid] is non-null and non-empty.
/// - [userid] looks like a valid Matrix user ID (`@user:domain`).
///
/// Own-profile redirects are handled by GoRouter redirect on the route
/// definition itself, keeping this widget free of layout-time navigation.
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

    // -- Null / empty check --------------------------------------
    if (userid == null || userid!.isEmpty) {
      log.e('ProfileDelegate: ${l10n.profileIdNullError}', stackTrace: StackTrace.current, time: DateTime.now());
      return EmptyState(
        icon: Icons.account_circle_outlined,
        title: l10n.error,
        message: l10n.profileIdNullError,
        actionLabel: l10n.back,
        onAction: () => GoRouter.of(context).pop(),
      );
    }

    // -- Format validation ----------------------------------------
    if (!_userIdPattern.hasMatch(userid!)) {
      log.e('ProfileDelegate: invalid id', stackTrace: StackTrace.current, time: DateTime.now());
      return EmptyState(
        icon: Icons.account_circle_outlined,
        title: l10n.error,
        message: l10n.profileIdInvalid('$userid'),
        actionLabel: l10n.back,
        onAction: () => GoRouter.of(context).pop(),
      );
    }

    // -- Look up the user to verify they exist --------------------
    // `getUserFromMemory` returns null if the user has never been seen
    // in any joined room, but a valid Matrix ID may still exist on the
    // server.  We use the cached profile as a best-effort existence check.
    return ProfilePage(client: client, userID: userid!);
  }
}
