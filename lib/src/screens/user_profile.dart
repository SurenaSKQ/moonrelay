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

// TODO Text Styles

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.client, required this.userID});
  final String userID;
  final Client client;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.client.getProfileFromUserId(widget.userID),
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
                AppLocalizations.of(context)?.userProfilePageBanner(
                        asyncSnapshot.data?.displayName ?? "User") ??
                    "Profile View",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            body: ProfilePageContents(
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

class ProfilePageContents extends StatelessWidget {
  const ProfilePageContents({
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
          content: Text("The user has not set a display name!"),
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
              AvatarFromUriOrFallbackImage(
                client: client,
                avatarUri: userProfile.avatarUrl,
              ),
              const SizedBox(
                width: 16,
              ),
              Flexible(
                child: Text(
                  userProfile.displayName ?? userProfile.userId,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Text(
          "(${userProfile.userId})",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ],
    );
  }
}
