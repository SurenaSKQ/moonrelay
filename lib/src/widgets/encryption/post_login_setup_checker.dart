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
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/encryption/bootstrap_screen.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:provider/provider.dart';

/// Checks the encryption setup state shortly after login and prompts the user
/// if they need to bootstrap cross-signing or verify this device.
///
/// Place this widget high in the widget tree (e.g. inside [DashboardLayout])
/// so it runs once when the user first lands on the main app screen after a
/// fresh login.  It uses a one-shot flag to avoid re-prompting on rebuilds.
class PostLoginSetupChecker extends StatefulWidget {
  const PostLoginSetupChecker({super.key, required this.child});

  final Widget child;

  @override
  State<PostLoginSetupChecker> createState() => _PostLoginSetupCheckerState();
}

class _PostLoginSetupCheckerState extends State<PostLoginSetupChecker> {
  bool _didCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCheck) {
      _didCheck = true;
      // Post-frame so the widget tree is fully built before we show a dialog.
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    if (!mounted) return;

    final client = context.read<Client>();
    final enc = context.read<EncryptionService>();

    if (!enc.isInitialized) {
      try {
        // init() now awaits its first refresh internally, so by the
        // time it resolves, setupRequirement reflects the latest
        // cross-signing / device state — no need for an extra
        // fixed-delay workaround here.
        await enc.init();
      } catch (_) {
        return;
      }
      if (!mounted) return;
    }

    // ── Wait for account data to settle ─────────────────────────────
    // The encryption service coalesces post-sync refreshes behind a
    // short debounce.  We still wait for one sync event so post-login
    // UI prompts reflect data the server has actually delivered.
    final log = context.read<Logger>();
    try {
      await client.onSync.stream.first.timeout(
        const Duration(seconds: 15),
      );
      // Give the debounced refresh (750ms) time to complete.
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } on TimeoutException {
      log.w('PostLoginSetupChecker: timeout waiting for sync; '
          'proceeding with current data');
    } catch (_) {
      // proceed with whatever data we have
    }

    if (!mounted) return;

    final requirement = enc.setupRequirement;
    log.i('PostLoginSetupChecker: requirement=$requirement');

    if (requirement == EncryptionSetupRequirement.none) return;
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    if (requirement == EncryptionSetupRequirement.bootstrap) {
      final shouldBootstrap = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.encryptionSetupTitle),
          content: Text(l10n.encryptionPostLoginBootstrap),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.encryptionSkipKeySetup),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.encryptionBootstrap),
            ),
          ],
        ),
      );

      if (shouldBootstrap == true && mounted) {
        try {
          final bootstrap = enc.startBootstrap();
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => BootstrapScreen(bootstrap: bootstrap),
            ),
          );
        } catch (e) {
          log.e('Bootstrap failed', error: e);
        }
      }
      return;
    }

    if (requirement == EncryptionSetupRequirement.verify) {
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.encryptionVerifyDevice),
          content: Text(l10n.encryptionPostLoginVerify),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'later'),
              child: Text(l10n.encryptionLater),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, 'settings');
              },
              child: Text(l10n.encryptionVerifyDeviceAction),
            ),
          ],
        ),
      );

      if (action == 'settings' && mounted) {
        try {
          final kv = await enc.requestSelfVerification();
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => VerificationScreen(
                request: kv,
                isIncoming: false,
              ),
            ),
          );
        } catch (e) {
          log.e('Self-verification failed', error: e);
        }
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
