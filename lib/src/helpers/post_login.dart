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
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:provider/provider.dart';

/// Starts encryption and persists [client]'s account for multi-account
/// support, returning the encryption service so the caller can offer the
/// device-verification prompt afterwards.
///
/// Both sign-in paths need this and neither should be able to forget it:
/// an account that is not in [AccountManager] does not appear in the
/// account switcher and cannot be re-selected without logging in again.
Future<EncryptionService> persistSignedInAccount(
  BuildContext context,
  Client client,
) async {
  // Provider reads happen before any await so the analyzer does not see
  // [context] used across the async gap.
  final encryptionService = context.read<EncryptionService>();
  final accountManager = context.read<AccountManager>();
  final homeserverSnapshot = client.homeserver?.toString() ?? '';
  final userIdSnapshot = client.userID!;

  await encryptionService.init();
  await accountManager.addOrUpdateAccount(
    StoredAccount(
      userId: userIdSnapshot,
      homeserver: homeserverSnapshot,
    ),
    client: client,
    encryptionService: encryptionService,
  );
  return encryptionService;
}

/// The one-shot device-verification prompt, shown immediately after a
/// successful sign-in.
///
/// The new encryption flow surfaces an emoji comparison as soon as the
/// device has keys. Cross-signing bootstrap, recovery key flows and other
/// SSSS prompts are deliberately deferred to the encryption settings page,
/// so the user is not ambushed by password-style dialogs every time they
/// open the app.
///
/// This is a no-op when the SDK offers no verification request, and when
/// the flow throws, which is why it is a separate step rather than part
/// of [persistSignedInAccount]: a homeserver that does not implement
/// verification must not be able to block the sign-in that just
/// succeeded.
Future<void> maybePromptDeviceVerification(
  BuildContext context,
  EncryptionService encryptionService,
) async {
  if (!context.mounted) return;
  final log = context.read<Logger>();
  KeyVerification? kv;
  try {
    kv = await encryptionService.startPostLoginFlow();
  } catch (e) {
    log.w('post-login encryption flow failed', error: e);
    return;
  }
  if (kv == null) return;
  if (!context.mounted) return;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => VerificationScreen(
        request: kv!,
        isIncoming: false,
      ),
    ),
  );
}

/// Persists the account, routes to the rooms screen, then offers the
/// verification prompt.
///
/// [beforeNavigate] runs after the account is saved and before the
/// route changes, which is where the sign-in pages put their own
/// follow-up: the login page waits for the SDK's first sync there so the
/// room list is not empty when the user lands on it.
Future<void> completeSignIn(
  BuildContext context,
  Client client, {
  Future<void> Function()? beforeNavigate,
}) async {
  final encryptionService = await persistSignedInAccount(context, client);
  await beforeNavigate?.call();
  if (!context.mounted) return;
  context.go('/main/rooms');
  await maybePromptDeviceVerification(context, encryptionService);
}
