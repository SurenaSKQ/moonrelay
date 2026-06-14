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
import 'package:matrix/encryption.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:provider/provider.dart';

/// Listens for incoming key verification requests and shows a dialog.
///
/// Place this widget high in the widget tree (e.g. inside [DashboardLayout])
/// so it can intercept to-device verification requests from other users.
class IncomingVerificationListener extends StatefulWidget {
  const IncomingVerificationListener({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingVerificationListener> createState() =>
      _IncomingVerificationListenerState();
}

class _IncomingVerificationListenerState
    extends State<IncomingVerificationListener> {
  StreamSubscription<KeyVerification>? _sub;
  KeyVerification? _pending;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-attach if the EncryptionService instance changed.
    _attach();
  }

  void _attach() {
    _sub?.cancel();
    final enc = context.read<EncryptionService>();
    _sub = enc.onKeyVerificationRequest.listen(_onRequest);
  }

  void _onRequest(KeyVerification request) {
    if (!mounted) return;

    // Avoid stacking multiple dialogs.
    if (_pending != null) {
      request.cancel();
      return;
    }

    _pending = request;
    _showRequestDialog(request);
  }

  Future<void> _showRequestDialog(KeyVerification request) async {
    final l10n = AppLocalizations.of(context)!;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.encryptionVerificationRequest),
        content: Text(request.userId),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.noOrCancellation),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.yesOrAffirmitive),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      try {
        await request.acceptVerification();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              request: request,
              isIncoming: true,
            ),
          ),
        );
      } catch (_) {
        if (mounted) {
          await request.cancel();
        }
      }
    } else {
      await request.cancel();
    }

    _pending = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
