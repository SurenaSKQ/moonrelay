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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/screens/encryption/bootstrap_screen.dart';
import 'package:moonrelay/src/screens/encryption/device_list_screen.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:provider/provider.dart';

/// The "Encryption & Security" hub page shown in the settings area.
///
/// Displays an overview of the current encryption state (cross-signing,
/// key backup, device verification) and provides entry points to the
/// detailed management screens.
class EncryptionOverviewScreen extends StatelessWidget {
  const EncryptionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final enc = context.watch<EncryptionService>();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.encryptionSecurity),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Cross-signing section ──────────────────────────────────────
          _SectionHeader(
            icon: LucideIcons.shield,
            title: loc.encryptionCrossSigning,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    icon: enc.crossSigningBootstrapped
                        ? LucideIcons.checkCircle
                        : LucideIcons.alertCircle,
                    iconColor: enc.crossSigningBootstrapped
                        ? Colors.green
                        : scheme.error,
                    label: enc.crossSigningBootstrapped
                        ? loc.encryptionCrossSigningActive
                        : loc.encryptionCrossSigningInactive,
                  ),
                  const SizedBox(height: 8),
                  _StatusRow(
                    icon: enc.isThisDeviceVerified
                        ? LucideIcons.shieldCheck
                        : LucideIcons.shieldOff,
                    iconColor: enc.isThisDeviceVerified
                        ? scheme.primary
                        : scheme.error,
                    label: enc.isThisDeviceVerified
                        ? loc.encryptionDeviceVerified
                        : loc.encryptionDeviceNotVerified,
                  ),
                  const SizedBox(height: 16),
                  if (!enc.crossSigningBootstrapped)
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.shieldPlus),
                      label: Text(loc.encryptionBootstrap),
                      onPressed: () => _startBootstrap(context, enc),
                    )
                  else ...[
                    // Self-verification: verify this device with another
                    // of the user's own (already-trusted) devices via SAS.
                    if (!enc.isThisDeviceVerified)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.tonalIcon(
                          icon: const Icon(LucideIcons.verified, size: 18),
                          label: Text(loc.encryptionVerifyDevice),
                          onPressed: () =>
                              _startSelfVerification(context, enc, loc),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(LucideIcons.refreshCw, size: 18),
                            label: Text(loc.encryptionReBootstrap),
                            onPressed: () => _startBootstrap(context, enc),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Devices section ──────────────────────────────────────────
          _SectionHeader(
            icon: LucideIcons.smartphone,
            title: loc.encryptionDevices,
          ),
          Card(
            child: ListTile(
              leading: Icon(LucideIcons.monitor, color: scheme.primary),
              title: Text(loc.encryptionManageDevices),
              subtitle: Text(
                '${enc.myDevices.length} ${loc.encryptionDevicesLower}',
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeviceListScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Key backup section ────────────────────────────────────────
          _SectionHeader(
            icon: LucideIcons.cloud,
            title: loc.encryptionKeyBackup,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    icon: enc.isKeyBackupEnabled
                        ? LucideIcons.cloud
                        : LucideIcons.cloudOff,
                    iconColor:
                        enc.isKeyBackupEnabled ? Colors.green : scheme.outline,
                    label: enc.isKeyBackupEnabled
                        ? loc.encryptionKeyBackupActive
                        : loc.encryptionKeyBackupInactive,
                  ),
                  const SizedBox(height: 16),
                  if (!enc.crossSigningBootstrapped)
                    Text(
                      loc.encryptionSetupCrossSigningFirst,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    )
                  else if (!enc.isKeyBackupEnabled)
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.cloudUpload, size: 18),
                      label: Text(loc.encryptionSetupKeyBackup),
                      onPressed: () => _startBootstrap(context, enc),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Verify other users section ────────────────────────────────
          _SectionHeader(
            icon: LucideIcons.users,
            title: loc.encryptionVerifiedUsers,
          ),
          _buildUnverifiedCount(context, enc, scheme, loc),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUnverifiedCount(
    BuildContext context,
    EncryptionService enc,
    ColorScheme scheme,
    AppLocalizations loc,
  ) {
    return FutureBuilder(
      future: enc.countUnverified(),
      builder: (context, snapshot) {
        final counts = snapshot.data;
        if (counts == null) return const SizedBox.shrink();
        final theme = Theme.of(context);

        return Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(LucideIcons.user, color: scheme.outline),
                title: Text(loc.encryptionUnverifiedOwn),
                trailing:
                    Text('${counts.own}', style: theme.textTheme.titleMedium),
              ),
              ListTile(
                leading: Icon(LucideIcons.users, color: scheme.error),
                title: Text(loc.encryptionUnverifiedOther),
                trailing:
                    Text('${counts.other}', style: theme.textTheme.titleMedium),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startBootstrap(BuildContext context, EncryptionService enc) async {
    if (!enc.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.encryptionUnsupported)),
      );
      return;
    }

    try {
      final bootstrap = enc.startBootstrap();
      if (!context.mounted) return;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => BootstrapScreen(bootstrap: bootstrap),
        ),
      );
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.encryptionDone)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error} $e')),
        );
      }
    }
  }

  void _startSelfVerification(
    BuildContext context,
    EncryptionService enc,
    AppLocalizations loc,
  ) async {
    try {
      final req = await enc.requestSelfVerification();
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationScreen(request: req),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.encryptionFailedAction('$e'))),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}
