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
import 'package:matrix/encryption.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wizard that guides the user through setting up cross-signing + key backup.
///
/// This screen drives the SDK [Bootstrap] state machine.  The Bootstrap object
/// walks the user through:
///   1. Checking for existing SSSS (wipe/keep/migrate)
///   2. Creating/entering a recovery passphrase
///   3. Setting up cross-signing keys
///   4. Optionally enabling online key backup
///
/// Callers must provide a [Bootstrap] instance obtained via
/// `EncryptionService.startBootstrap()`.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key, required this.bootstrap});

  final Bootstrap bootstrap;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  late Bootstrap _bootstrap;
  final _passphraseCtl = TextEditingController();
  bool _showExistingSsssUnlock = false;

  @override
  void initState() {
    super.initState();
    _bootstrap = widget.bootstrap;
    _bootstrap.onUpdate = (_) {
      if (mounted) setState(() {});
      // When the SDK opens an existing SSSS key (e.g. the default key was
      // valid and didn't need passphrase unlocking), it transitions to
      // [BootstrapState.openExistingSsss].  We must then call
      // [Bootstrap.openExistingSsss()] to cache secrets and advance the
      // state machine; otherwise the UI sits on a spinner forever.
      if (_bootstrap.state == BootstrapState.openExistingSsss) {
        // Schedule for the next frame so the spinner is shown briefly
        // before the potentially-async openExistingSsss() call.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _bootstrap.openExistingSsss().catchError((e, s) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          });
        });
      }
    };
  }

  void _confirmWipeSsss(bool wipe) {
    if (!wipe) {
      // Keep existing: no destructive action, proceed directly.
      try {
        _bootstrap.wipeSsss(false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return;
    }

    // Wiping SSSS is destructive and irreversible.  Show a confirmation
    // dialog so the user understands they will lose access to all
    // previously encrypted messages unless they have a recovery key.
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe Existing Encryption Keys?'),
        content: const Text(
          'This will permanently delete your existing encryption keys.\n\n'
          'You will not be able to read old encrypted messages on any '
          'device unless you have saved a separate recovery key.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Wipe Keys'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true) return;
      if (!mounted) return;
      try {
        _bootstrap.wipeSsss(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(loc.encryptionSetupTitle),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStateWidget(scheme, loc),
          ],
        ),
      ),
    );
  }

  Widget _buildStateWidget(ColorScheme scheme, AppLocalizations loc) {
    switch (_bootstrap.state) {
      case BootstrapState.loading:
        return _section(
          icon: LucideIcons.loader,
          title: loc.loading,
          child: const LinearProgressIndicator(),
        );

      case BootstrapState.askWipeSsss:
        return _section(
          icon: LucideIcons.alertTriangle,
          title: loc.encryptionExistingSsssFound,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _confirmWipeSsss(true),
                      child: Text(loc.encryptionWipeExisting),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmWipeSsss(false),
                      child: Text(loc.encryptionKeepExisting),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case BootstrapState.askUseExistingSsss:
        return _section(
          icon: LucideIcons.key,
          title: loc.encryptionUseExistingSsss,
          child: Column(
            children: [
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  try {
                    _bootstrap.useExistingSsss(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.yesOrAffirmitive),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  try {
                    _bootstrap.useExistingSsss(false);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.noOrCancellation),
              ),
            ],
          ),
        );

      case BootstrapState.askBadSsss:
        return _section(
          icon: LucideIcons.alertTriangle,
          title: loc.encryptionBadSsss,
          child: Column(
            children: [
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  try {
                    _bootstrap.ignoreBadSecrets(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.encryptionContinueAnyway),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  try {
                    _bootstrap.ignoreBadSecrets(false);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.cancel),
              ),
            ],
          ),
        );

      case BootstrapState.askUnlockSsss:
        return _section(
          icon: LucideIcons.lock,
          title: loc.encryptionUnlockSsss,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(loc.encryptionUnlockDescription),
              const SizedBox(height: 16),
              if (!_showExistingSsssUnlock) ...[
                FilledButton(
                  onPressed: () => setState(
                    () => _showExistingSsssUnlock = true,
                  ),
                  child: Text(loc.encryptionEnterRecoveryKey),
                ),
              ] else ...[
                TextField(
                  controller: _passphraseCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: loc.encryptionPassphraseOrKey,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    for (final entry in _bootstrap.oldSsssKeys?.entries ??
                        <MapEntry<String, OpenSSSS>>[]) {
                      if (_passphraseCtl.text.isEmpty) {
                        try {
                          await entry.value.unlock();
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(loc.encryptionCouldNotUnlock),
                            ),
                          );
                          return;
                        }
                      } else {
                        // Use keyOrPassphrase which auto-detects whether the
                        // input is a recovery key (base58) or a passphrase.
                        try {
                          await entry.value.unlock(
                            keyOrPassphrase: _passphraseCtl.text,
                          );
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(loc.encryptionCouldNotUnlock),
                            ),
                          );
                          return;
                        }
                      }
                      if (!entry.value.isUnlocked) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.encryptionCouldNotUnlock),
                          ),
                        );
                        return;
                      }
                    }
                    if (!mounted) return;
                    _bootstrap.unlockedSsss();
                  },
                  child: Text(loc.encryptionUnlock),
                ),
              ],
            ],
          ),
        );

      case BootstrapState.askNewSsss:
        return _section(
          icon: LucideIcons.shieldPlus,
          title: loc.encryptionCreatePassphrase,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: _passphraseCtl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: loc.encryptionPassphraseOrKey,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  try {
                    _bootstrap.newSsss(
                      _passphraseCtl.text.isNotEmpty
                          ? _passphraseCtl.text
                          : null,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.encryptionSetPassphrase),
              ),
            ],
          ),
        );

      case BootstrapState.openExistingSsss:
        return _section(
          icon: LucideIcons.unlock,
          title: loc.encryptionUnlocking,
          child: const LinearProgressIndicator(),
        );

      case BootstrapState.askWipeCrossSigning:
        return _section(
          icon: LucideIcons.refreshCw,
          title: loc.encryptionCrossSigningExists,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        try {
                          _bootstrap.wipeCrossSigning(true);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                      child: Text(loc.encryptionRecreateKeys),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        try {
                          _bootstrap.wipeCrossSigning(false);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                      child: Text(loc.encryptionKeepKeys),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case BootstrapState.askSetupCrossSigning:
        return _section(
          icon: LucideIcons.verified,
          title: loc.encryptionSetupCrossSigning,
          subtitle: loc.encryptionSetupCrossSigningDesc,
          child: Column(
            children: [
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  try {
                    _bootstrap.askSetupCrossSigning(
                      setupMasterKey: true,
                      setupSelfSigningKey: true,
                      setupUserSigningKey: true,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.encryptionSetupAllKeys),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  try {
                    _bootstrap.askSetupCrossSigning();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.encryptionSkipKeySetup),
              ),
            ],
          ),
        );

      case BootstrapState.askWipeOnlineKeyBackup:
        return _section(
          icon: LucideIcons.cloud,
          title: loc.encryptionBackupExists,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        try {
                          _bootstrap.wipeOnlineKeyBackup(true);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                      child: Text(loc.encryptionRecreateBackup),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        try {
                          _bootstrap.wipeOnlineKeyBackup(false);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                      child: Text(loc.encryptionKeepBackup),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case BootstrapState.askSetupOnlineKeyBackup:
        return _section(
          icon: LucideIcons.cloudUpload,
          title: loc.encryptionSetupBackup,
          subtitle: loc.encryptionSetupBackupDesc,
          child: Column(
            children: [
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  try {
                    _bootstrap.askSetupOnlineKeyBackup(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.encryptionEnableBackup),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  try {
                    _bootstrap.askSetupOnlineKeyBackup(false);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                child: Text(loc.encryptionSkipBackup),
              ),
            ],
          ),
        );

      case BootstrapState.error:
        return _section(
          icon: LucideIcons.alertOctagon,
          title: loc.error,
          child: Column(
            children: [
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(loc.cancel),
              ),
            ],
          ),
        );

      case BootstrapState.done:
        return _buildDoneState(scheme, loc);
    }
  }

  /// Builds the final "all set" state shown when the bootstrap wizard
  /// has finished.
  ///
  /// Surfaces a recovery-key reminder: the SDK encrypts the key at rest
  /// so we can't display it, but the user still needs to write it down
  /// somewhere safe before they can sign in on a new device.  "I
  /// saved it" persists a flag in [SharedPreferences] so the reminder
  /// can be re-shown at a later time; "I'll do this later" simply
  /// dismisses the screen.
  Widget _buildDoneState(ColorScheme scheme, AppLocalizations loc) {
    return _section(
      icon: LucideIcons.shieldCheck,
      title: loc.encryptionDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Icon(LucideIcons.shieldCheck, size: 72, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            loc.encryptionRecoveryKeyReminderBody,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(LucideIcons.check),
            onPressed: () async {
              await _persistRecoveryKeyAcknowledged();
              if (!mounted) return;
              Navigator.of(context).pop(true);
            },
            label: Text(loc.encryptionRecoveryKeyReminderAck),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(loc.encryptionRecoveryKeyReminderLater),
          ),
        ],
      ),
    );
  }

  /// Records that the user explicitly acknowledged they have saved
  /// the recovery key.  Used by the encryption overview to hide the
  /// persistent banner once the user has opted in.
  Future<void> _persistRecoveryKeyAcknowledged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('encryption_recovery_key_acknowledged', true);
    } catch (_) {
      // Persistence is best-effort; the next launch will re-prompt,
      // which is preferable to crashing the dismiss flow.
    }
  }

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
