// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <http://www.gnu.org/licenses/>.

// TODO: Loading animations, handle different states, theming?
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

enum AvatarStates {
  inactive,
  active,
}

class DynamicAvatarWidget extends StatefulWidget {
  const DynamicAvatarWidget({
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
  State<DynamicAvatarWidget> createState() => _DynamicAvatarWidgetState();
}

class _DynamicAvatarWidgetState extends State<DynamicAvatarWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: CircleAvatar(
        foregroundImage: widget.avatarUri == null
            // TODO: Default Icon!
            ? widget.fallbackImage
            : NetworkImage(
                widget.avatarUri!
                    .getThumbnail(
                      widget.client,
                      width: 56,
                      height: 56,
                    )
                    .toString(),
              ),
      ),
    );
  }
}
