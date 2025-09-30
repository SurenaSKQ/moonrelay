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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

// FIXME this entire widget is a disaster
class OwnProfilePage extends StatefulWidget {
  const OwnProfilePage({super.key, required this.client});
  final Client client;
  @override
  State<OwnProfilePage> createState() => _OwnProfilePageState();
}

class _OwnProfilePageState extends State<OwnProfilePage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.client.getProfileFromUserId(widget.client.userID!),
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                asyncSnapshot.error.toString(),
              ),
            ),
          );
        }
        if (asyncSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.pop(),
              ),
              title: Text(
                AppLocalizations.of(context)?.ownProfileDescriptor ??
                    "Your Profile",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
            ),
            body: OwnProfilePageContent(
              client: widget.client,
              userProfile: asyncSnapshot.data!,
            ),
          );
        } else {
          return LoadingScreen();
        }
      },
    );
  }
}

class OwnProfilePageContent extends StatelessWidget {
  const OwnProfilePageContent({
    super.key,
    required this.client,
    required this.userProfile,
  });

  final Profile userProfile;
  final Client client;

  @override
  Widget build(BuildContext context) {
    if (userProfile.displayName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You have not set a display name!"),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              userProfile.avatarUrl == null
                  ? Text(
                      userProfile.displayName!
                          .toUpperCase()
                          .split(RegExp(' +'))
                          .map((s) => s[0])
                          .take(2)
                          .join(),
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    )
                  : AvatarFromUriOrFallbackImage(
                      client: client,
                      avatarUri: userProfile.avatarUrl,
                    ),
              const SizedBox(
                width: 16,
              ),
              Text(
                userProfile.displayName ?? userProfile.userId,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(),
        Text(
          "(${userProfile.userId})",
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
