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
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:provider/provider.dart';

/// Shows the devices of another user in a room, with trust status.
class UserDevicesScreen extends StatelessWidget {
  const UserDevicesScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    final enc = context.watch<EncryptionService>();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final client = context.read<Client>();

    // Use cached device keys from the SDK.
    final userKeys = client.userDeviceKeys[userId];
    final devices = userKeys?.deviceKeys.values.toList() ?? [];

    final isUserVerified = userKeys?.masterKey?.verified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.encryptionDevices}  $userId'),
        actions: [
          if (!isUserVerified)
            TextButton.icon(
              icon: const Icon(LucideIcons.shieldCheck, size: 18),
              label: Text(loc.encryptionVerifyUser),
              onPressed: () => _requestVerification(context, enc, userId),
            ),
        ],
      ),
      body: devices.isEmpty
          ? Center(child: Text(loc.encryptionNoDevices))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length + 1, // +1 for user-level header
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _UserTrustHeader(
                    userId: userId,
                    isVerified: isUserVerified,
                    onVerify: !isUserVerified
                        ? () => _requestVerification(context, enc, userId)
                        : null,
                  );
                }
                final deviceKey = devices[index - 1];
                final isVerified = deviceKey.verified;

                return ListTile(
                  leading: Icon(
                    isVerified
                        ? LucideIcons.shieldCheck
                        : LucideIcons.shieldOff,
                    color: isVerified ? scheme.primary : scheme.error,
                  ),
                  title: Text(deviceKey.deviceId ?? loc.encryptionNoKeyInfo),
                  subtitle: Text(
                    () {
                      final key = deviceKey.ed25519Key;
                      if (key != null && key.isNotEmpty) {
                        return 'Ed25519: ${key.substring(0, 8)}…';
                      }
                      return loc.encryptionNoKeyInfo;
                    }(),
                  ),
                  trailing: _TrustBadge(verified: isVerified),
                );
              },
            ),
    );
  }

  void _requestVerification(
    BuildContext context,
    EncryptionService enc,
    String userId,
  ) async {
    try {
      final req = await enc.requestVerification(userId);
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            request: req,
          ),
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
}

class _UserTrustHeader extends StatelessWidget {
  const _UserTrustHeader({
    required this.userId,
    required this.isVerified,
    this.onVerify,
  });

  final String userId;
  final bool isVerified;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Card(
      child: ListTile(
        leading: Icon(
          isVerified ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
          color: isVerified ? scheme.primary : scheme.error,
          size: 32,
        ),
        title: Text(
          isVerified
              ? loc.encryptionUserVerified
              : loc.encryptionUserNotVerified,
        ),
        subtitle: Text(userId),
        trailing: onVerify != null
            ? FilledButton.tonalIcon(
                icon: const Icon(LucideIcons.verified, size: 18),
                label: Text(loc.encryptionVerify),
                onPressed: onVerify,
              )
            : null,
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label =
        verified ? l10n.encryptionVerified : l10n.encryptionUnverified;
    // [Semantics] instead of [Tooltip]: same reason as
    // [_TrustBadge] in `device_list_screen.dart` — the page lives
    // inside the dashboard's [LayoutBuilder] shell, and a Tooltip's
    // internal [OverlayPortal] activation would mark a sibling
    // [_RenderLayoutBuilder] as needing layout mid-performLayout.
    return Semantics(
      label: label,
      child: Icon(
        verified ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
        color: verified ? scheme.primary : scheme.error,
        size: 20,
      ),
    );
  }
}
