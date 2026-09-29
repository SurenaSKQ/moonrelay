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

/// Renders the profile page for [userId], or an error state if the id is
/// not a Matrix user ID.
///
/// This replaces `ProfileDelegate`, which took a *nullable* id and treated
/// a null as an error. That conflated two unrelated things: "this route has
/// no user id, use the signed-in one" (which is what `/main/myprofile`
/// meant) and "this route is malformed". The first became an error card on
/// the user's own profile page. The router now resolves the id before
/// calling this, so [userId] is always present and always deliberate.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.userId});

  /// The Matrix user ID to show, already percent-decoded by the caller.
  final String userId;

  /// Valid Matrix user IDs start with `@` and contain a `:` (server part).
  static final RegExp _userIdPattern = RegExp(r'^@.+:.+');

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    if (!_userIdPattern.hasMatch(userId)) {
      log.e('ProfileView: invalid id "$userId"',
          stackTrace: StackTrace.current, time: DateTime.now());
      return EmptyState(
        icon: Icons.account_circle_outlined,
        title: l10n.error,
        message: l10n.profileIdInvalid(userId),
        actionLabel: l10n.back,
        onAction: () => GoRouter.of(context).pop(),
      );
    }

    // No existence check here on purpose: `getUserFromMemory` only knows
    // about users seen in a joined room, and a perfectly valid ID from a
    // link would then look broken. `ProfilePage` already renders its own
    // error state when the fetch fails.
    return ProfilePage(client: client, userID: userId);
  }
}
