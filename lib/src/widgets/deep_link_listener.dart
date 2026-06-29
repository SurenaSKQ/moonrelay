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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';
import 'package:moonrelay/src/services/deep_link_service.dart';
import 'package:provider/provider.dart';

/// Listens to the [DeepLinkService] and navigates to the target when a
/// matrix URI is received.
///
/// This widget must be placed inside the [MaterialApp.router] widget tree
/// so it has access to [GoRouter] via the context.
class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  @override
  void initState() {
    super.initState();
    _registerCallback();
  }

  void _registerCallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<DeepLinkService>();
      service.onMatrixUri = _handleUri;
    });
  }

  void _handleUri(MatrixUriResult result) {
    if (!mounted) return;
    final client = context.read<Client>();

    switch (result.entityType) {
      case MatrixUriEntity.room:
      case MatrixUriEntity.roomAlias:
        final room = client.getRoomById(result.entityId);
        if (room != null) {
          context.go('/main/rooms/${result.entityId}');
        } else {
          context.go('/main/room_preview/${result.entityId}');
        }
      case MatrixUriEntity.user:
        context.go('/main/rooms/${result.entityId}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
