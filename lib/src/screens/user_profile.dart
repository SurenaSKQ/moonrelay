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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/show_error_infobar.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.client, required this.userID});
  final String userID;
  final Client client;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Profile uprofile;

  Future<void> _getUserProfile() async {
    uprofile = await widget.client.getProfileFromUserId(widget.userID);
    setState(() {});
  }

  @override
  void initState() {
    _getUserProfile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Acrylic(
        child: ScaffoldPage(
          header: ProfilePageheaderBar(
            username: uprofile.displayName,
          ),
          content: ProfilePageContents(
            client: widget.client,
            userProfile: uprofile,
          ),
        ),
      );
    } catch (e) {
      final Logger log = Provider.of<Logger>(context, listen: false);
      log.w(
        "Method 'client.getProfileFromuserId' has failed! Probably loading data",
        error: e,
        stackTrace: StackTrace.current,
        time: DateTime.now(),
      );
      return const LoadingAndTransitionScreen();
    }
  }
}

class ProfilePageheaderBar extends StatelessWidget {
  const ProfilePageheaderBar({super.key, required this.username});
  final String? username;
  @override
  Widget build(BuildContext context) {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () => context.pop(),
      ),
      title: Text(
        AppLocalizations.of(context)
                ?.userProfilePageBanner(username ?? "User") ??
            "Profile View",
        style: FluentTheme.of(context).typography.bodyLarge,
      ),
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
      showErrorInfobar(context, "The user has not set a display name!", "");
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
                  style: FluentTheme.of(context).typography.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(
          direction: Axis.horizontal,
        ),
        Text(
          "(${userProfile.userId})",
          style: FluentTheme.of(context).typography.subtitle,
        ),
      ],
    );
  }
}
