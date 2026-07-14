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

// Compact "encrypted room" indicator used in `RoomsPane`.
//
// Note: a separate `EncryptionBadge` class already lives in
// `lib/src/widgets/encryption/trust_indicator.dart` for the chat
// timeline.  This widget is the list-side counterpart; it always
// renders the shield-check (or nothing) so users can spot encrypted
// rooms at a glance.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// A compact badge that signals whether a room is end-to-end encrypted.
class RoomEncryptionBadge extends StatelessWidget {
  const RoomEncryptionBadge({super.key, required this.room, this.size = 14});

  final Room? room;
  final double size;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final encrypted = _isEncrypted();
    if (!encrypted) return const SizedBox.shrink();

    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8FE3B0)
        : const Color(0xFF15803D);

    // [Semantics] instead of [Tooltip]: this badge is rendered inside
    // the dashboard's [LayoutBuilder] shell (RoomsPane row entries
    // and the room-header bar). A Tooltip mounts an internal
    // [OverlayPortal] that activates on mount and would mark a
    // sibling [_RenderLayoutBuilder] as needing layout mid-
    // performLayout, tripping the
    // `_RenderLayoutBuilder was mutated in performLayout` assertion.
    // Semantics provides the same accessibility label without
    // materialising an overlay entry. The Icon's `semanticLabel`
    // is preserved so screen-reader output matches what the Tooltip
    // would have announced.
    return Icon(
      LucideIcons.shieldCheck,
      size: size,
      color: color,
      semanticLabel: loc.encryptionBadgeTooltip,
    );
  }

  bool _isEncrypted() {
    final r = room;
    if (r == null) return false;
    try {
      // Matrix SDK exposes `Room.encrypted`; a try/catch defends
      // against disposed clients and edge-case getters during room
      // teardown.
      return r.encrypted;
    } catch (_) {
      return false;
    }
  }
}
