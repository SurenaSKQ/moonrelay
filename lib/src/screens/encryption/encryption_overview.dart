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

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/screens/encryption/bootstrap_screen.dart';
import 'package:moonrelay/src/screens/encryption/device_list_screen.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Encryption & Security" hub page shown in the settings area.
///
/// Displays an overview of the current encryption state (cross-signing,
/// key backup, device verification) and provides entry points to the
/// detailed management screens.
class EncryptionOverviewScreen extends StatefulWidget {
  const EncryptionOverviewScreen({super.key, this.embedded = false});

  /// When `true`, the page is rendered without its own [Scaffold] /
  /// [AppBar] so it can be embedded inside a parent widget (e.g. the
  /// hub screen's content pane) without nesting scaffolds.
  final bool embedded;

  @override
  State<EncryptionOverviewScreen> createState() =>
      _EncryptionOverviewScreenState();
}

class _EncryptionOverviewScreenState extends State<EncryptionOverviewScreen> {
  /// True when the user has previously acknowledged that they have
  /// saved their recovery key.  Loaded from [SharedPreferences] in
  /// [initState] and flipped from the persistent banner so the user
  /// can dismiss it without going through the bootstrap wizard.
  bool _recoveryKeyAcknowledged = true;

  @override
  void initState() {
    super.initState();
    _loadRecoveryKeyAcknowledged();
  }

  Future<void> _loadRecoveryKeyAcknowledged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _recoveryKeyAcknowledged =
            prefs.getBool('encryption_recovery_key_acknowledged') ?? false;
      });
    } catch (_) {
      // Best-effort; default is "not acknowledged" so the banner shows.
      if (!mounted) return;
      setState(() => _recoveryKeyAcknowledged = false);
    }
  }

  Future<void> _acknowledgeRecoveryKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('encryption_recovery_key_acknowledged', true);
      if (!mounted) return;
      setState(() => _recoveryKeyAcknowledged = true);
    } catch (_) {
      if (!mounted) return;
      // Even if persistence fails, hide the banner so the user is
      // not nagged for the rest of the session.
      setState(() => _recoveryKeyAcknowledged = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enc = context.watch<EncryptionService>();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
          // -- Recovery key reminder -----------------------------------
          // Shown when cross-signing is bootstrapped but the user has
          // not yet confirmed they have saved the recovery key. The
          // banner is dismissable so it can be hidden for the rest
          // of the session without forcing the user to re-run the
          // bootstrap wizard.
          if (enc.crossSigningBootstrapped && !_recoveryKeyAcknowledged)
            _RecoveryKeyReminderCard(
              onDismiss: _acknowledgeRecoveryKey,
              loc: loc,
              scheme: scheme,
            ),
          // -- Cross-signing section --------------------------------------
          _SectionHeader(
            icon: LucideIcons.shield,
            title: loc.encryptionCrossSigning,
            trailing: _StatusBadge(
              label: enc.crossSigningBootstrapped
                  ? loc.encryptionStatusOk
                  : loc.encryptionStatusActionRequired,
              ok: enc.crossSigningBootstrapped,
            ),
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
                  if (enc.crossSigningBootstrapped) ...[
                    const SizedBox(height: 12),
                    _FingerprintRow(
                      scheme: scheme,
                      label: loc.encryptionCrossSigningFingerprint,
                      fingerprint: enc.masterKeyFingerprint,
                    ),
                  ],
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

          // -- Setup benefits checklist (shown when not yet bootstrapped) --
          if (!enc.crossSigningBootstrapped) ...[
            _SectionHeader(
              icon: LucideIcons.lightbulb,
              title: loc.encryptionSetupChecklist,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletRow(
                      icon: LucideIcons.shieldCheck,
                      scheme: scheme,
                      text: loc.encryptionSetupChecklistCrossSigning,
                    ),
                    const SizedBox(height: 10),
                    _BulletRow(
                      icon: LucideIcons.cloud,
                      scheme: scheme,
                      text: loc.encryptionSetupChecklistBackup,
                    ),
                    const SizedBox(height: 10),
                    _BulletRow(
                      icon: LucideIcons.smartphone,
                      scheme: scheme,
                      text: loc.encryptionSetupChecklistDevice,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // -- Devices section ------------------------------------------
          _SectionHeader(
            icon: LucideIcons.smartphone,
            title: loc.encryptionDevices,
            trailing: _StatusBadge(
              label: enc.isThisDeviceVerified
                  ? loc.encryptionStatusOk
                  : loc.encryptionStatusActionRequired,
              ok: enc.isThisDeviceVerified,
            ),
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

          // -- Key backup section ----------------------------------------
          _SectionHeader(
            icon: LucideIcons.cloud,
            title: loc.encryptionKeyBackup,
            trailing: _StatusBadge(
              label: enc.keyBackupExists
                  ? loc.encryptionKeyBackupActive
                  : loc.encryptionKeyBackupInactive,
              ok: enc.keyBackupExists,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    icon: enc.keyBackupExists
                        ? LucideIcons.cloud
                        : LucideIcons.cloudOff,
                    iconColor:
                        enc.keyBackupExists ? Colors.green : scheme.outline,
                    label: enc.keyBackupExists
                        ? loc.encryptionKeyBackupActive
                        : loc.encryptionKeyBackupInactive,
                  ),
                  if (enc.keyBackupExists) ...[
                    const SizedBox(height: 12),
                    // Algorithm
                    if (enc.keyBackupAlgorithm != null)
                      _DetailLine(
                        scheme: scheme,
                        label: loc.encryptionBackupAlgorithm,
                        value: enc.keyBackupAlgorithm!,
                      ),
                    // Cached recovery key
                    _StatusRow(
                      icon: enc.keyBackupCached
                          ? LucideIcons.checkCircle
                          : LucideIcons.helpCircle,
                      iconColor: enc.keyBackupCached
                          ? Colors.green
                          : Colors.orange,
                      label: enc.keyBackupCached
                          ? loc.encryptionBackupRecoveryKeySet
                          : loc.encryptionBackupNoRecoveryKey,
                    ),
                    if (!enc.keyBackupCached) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          loc.encryptionBackupRecoveryKeyHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  if (!enc.crossSigningBootstrapped)
                    Text(
                      loc.encryptionSetupCrossSigningFirst,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    )
                  else
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.cloudUpload, size: 18),
                      label: Text(
                        enc.keyBackupExists
                            ? loc.encryptionRebootstrapKeyBackup
                            : loc.encryptionSetupKeyBackup,
                      ),
                      onPressed: () =>
                          _startKeyBackup(context, enc),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -- Verify other users section --------------------------------
          _SectionHeader(
            icon: LucideIcons.users,
            title: loc.encryptionVerifiedUsers,
          ),
          _buildUnverifiedCount(context, enc, scheme, loc),
          const SizedBox(height: 16),

          // -- Local data section -------------------------------------
          // Sensitive: the export contains the pickled olm account
          // and must be triggered explicitly.  The button copy makes
          // this clear and the action writes to a user-chosen file
          // rather than auto-opening it.
          _SectionHeader(
            icon: LucideIcons.keyRound,
            title: loc.encryptionLocalDataSection,
          ),
          Card(
            child: ListTile(
              leading: Icon(
                LucideIcons.download,
                color: scheme.primary,
              ),
              title: Text(loc.encryptionExportKeys),
              subtitle: Text(loc.encryptionExportKeysDescription),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _exportKeys(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.encryptionSecurity),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: loc.encryptionRefresh,
            onPressed: () async {
              await enc.refresh();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.encryptionRefreshed)),
              );
            },
          ),
        ],
      ),
      body: body,
    );
  }

  /// Prompts the user for confirmation, then writes the encryption
  /// export to a user-chosen file.  The export contains the pickled
  /// olm account and a snapshot of non-sensitive preferences; it is
  /// the only way to move keys off this device without going through
  /// the homeserver's key backup.
  Future<void> _exportKeys(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final enc = context.read<EncryptionService>();

    // Confirm dialog: the file is the only way to move this device's
    // keys to a new install, so we want the user to acknowledge the
    // risk before exporting.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(LucideIcons.alertTriangle, color: scheme.error),
        title: Text(loc.encryptionExportKeys),
        content: Text(loc.encryptionExportKeysConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.encryptionExportKeys),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    String? json;
    String? error;
    try {
      json = await enc.exportOlmAccount();
    } catch (e) {
      error = e.toString();
    }
    if (!context.mounted) return;
    if (json == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? loc.error)),
      );
      return;
    }

    final saved = await _writeExportFile(context, json, loc);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? loc.encryptionExportKeysDone
              : loc.encryptionExportKeysCancelled,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Opens a save-file dialog and writes [json] to the chosen path.
  /// Returns `true` if the file was saved, `false` if the user
  /// cancelled the dialog or the write failed.
  Future<bool> _writeExportFile(
    BuildContext context,
    String json,
    AppLocalizations loc,
  ) async {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final suggested = 'moonrelay-e2ee-export-$stamp.json';
    final path = await FilePicker.saveFile(
      dialogTitle: loc.encryptionExportKeys,
      fileName: suggested,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    if (path == null) return false;
    return true;
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
                leading: Icon(
                  counts.own == 0 ? LucideIcons.shieldCheck : LucideIcons.alertCircle,
                  color: counts.own == 0 ? Colors.green : scheme.error,
                ),
                title: Text(loc.encryptionUnverifiedOwn),
                trailing: Text(
                  '${counts.own}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: counts.own == 0 ? Colors.green : scheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  counts.other == 0 ? LucideIcons.users : LucideIcons.userX,
                  color: counts.other == 0 ? Colors.green : scheme.error,
                ),
                title: Text(loc.encryptionUnverifiedOther),
                trailing: Text(
                  '${counts.other}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: counts.other == 0 ? Colors.green : scheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => BootstrapScreen(bootstrap: bootstrap),
        ),
      );
      // Always notify the service that bootstrap finished  it re-runs
      // the full state refresh and re-evaluates setupRequirement.
      enc.onBootstrapFinished();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.encryptionDone),
        ),
      );
    } catch (e) {
      enc.onBootstrapFinished();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.error}: $e',
            ),
          ),
        );
      }
    }
  }

  /// Re-launches the bootstrap flow solely to configure / re-configure
  /// the online key backup.  The wizard handles both the "backup not
  /// configured" and "backup configured, want to re-create" cases via
  /// its [BootstrapState.askWipeOnlineKeyBackup] / [BootstrapState.askSetupOnlineKeyBackup]
  /// states; we let it run to completion.
  void _startKeyBackup(BuildContext context, EncryptionService enc) async {
    if (!enc.isSupported || !enc.crossSigningBootstrapped) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.encryptionSetupCrossSigningFirst,
          ),
        ),
      );
      return;
    }
    // Same wizard  it begins by asking whether to wipe existing SSSS,
    // flows through cross-signing re-creation if needed, then asks
    // about the online key backup specifically.
    _startBootstrap(context, enc);
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
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small pill-shaped status label used in the overview to give an at-a-glance
/// "this feature is OK / needs attention" indicator next to each section header.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok ? Colors.green : scheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? LucideIcons.checkCircle : LucideIcons.alertCircle,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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

/// Bullet-row used by the "Why set up encryption?" checklist.
class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.icon,
    required this.scheme,
    required this.text,
  });

  final IconData icon;
  final ColorScheme scheme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/// Two-column label + monospace fingerprint reader for the user-facing
/// "Master key fingerprint" entry.  Selectable so the user can copy it.
class _FingerprintRow extends StatelessWidget {
  const _FingerprintRow({
    required this.scheme,
    required this.label,
    required this.fingerprint,
  });

  final ColorScheme scheme;
  final String label;
  final String? fingerprint;

  @override
  Widget build(BuildContext context) {
    if (fingerprint == null || fingerprint!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              fingerprint!,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label-below-value detail line for showing backup metadata.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.scheme,
    required this.label,
    required this.value,
  });

  final ColorScheme scheme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 26), // align with icon width in _StatusRow
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Persistent reminder shown at the top of the encryption overview when
/// cross-signing is bootstrapped but the user has not yet confirmed
/// that they have saved their recovery key.
///
/// The banner is intentionally non-blocking: it explains why the key
/// matters and offers a single "I saved it" button that dismisses it
/// for the rest of the session (and persists the acknowledgement so it
/// stays dismissed on subsequent launches).
class _RecoveryKeyReminderCard extends StatelessWidget {
  const _RecoveryKeyReminderCard({
    required this.onDismiss,
    required this.loc,
    required this.scheme,
  });

  final Future<void> Function() onDismiss;
  final AppLocalizations loc;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: scheme.tertiaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.keyRound,
                  color: scheme.tertiary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.encryptionRecoveryKeyReminderTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc.encryptionRecoveryKeyReminderBody,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: const Icon(LucideIcons.check, size: 16),
                onPressed: () {
                  // ignore: discarded_futures
                  onDismiss();
                },
                label: Text(loc.encryptionRecoveryKeyReminderAck),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
