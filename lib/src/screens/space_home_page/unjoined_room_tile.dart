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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

class UnjoinedRoomTile extends StatefulWidget {
  const UnjoinedRoomTile({
    super.key,
    required this.child,
    required this.client,
    required this.scheme,
    required this.l10n,
  });

  final dynamic child;
  final Client client;
  final ColorScheme scheme;
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
    final isSuggested = widget.child.suggested == true;

    final displayName = _loading
        ? _roomId
        : (_summary?.name?.isNotEmpty == true
            ? _summary!.name!
            : _summary?.canonicalAlias ?? _roomId);

    final avatarUri = _summary?.avatarUrl;

    return Card(
      elevation: t.elevationNone,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(
            color: widget.scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: ext.components.avatar.sizeMedium / 2,
          backgroundColor:
              widget.scheme.primaryContainer.withValues(alpha: t.opacitySubtle),
          backgroundImage:
              avatarUri != null ? NetworkImage(avatarUri.toString()) : null,
          onBackgroundImageError: avatarUri != null ? (_, __) {} : null,
          child: avatarUri == null
              ? Icon(
                  LucideIcons.hash,
                  size: 18,
                  color: widget.scheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: _loading || _summary?.name?.isNotEmpty != true
                ? 'JetBrainsMono'
                : null,
            fontSize:
                _loading || _summary?.name?.isNotEmpty != true ? 13 : null,
          ),
        ),
        subtitle: isSuggested
            ? Text(
                widget.l10n.roomPreviewSuggested,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.scheme.tertiary,
                ),
              )
            : null,
        trailing: FilledButton.tonal(
          onPressed: () => context.push('/main/room_preview/$_roomId'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            widget.l10n.roomPreviewView,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
