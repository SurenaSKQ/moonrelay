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

// TODO: Loading animations, handle different states, theming?
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:matrix/matrix.dart';

enum AvatarStates {
  inactive,
  active,
}

class AvatarFromUriOrFallbackImage extends StatefulWidget {
  const AvatarFromUriOrFallbackImage({
    super.key,
    required this.client,
    this.avatarUri,
    this.onTap,
    this.fallbackImage,
  });
  final Client client;
  final Uri? avatarUri;
  final VoidCallback? onTap;
  final AvatarStates avatarState = AvatarStates.active;
  final ImageProvider? fallbackImage;
  @override
  State<AvatarFromUriOrFallbackImage> createState() =>
      _AvatarFromUriOrFallbackImageState();
}

class _AvatarFromUriOrFallbackImageState
    extends State<AvatarFromUriOrFallbackImage> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: (widget.avatarUri == null)
          ? CircleAvatar(
              foregroundImage: AssetImage('assets/images/fallbackAvatar.png'))
          : FutureBuilder(
              future: widget.avatarUri!
                  .getThumbnailUri(widget.client, width: 56, height: 56),
              builder: (context, asyncSnapshot) {
                if (asyncSnapshot.connectionState != ConnectionState.done) {
                  return Builder(
                    builder: (context) => SpinKitCubeGrid(
                      color: FluentTheme.of(context).accentColor,
                    ),
                  );
                }
                return CircleAvatar(
                  foregroundImage: NetworkImage(asyncSnapshot.data.toString(),
                      headers: {
                        "authorization": "Bearer ${widget.client.accessToken}"
                      }),
                );
              }),
    );
  }
}
