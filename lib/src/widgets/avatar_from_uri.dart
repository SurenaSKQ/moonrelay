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
import 'package:moonrelay/src/helpers/async_utils.dart';

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
    final displaySize = ((radius ?? 20) * 2).round();

    return GestureDetector(
      onTap: onTap,
      child: avatarUri == null
          ? _placeholder(theme)
          : FutureBuilder<Uri>(
              future: withTimeoutOrFallback(
                () => avatarUri!.getThumbnailUri(
                  client,
                  width: displaySize,
                  height: displaySize,
                ),
                timeout: kDefaultTimeout,
                fallback: avatarUri!,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _avatarWithErrorHandling(
                    context,
                    theme,
                    snapshot.data.toString(),
                  );
                }
                // Themed placeholder while the thumbnail URL resolves.
                return _placeholder(theme);
              },
            ),
    );
  }

  /// Placeholder avatar shown when no URI is available or while loading.
  Widget _placeholder(ThemeData theme) => CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );

  /// Avatar with a network image that gracefully handles load failures
  /// (e.g. empty files returned by the server).
  Widget _avatarWithErrorHandling(
    BuildContext context,
    ThemeData theme,
    String imageUrl,
  ) {
    final avatarRadius = radius ?? 20.0;

    return CircleAvatar(
      radius: avatarRadius,
      backgroundImage: NetworkImage(
        imageUrl,
        headers: {
          'authorization': 'Bearer ${client.accessToken}',
        },
      ),
      backgroundColor: theme.colorScheme.primaryContainer,
      onBackgroundImageError: (_, __) {},
    );
  }
}
