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
import 'package:flutter/services.dart';
import 'package:moonrelay/src/screens/room_details/top_threads_section.dart';
import 'package:moonrelay/src/screens/room_details/top_members_section.dart';
import 'package:moonrelay/src/screens/room_details/room_identity_card.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/room_dates.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/screens/encryption/user_devices_screen.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// A full room information page built with Material 3 design tokens.
///
/// Displays:
/// - Room avatar, display name, topic, and room ID
/// - Room actions (leave room, copy ID, open in browser)
/// - Room details (type, encryption, creation date, canonical alias)
/// - Top members (by power level) with a "Load all members" button
///
/// The page wraps its scrolled content in a [Scaffold] so it works both as a
/// pushed route and as an embedded page on wide screens.
class RoomInformations extends StatefulWidget {
  const RoomInformations({super.key, required this.room});

  final Room room;

  @override
  State<RoomInformations> createState() => _RoomInformationsState();
}

class _RoomInformationsState extends State<RoomInformations> {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Human-friendly room type label.
  String _roomTypeLabel(Room room) {
    final l10n = AppLocalizations.of(context)!;
    if (room.isDirectChat) return l10n.directMessage;
    if (room.isSpace) return l10n.spaceType;
    return switch (room.joinRules) {
      JoinRules.public => l10n.publicRoom,
      JoinRules.knock || JoinRules.knockRestricted => l10n.roomTypeKnock,
      JoinRules.restricted => l10n.roomTypeRestricted,
      JoinRules.invite || JoinRules.private => l10n.roomTypeInviteOnly,
      null => l10n.publicRoom,
    };
  }

  /// Whether the room is encrypted.
  bool _isEncrypted(Room room) {
    try {
      return room.encrypted;
    } catch (_) {
      return false;
    }
  }

  /// Friendly creation date string.
  String _creationDate(Room room) {
    final created = roomCreatedAt(room);
    if (created == null) return AppLocalizations.of(context)!.unknownDate;
    return formatIsoDay(created);
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: widget.room.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.roomIdCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Asks for confirmation, then rotates the room's outbound megolm
  /// session.  All current room members will receive a fresh
  /// `m.room_key` to-device event the next time this client sends a
  /// message; their old (already-encrypted) history remains readable
  /// because they still hold the previous session keys.
  Future<void> _rotateMegolmSession(BuildContext context, Room room) async {
    final l10n = AppLocalizations.of(context)!;
    final enc = context.read<EncryptionService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rotateMegolmSession),
        content: Text(l10n.rotateMegolmSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.rotateMegolmSession),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final ok = await enc.rotateMegolmSession(room);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.rotateMegolmSessionDone : l10n.rotateMegolmSessionFailed,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Room editing helpers
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Room deletion / forgetting
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final room = widget.room;
    final isEncrypted = _isEncrypted(room);
    final roomType = _roomTypeLabel(room);
    final creationDate = _creationDate(room);

    final canonicalAlias =
        room.canonicalAlias.isNotEmpty ? room.canonicalAlias : null;

    final totalMembers = (room.summary.mInvitedMemberCount ?? 0) +
        (room.summary.mJoinedMemberCount ?? 0);

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.roomInfoTitle,
          style: textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: l10n.copyRoomIdTooltip,
            onPressed: _copyRoomId,
          ),
        ],
      ),
      body: ListView(
        padding:
            EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceSm),
        children: [
          // -- Room identity card ----------------------------------------
          RoomIdentityCard(
            room: room,
            roomType: roomType,
            totalMembers: totalMembers,
            scheme: scheme,
            textTheme: textTheme,
          ),
          SizedBox(height: t.spaceLg),

          // -- Room actions ---------------------------------------------
          InfoSectionHeader(title: l10n.actionsSection, scheme: scheme),
          SizedBox(height: t.spaceSm),
          InfoActionTile(
            icon: LucideIcons.settings,
            label: l10n.roomSettings,
            description: l10n.roomSettingsDescription,
            onTap: () => openRoomSubpage(context, room.id, 'settings'),
            scheme: scheme,
          ),
          InfoActionTile(
            icon: LucideIcons.copy,
            label: l10n.copyRoomId,
            description: room.id,
            onTap: _copyRoomId,
            scheme: scheme,
          ),
          if (room.encrypted)
            InfoActionTile(
              icon: LucideIcons.rotateCw,
              label: l10n.rotateMegolmSession,
              description: l10n.rotateMegolmSessionDescription,
              onTap: () => _rotateMegolmSession(context, room),
              scheme: scheme,
            ),

          SizedBox(height: t.spaceLg),

          // -- Room details ---------------------------------------------
          InfoSectionHeader(title: l10n.detailsSection, scheme: scheme),
          SizedBox(height: t.spaceSm),
          InfoDetailRow(
            icon: room.joinRules == JoinRules.public
                ? LucideIcons.globe
                : room.joinRules == JoinRules.knock ||
                        room.joinRules == JoinRules.knockRestricted
                    ? LucideIcons.logIn
                    : LucideIcons.lock,
            label: l10n.typeLabel,
            value: roomType,
            scheme: scheme,
          ),
          InfoDetailRow(
            icon: isEncrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            label: l10n.encryptionLabel,
            value: isEncrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            scheme: scheme,
          ),
          if (canonicalAlias != null)
            InfoDetailRow(
              icon: LucideIcons.hash,
              label: l10n.addressLabel,
              value: canonicalAlias,
              scheme: scheme,
            ),
          InfoDetailRow(
            icon: LucideIcons.calendar,
            label: l10n.createdLabel,
            value: creationDate,
            scheme: scheme,
          ),
          SizedBox(height: t.spaceLg),

          // -- Security -------------------------------------------------
          InfoSectionHeader(title: l10n.securitySection, scheme: scheme),
          SizedBox(height: t.spaceSm),
          _buildSecuritySection(context, scheme, room, isEncrypted),
          SizedBox(height: t.spaceLg),

          // -- Top members ----------------------------------------------
          InfoSectionHeader(title: l10n.membersSection, scheme: scheme),
          SizedBox(height: t.spaceSm),
          TopMembersSection(
            room: room,
            totalMembers: totalMembers,
            scheme: scheme,
          ),
          SizedBox(height: t.spaceLg),

          // -- Threads -------------------------------------------------
          InfoSectionHeader(title: l10n.threads, scheme: scheme),
          SizedBox(height: t.spaceSm),
          TopThreadsSection(
            room: room,
            scheme: scheme,
          ),
          SizedBox(height: t.spaceLg),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(
    BuildContext context,
    ColorScheme scheme,
    Room room,
    bool isEncrypted,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!isEncrypted) {
      return InfoDetailRow(
        icon: LucideIcons.lockOpen,
        label: l10n.encryptionLabel,
        value: l10n.notEnabled,
        scheme: scheme,
      );
    }
    final participants = room.getParticipants();

    return Column(
      children: [
        InfoDetailRow(
          icon: LucideIcons.shieldCheck,
          label: l10n.encryptionLabel,
          value: room.encryptionAlgorithm ?? 'Megolm',
          scheme: scheme,
        ),
        if (participants.length <= 10)
          ...participants.map((member) {
            if (member.id == room.client.userID) return const SizedBox.shrink();
            return InfoDetailRow(
              icon: LucideIcons.user,
              label: member.calcDisplayname(),
              value: '',
              trailing: VerificationIconButton(
                userId: member.id,
                room: room,
              ),
              scheme: scheme,
            );
          }),
      ],
    );
  }
}

// =============================================================================

class VerificationIconButton extends StatelessWidget {
  const VerificationIconButton({
    super.key,
    required this.userId,
    required this.room,
  });

  final String userId;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final enc = context.watch<EncryptionService>();
    final isUserVerified = enc.isUserVerifiedById(userId);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        isUserVerified ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
        size: 18,
        color: isUserVerified ? scheme.primary : scheme.error,
      ),
      tooltip: isUserVerified ? l10n.userIsVerified : l10n.userIsNotVerified,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserDevicesScreen(userId: userId),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Internal widgets
// =============================================================================

/// A small chip used for room metadata badges.

/// A section header label.

/// A tappable action row.

/// A read-only detail row with icon, label, and value.

// =============================================================================
// Top members section
// =============================================================================

// =============================================================================
// Top threads section
// =============================================================================

// =============================================================================
// Member tile (reused in both top members and full list)
// =============================================================================
