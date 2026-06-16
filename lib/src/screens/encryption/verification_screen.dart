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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// SAS (emoji/number) verification dialog.
///
/// This screen handles both sides of the verification flow:
/// - **Incoming** — another user has sent us a verification request.
/// - **Outgoing** — we initiated the request and are waiting for their response.
///
/// The widget takes a [KeyVerification] object and listens to its state
/// transitions to drive the UI.  Callers should obtain the object from
/// `EncryptionService.requestVerification()` or listen to
/// `client.onKeyVerificationRequest`.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    required this.request,
    this.isIncoming = false,
  });

  /// The SDK verification request object.
  final KeyVerification request;

  /// Whether this is an incoming request (shown immediately) or outgoing
  /// (we initiated it).
  final bool isIncoming;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    if (!widget.isIncoming) {
      // We already called kv.start() in the service — listen for updates.
      widget.request.onUpdate = () {
        if (mounted) setState(() {});
      };
    } else {
      // Incoming — we need to react to the request's built-in stream.
      widget.request.onUpdate = () {
        if (mounted) setState(() {});
      };
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.encryptionVerifyUser),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => _cancel(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(scheme, loc, context),
        ),
      ),
    );
  }

  Widget _buildBody(
      ColorScheme scheme, AppLocalizations loc, BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;

    switch (req.state) {
      case KeyVerificationState.waitingAccept:
        return _statusColumn(
          icon: LucideIcons.clock,
          title: widget.isIncoming
              ? loc.encryptionWaitingForYou
              : loc.encryptionWaitingForOther,
          subtitle: loc.encryptionVerificationWaitingDesc,
        );

      case KeyVerificationState.askAccept:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldQuestion, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(loc.encryptionVerificationRequest,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(req.userId, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _accept(context),
              child: Text(loc.yesOrAffirmitive),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _cancel(context),
              child: Text(loc.noOrCancellation),
            ),
          ],
        );

      case KeyVerificationState.askChoice:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.handshake, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(loc.encryptionChooseMethod, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (req.possibleMethods.contains(EventTypes.Sas))
              _methodButton(
                icon: LucideIcons.smile,
                label: loc.encryptionMethodEmoji,
                onTap: () => _startSas(context),
              ),
            if (req.possibleMethods.contains(EventTypes.QRShow) ||
                req.possibleMethods.contains(EventTypes.QRScan))
              _methodButton(
                icon: LucideIcons.qrCode,
                label: loc.encryptionMethodQr,
                onTap: () => _startQr(context, req),
              ),
          ],
        );

      case KeyVerificationState.askSas:
        // Show the emoji/number comparison.
        final emojis = req.sasEmojis;
        final numbers = req.sasNumbers;
        final isEmoji = emojis.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.encryptionCompareEmojis,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              loc.encryptionCompareDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            // Emoji display
            if (isEmoji)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: emojis.map((e) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 36)),
                      Text(e.name, style: theme.textTheme.bodySmall),
                    ],
                  );
                }).toList(),
              )
            else
              // Number display
              Wrap(
                spacing: 16,
                alignment: WrapAlignment.center,
                children: numbers.map((d) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$d',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            Text(loc.encryptionDoTheyMatch, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.check, color: Colors.green),
                  label: Text(loc.encryptionTheyMatch),
                  onPressed: () => _sasMatch(context),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.x, color: Colors.red),
                  label: Text(loc.encryptionTheyDontMatch),
                  onPressed: () => _sasMismatch(context),
                ),
              ],
            ),
          ],
        );

      case KeyVerificationState.waitingSas:
        return _statusColumn(
          icon: LucideIcons.clock,
          title: loc.encryptionWaitingForSas,
        );

      case KeyVerificationState.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldCheck, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(loc.encryptionVerificationDone,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(loc.done),
            ),
          ],
        );

      case KeyVerificationState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertOctagon, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            Text(loc.encryptionVerificationFailed,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(req.canceledReason ?? loc.encryptionUnknownError),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(loc.close),
            ),
          ],
        );

      // Other states we don't handle here (SSSS, QR confirm, etc.)
      case KeyVerificationState.askSSSS:
      case KeyVerificationState.showQRSuccess:
      case KeyVerificationState.confirmQRScan:
        return _statusColumn(
          icon: LucideIcons.clock,
          title: loc.loading,
        );
    }
  }

  // ---- Actions ----------------------------------------------------------

  void _accept(BuildContext context) async {
    try {
      await widget.request.acceptVerification();
      setState(() {});
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.encryptionFailedAction('$e'))),
        );
      }
    }
  }

  Future<void> _startSas(BuildContext context) async {
    try {
      await widget.request.continueVerification(EventTypes.Sas);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.encryptionFailedAction('$e'))),
        );
      }
    }
  }

  Future<void> _startQr(BuildContext context, KeyVerification req) async {
    try {
      await widget.request.continueVerification(EventTypes.QRShow);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.encryptionFailedAction('$e'))),
        );
      }
    }
  }

  Future<void> _sasMatch(BuildContext context) async {
    try {
      await widget.request.acceptSas();
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.encryptionFailedAction('$e'))),
        );
      }
    }
  }

  Future<void> _sasMismatch(BuildContext context) async {
    try {
      await widget.request.rejectSas();
    } catch (_) {}
    if (mounted && context.mounted) Navigator.of(context).pop(false);
  }

  Future<void> _cancel(BuildContext context) async {
    try {
      await widget.request.cancel();
    } catch (_) {
      // ignore
    }
    if (mounted && context.mounted) Navigator.of(context).pop(false);
  }

  // ---- Helpers ----------------------------------------------------------

  Widget _statusColumn({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? extra,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
        if (extra != null) extra,
      ],
    );
  }

  Widget _methodButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(icon),
          label: Text(label),
          onPressed: onTap,
        ),
      ),
    );
  }
}
