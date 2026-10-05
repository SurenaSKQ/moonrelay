// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

class UnjoinedRoomTile extends StatefulWidget {
  const UnjoinedRoomTile({
    super.key,
    required this.child,
    required this.client,
    required this.l10n,
  });

  final dynamic child;
  final Client client;
  final AppLocalizations l10n;

  @override
  State<UnjoinedRoomTile> createState() => UnjoinedRoomTileState();
}

class UnjoinedRoomTileState extends State<UnjoinedRoomTile> {
  /// The room summary fetched from the server.
  ///
  /// Null while loading or if the fetch failed.
  GetRoomSummaryResponse$3? _summary;
  bool _loading = true;

  String get _roomId => (widget.child.roomId as String?) ?? '?';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await widget.client.getRoomSummary(_roomId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    final isSuggested = widget.child.suggested == true;

    final displayName = _loading
        ? _roomId
        : (_summary?.name?.isNotEmpty == true
            ? _summary!.name!
            : _summary?.canonicalAlias ?? _roomId);

    final avatarUri = _summary?.avatarUrl;
    // Monospace only while the id is all we have. Once a real name arrives it
    // is a name, and a monospace name is a small shout.
    final showingIdOnly = _loading || _summary?.name?.isNotEmpty != true;

    // A row rather than a bordered card: this sits in a panel with the
    // resolved children, and a card here made the preview rooms look like a
    // different kind of thing from the rooms you are actually in, which is
    // precisely the distinction the section heading is there to draw.
    return InkWell(
      onTap: () => context.push('/main/room_preview/$_roomId'),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spaceLg,
          vertical: t.spaceSm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: ext.components.avatar.sizeMedium / 2,
              backgroundColor: scheme.primaryContainer
                  .withValues(alpha: t.opacitySubtle),
              backgroundImage: avatarUri != null
                  ? NetworkImage(
                      avatarUri.toString(),
                      headers: authHeaders(widget.client),
                    )
                  : null,
              onBackgroundImageError: avatarUri != null ? (_, __) {} : null,
              child: avatarUri == null
                  ? Icon(
                      LucideIcons.hash,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    )
                  : null,
            ),
            SizedBox(width: t.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                      fontFamily: showingIdOnly ? 'JetBrainsMono' : null,
                    ),
                  ),
                  if (isSuggested) ...[
                    SizedBox(height: t.spaceXxs),
                    Text(
                      widget.l10n.roomPreviewSuggested,
                      style: TextStyle(fontSize: 12, color: scheme.tertiary),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: t.spaceSm),
            // The whole row already navigates, so this button is a labelled
            // duplicate of the tap target. It exists because "Preview" says
            // what will happen and a chevron does not, and because a row of
            // chevrons with no words makes a screen reader announce the same
            // thing thirty times.
            Text(
              widget.l10n.roomPreviewView,
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
