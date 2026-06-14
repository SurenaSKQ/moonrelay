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
import 'package:provider/provider.dart';

/// Lists all devices for the current user, showing trust status and providing
/// actions to verify, rename, or delete sessions.
class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final enc = context.watch<EncryptionService>();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final client = context.read<Client>();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.encryptionDevices),
      ),
      body: enc.myDevices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.smartphone, size: 48, color: scheme.outline),
                  const SizedBox(height: 16),
                  Text(loc.encryptionNoDevices,
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: enc.myDevices.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final device = enc.myDevices[index];
                final isCurrent = device.deviceId == client.deviceID;
                final deviceKeys =
                    client.userDeviceKeys[client.userID]?.deviceKeys;
                final key = deviceKeys?[device.deviceId];
                final isVerified = key?.verified ?? false;

                return ListTile(
                  leading: Icon(
                    isCurrent ? LucideIcons.smartphone : LucideIcons.monitor,
                    color: isVerified ? scheme.primary : scheme.error,
                  ),
                  title: Text(
                    device.displayName?.isNotEmpty == true
                        ? device.displayName!
                        : '${loc.encryptionDevice} ${device.deviceId}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.deviceId),
                      if (isCurrent)
                        Text(loc.encryptionThisDevice,
                            style: TextStyle(color: scheme.primary)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TrustBadge(verified: isVerified),
                      if (!isCurrent)
                        IconButton(
                          icon: Icon(LucideIcons.trash2, color: scheme.error),
                          onPressed: () => _confirmDelete(
                            context,
                            device,
                            loc,
                            enc,
                          ),
                        ),
                    ],
                  ),
                  onTap: isCurrent
                      ? null
                      : () => _showDeviceOptions(
                            context,
                            device,
                            isVerified,
                            loc,
                            enc,
                          ),
                );
              },
            ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Device device,
    AppLocalizations loc,
    EncryptionService enc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.encryptionDeleteDevice),
        content: Text(
          '${loc.encryptionDeleteDeviceConfirm} "${device.displayName ?? device.deviceId}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noOrCancellation),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(loc.yesOrAffirmitive),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await enc.deleteDevice(device.deviceId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.encryptionDeviceDeleted)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.error} $e')),
          );
        }
      }
    }
  }

  void _showDeviceOptions(
    BuildContext context,
    Device device,
    bool isVerified,
    AppLocalizations loc,
    EncryptionService enc,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isVerified ? LucideIcons.shieldOff : LucideIcons.shieldCheck,
              ),
              title: Text(
                isVerified
                    ? loc.encryptionMarkAsUnverified
                    : loc.encryptionMarkAsVerified,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleTrust(context, device, isVerified, loc, enc);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2),
              title: Text(loc.encryptionDeleteDevice),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, device, loc, enc);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTrust(
    BuildContext context,
    Device device,
    bool isVerified,
    AppLocalizations loc,
    EncryptionService enc,
  ) async {
    try {
      // Toggle trust on the device key via cross-signing.
      final client = context.read<Client>();
      final keys = client.userDeviceKeys[client.userID];
      final deviceKey = keys?.deviceKeys[device.deviceId];
      if (deviceKey != null) {
        await deviceKey.setVerified(!isVerified);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.error} $e')),
        );
      }
    }
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: verified ? 'Verified' : 'Unverified',
      child: Icon(
        verified ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
        color: verified ? scheme.primary : scheme.error,
        size: 20,
      ),
    );
  }
}
