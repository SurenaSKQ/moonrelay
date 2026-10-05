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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/room_dates.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/encryption/user_devices_screen.dart';
import 'package:moonrelay/src/screens/room_details/top_members_section.dart';
import 'package:moonrelay/src/screens/room_details/top_threads_section.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/identity_header.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
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
    final room = widget.room;
    final isEncrypted = _isEncrypted(room);
    final roomType = _roomTypeLabel(room);
    final creationDate = _creationDate(room);

    final canonicalAlias =
        room.canonicalAlias.isNotEmpty ? room.canonicalAlias : null;

    final totalMembers = (room.summary.mInvitedMemberCount ?? 0) +
        (room.summary.mJoinedMemberCount ?? 0);

    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return MoonrelayInfoPage(
      title: l10n.roomInfoTitle,
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.copy),
          tooltip: l10n.copyRoomIdTooltip,
          onPressed: _copyRoomId,
        ),
      ],
      children: [
        IdentityHeader(
          name: room.getLocalizedDisplayname(),
          topic: room.topic,
          avatar: SizedBox(
            width: 64,
            height: 64,
            child: AvatarFromUriOrFallbackImage(
              client: room.client,
              avatarUri: room.avatar,
            ),
          ),
          chips: [
            InfoChip(
              icon: room.joinRules == JoinRules.public
                  ? LucideIcons.globe
                  : room.joinRules == JoinRules.knock ||
                          room.joinRules == JoinRules.knockRestricted
                      ? LucideIcons.doorOpen
                      : LucideIcons.lock,
              label: roomType,
            ),
            InfoChip(
              icon: LucideIcons.users,
              label: '$totalMembers ${l10n.members}',
            ),
            if (room.isDirectChat)
              InfoChip(
                icon: LucideIcons.userRound,
                label: l10n.directMessage,
              ),
            if (room.encrypted)
              InfoChip(
                icon: LucideIcons.shieldCheck,
                label: l10n.endToEndEncrypted,
                // The one chip on the page that is filled. Encryption is the
                // fact a reader came here to check, so it is the one chip
                // allowed to be louder than the rest.
                emphasis: true,
              ),
          ],
        ),

        const InfoSectionGap(first: true),

        // -- Actions ----------------------------------------------------
        // One panel for all of them. They were three separate bordered cards,
        // which read as three unrelated things rather than as the three things
        // you can do to a room.
        InfoPanel(
          title: l10n.actionsSection,
          children: [
            InfoPanelRow(
              icon: LucideIcons.settings,
              label: l10n.roomSettings,
              description: l10n.roomSettingsDescription,
              onTap: () => openRoomSubpage(context, room.id, 'settings'),
            ),
            InfoPanelRow(
              icon: LucideIcons.copy,
              label: l10n.copyRoomId,
              // The id under the label rather than beside it. Beside it, on a
              // 680px measure, the chevron and the value fought for the same
              // 220px and the id ellipsised on a page whose whole job is
              // showing you the id.
              description: room.id,
              valueFontFamily: MoonrelayTypography.mono(context),
              onTap: _copyRoomId,
            ),
            if (room.encrypted)
              InfoPanelRow(
                icon: LucideIcons.rotateCw,
                label: l10n.rotateMegolmSession,
                description: l10n.rotateMegolmSessionDescription,
                onTap: () => _rotateMegolmSession(context, room),
              ),
          ],
        ),

        const InfoSectionGap(),

        // -- Facts ------------------------------------------------------
        InfoPanel(
          title: l10n.detailsSection,
          children: [
            InfoPanelRow(
              label: l10n.typeLabel,
              value: roomType,
              icon: LucideIcons.tag,
            ),
            InfoPanelRow(
              label: l10n.encryptionLabel,
              value: isEncrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
              icon:
                  isEncrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            ),
            if (canonicalAlias != null)
              InfoPanelRow(
                label: l10n.addressLabel,
                value: canonicalAlias,
                icon: LucideIcons.hash,
              ),
            InfoPanelRow(
              label: l10n.roomIdLabel,
              value: room.id,
              icon: LucideIcons.fingerprint,
              valueFontFamily: MoonrelayTypography.mono(context),
            ),
            InfoPanelRow(
              label: l10n.createdLabel,
              value: creationDate,
              icon: LucideIcons.calendar,
            ),
          ],
        ),

        const InfoSectionGap(),

        // -- Security ---------------------------------------------------
        InfoPanel(
          title: l10n.securitySection,
          children: _securityRows(context, room, isEncrypted),
        ),

        const InfoSectionGap(),

        // -- People and threads ------------------------------------------
        InfoPanel(
          title: l10n.membersSection,
          padding: EdgeInsets.zero,
          children: [
            TopMembersSection(
              room: room,
              totalMembers: totalMembers,
            ),
          ],
        ),
        const InfoSectionGap(),

        InfoPanel(
          title: l10n.threads,
          padding: EdgeInsets.zero,
          children: [
            TopThreadsSection(room: room),
          ],
        ),
        SizedBox(height: t.spaceLg),
      ],
    );
  }

  /// The verification list for an encrypted room.
  ///
  /// Returns rows rather than widgets so the panel owns the hairlines between
  /// them. The previous version built its own [Column] with
  /// `InfoDetailRow`s that took no icon slot worth the name, which is why the
  /// member names appeared squeezed into a 100px column with an empty value
  /// beside them.
  List<Widget> _securityRows(
    BuildContext context,
    Room room,
    bool isEncrypted,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!isEncrypted) {
      return [
        InfoPanelRow(
          icon: LucideIcons.lockOpen,
          label: l10n.encryptionLabel,
          value: l10n.notEnabled,
        ),
      ];
    }

    final participants = room.getParticipants();
    final verified = participants
        .where((m) => m.id != room.client.userID)
        .toList(growable: false);
    // The threshold is the same ten the old list used, but it is now stated
    // where the reader is: a room with four hundred members shows a count and
    // a link instead of an implied "and 390 more".
    const listThreshold = 10;
    if (verified.length > listThreshold) {
      return [
        InfoPanelRow(
          icon: LucideIcons.shieldCheck,
          label: l10n.encryptionLabel,
          value: room.encryptionAlgorithm ?? 'Megolm',
        ),
        InfoPanelRow(
          icon: LucideIcons.users,
          label: l10n.showAllMembers(verified.length),
          value: '$listThreshold+',
          onTap: () => openRoomSubpage(context, room.id, 'members'),
        ),
      ];
    }

    return [
      InfoPanelRow(
        icon: LucideIcons.shieldCheck,
        label: l10n.encryptionLabel,
        value: room.encryptionAlgorithm ?? 'Megolm',
      ),
      for (final member in verified)
        InfoPanelRow(
          label: member.calcDisplayname(),
          leading: VerificationIconButton(
            userId: member.id,
            room: room,
          ),
        ),
    ];
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
