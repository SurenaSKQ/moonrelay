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
import 'package:matrix/matrix.dart';

/// An avatar that loads from a Matrix content URI with a themed placeholder
/// while the thumbnail URL resolves and the image downloads.
///
/// When [avatarUri] is `null` a generic person icon is shown instead.
class AvatarFromUriOrFallbackImage extends StatelessWidget {
  const AvatarFromUriOrFallbackImage({
    super.key,
    required this.client,
    this.avatarUri,
    this.onTap,
    this.radius,
  });

  final Client client;
  final Uri? avatarUri;
  final VoidCallback? onTap;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: avatarUri == null
          ? CircleAvatar(
              radius: radius,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            )
          : FutureBuilder<Uri>(
              future: avatarUri!.getThumbnailUri(
                client,
                width: 56,
                height: 56,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return CircleAvatar(
                    radius: radius,
                    backgroundImage: NetworkImage(
                      snapshot.data.toString(),
                      headers: {
                        'authorization': 'Bearer ${client.accessToken}',
                      },
                    ),
                  );
                }
                // Themed placeholder while the thumbnail URL resolves.
                return CircleAvatar(
                  radius: radius,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                );
              },
            ),
    );
  }
}
