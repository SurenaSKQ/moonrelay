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
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:provider/provider.dart';

/// Reserved name for the post-login setup hook.  This widget used to
/// fire the cross-signing bootstrap / device-verification flow
/// automatically on every dashboard mount; the new encryption flow
/// instead surfaces a one-shot emoji-verification prompt immediately
/// after sign-in (see [runPostLoginEncryptionFlow] in
/// [EncryptionService]) and leaves the rest of the setup to the
/// encryption settings page.
///
/// Keeping the class around means the dashboard mount site does not
/// need to change  it still wraps the dashboard in
/// [PostLoginSetupChecker], but the widget is now a no-op
/// [Container] that simply forwards the child.
class PostLoginSetupChecker extends StatelessWidget {
  const PostLoginSetupChecker({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Keep the encryption service in scope so the dashboard tree has
    // a single owner of the [EncryptionService] instance.  The actual
    // post-login prompt lives in [EncryptionService] now.
    context.read<EncryptionService>();
    return child;
  }
}
