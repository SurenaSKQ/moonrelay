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
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// Renders a `m.key.verification.request` event from the room timeline.
///
/// Shows the sender's name and, when the request targets the current user,
/// provides Accept / Decline buttons that integrate with the SDK's
/// [KeyVerification] flow (the same SAS emoji matching used in
/// [VerificationScreen]).
class VerificationRequestEvent extends StatelessWidget {
  const VerificationRequestEvent({
    super.key,
    required this.event,
    this.showTimestamp = true,
  });

  final Event event;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final client = context.read<Client>();
    final enc = context.read<EncryptionService>();
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final isFromSelf = event.senderId == client.userID;
    final ts = showTimestamp
        ? '  ${event.originServerTs.localizedTimeShort(context)}'
        : '';

    // Attempt to look up the KeyVerification object registered by the
    // SDK's KeyVerificationManager when it processed this event.
    final kv = _lookupKeyVerification(client);

    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: t.spaceXs + 2, horizontal: t.spaceMd),
      child: Card(
        color:
            scheme.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: t.spaceMd + 2, vertical: t.spaceMd - 2),
          child: Row(
            children: [
              Icon(LucideIcons.shieldQuestion,
                  size: t.iconSizeMedium, color: scheme.primary),
              SizedBox(width: t.spaceSm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.stateVerificationRequest(senderName),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (ts.isNotEmpty)
                      Text(
                        ts,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface
                              .withValues(alpha: t.opacitySubtle),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isFromSelf && kv != null) ...[
                SizedBox(width: t.spaceSm),
                FilledButton.tonalIcon(
                  icon: Icon(LucideIcons.check, size: t.iconSizeSmall),
                  label: Text(l10n.yesOrAffirmitive),
                  onPressed: () => _accept(context, kv, enc),
                ),
                SizedBox(width: t.spaceXs),
                OutlinedButton.icon(
                  icon: Icon(LucideIcons.x, size: t.iconSizeSmall),
                  label: Text(l10n.noOrCancellation),
                  onPressed: () => _decline(context, kv),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Looks up the [KeyVerification] object that the SDK's
  /// [KeyVerificationManager] created for this event's transaction.
  KeyVerification? _lookupKeyVerification(Client client) {
    final enc = client.encryption;
    if (enc == null) return null;

    final transactionId =
        KeyVerification.getTransactionId(event.content) ?? event.eventId;

    return enc.keyVerificationManager.getRequest(transactionId);
  }

  Future<void> _accept(
    BuildContext context,
    KeyVerification kv,
    EncryptionService enc,
  ) async {
    try {
      await kv.acceptVerification();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationScreen(request: kv, isIncoming: true),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.encryptionFailedAction('$e'))),
        );
      }
    }
  }

  Future<void> _decline(BuildContext context, KeyVerification kv) async {
    try {
      await kv.cancel();
    } catch (_) {
      // best-effort
    }
  }
}
