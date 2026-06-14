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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// A small icon that indicates the encryption state of a room (encrypted or
/// not, trust level redacted).
class EncryptionBadge extends StatelessWidget {
  const EncryptionBadge({
    super.key,
    required this.room,
    this.size = 16,
  });

  final Room room;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final encrypted = room.encrypted;

    return Tooltip(
      message: encrypted ? l10n.encryptedTooltip : l10n.notEncryptedTooltip,
      child: Icon(
        encrypted ? LucideIcons.lock : LucideIcons.lockOpen,
        size: size,
        color: encrypted ? scheme.primary : scheme.outline,
      ),
    );
  }
}

/// Shows a trust indicator (shield) for a message sender.
///
/// Place this next to a message to indicate whether the sender is verified
/// via cross-signing.
class TrustIndicator extends StatelessWidget {
  const TrustIndicator({
    super.key,
    required this.isVerified,
    this.size = 14,
  });

  final bool isVerified;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (!isVerified) {
      return Tooltip(
        message: l10n.unverifiedTooltip,
        child: Icon(
          LucideIcons.shieldOff,
          size: size,
          color: scheme.error.withValues(alpha: 0.6),
        ),
      );
    }

    return Tooltip(
      message: l10n.verifiedTooltip,
      child: Icon(
        LucideIcons.shieldCheck,
        size: size,
        color: scheme.primary,
      ),
    );
  }
}

/// Shows the current encryption status of a room with a colored badge and
/// a short description (enabled/disabled/not supported).
class RoomEncryptionStatus extends StatelessWidget {
  const RoomEncryptionStatus({
    super.key,
    required this.room,
  });

  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    final enc = room.encrypted;
    final algo = room.encryptionAlgorithm;

    return ListTile(
      leading: Icon(
        enc ? LucideIcons.lock : LucideIcons.lockOpen,
        color: enc ? scheme.primary : scheme.outline,
      ),
      title: Text(
        enc ? loc.encryptionEnabledTitle : loc.encryptionNotEnabledTitle,
      ),
      subtitle:
          enc && algo != null ? Text(algo) : Text(loc.encryptionStatusInfo),
    );
  }
}

/// Renders an encrypted event placeholder when the event failed to decrypt.
class DecryptionFailedWidget extends StatelessWidget {
  const DecryptionFailedWidget({
    super.key,
    required this.event,
    this.canRequestSession = false,
  });

  final Event event;
  final bool canRequestSession;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lock, color: scheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.encryptionDecryptionFailed,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.body.isNotEmpty)
                  Text(
                    event.body,
                    style: TextStyle(
                      color: scheme.onErrorContainer.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (canRequestSession)
            IconButton(
              icon: Icon(LucideIcons.refreshCw, color: scheme.error),
              tooltip: loc.encryptionRequestKeys,
              onPressed: () {
                _requestMissingKeys(context, event);
              },
            ),
        ],
      ),
    );
  }

  void _requestMissingKeys(BuildContext context, Event event) {
    final client = event.room.client;
    final enc = client.encryption;
    if (enc == null) return;

    try {
      final content = event.parsedRoomEncryptedContent;
      final sessionId = content.sessionId;
      if (sessionId == null) return;

      enc.keyManager.maybeAutoRequest(
        event.room.id,
        sessionId,
        content.senderKey,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.encryptionKeysRequested,
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
    }
  }
}
