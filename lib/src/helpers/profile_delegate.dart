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
import 'package:moonrelay/src/screens/hub_screen.dart';
import 'package:moonrelay/src/screens/user_profile.dart';

class ProfileDelegate extends StatelessWidget {
  const ProfileDelegate({super.key, required this.userid});
  final String? userid;

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);
    if (userid == null) {
      log.e(
        "Profile page called with null user ID!",
        stackTrace: StackTrace.current,
        time: DateTime.now(),
      );
      // Schedule SnackBar after build to avoid "showSnackBar during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              children: [
                Text(AppLocalizations.of(context)!.error),
                Text(
                    "The User's ID could not be understood (userid==null),\n Please try again later , or report a bug to our project"),
              ],
            ),
          ),
        );
      });
      return const SizedBox.shrink();
    } else if (userid == client.userID) {
      // Redirect to the hub screen when viewing the user's own profile.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.pushReplacement('/main/myprofile');
      });
      return const SizedBox.shrink();
    } else {
      return ProfilePage(client: client, userID: userid!);
    }
  }
}
