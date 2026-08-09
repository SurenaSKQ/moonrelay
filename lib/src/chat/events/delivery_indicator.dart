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

// Tiny delivery-status indicator shown next to outgoing messages.
//
// Renders one of four states:
//   - `sending`: amber spinner with "Sending…" tooltip
//   - `sent`:    subtle check mark (relies on eventId being set)
//   - `failed`:  red error with retry icon
//   - `idle`:    nothing rendered (used as the default for events that
//                have already been confirmed by the server)

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Lifecycle stages a freshly-sent message can be in.
enum DeliveryStatus { sending, sent, failed }

class DeliveryIndicator extends StatelessWidget {
  const DeliveryIndicator({super.key, required this.status, this.onRetry});

  final DeliveryStatus status;

  /// Called when the user taps the retry icon on a failed message.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    switch (status) {
      case DeliveryStatus.sending:
        return Semantics(
          label: loc.deliverySending,
          child: SizedBox(
            width: t.spaceMd,
            height: t.spaceMd,
            child: const CircularProgressIndicator(strokeWidth: 1.6),
          ),
        );
      case DeliveryStatus.sent:
        return Semantics(
          label: loc.deliverySent,
          child: Icon(
            LucideIcons.check,
            size: t.spaceMd,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      case DeliveryStatus.failed:
        return Semantics(
          label: loc.deliveryFailed,
          button: true,
          child: InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(t.radiusSm),
            child: Icon(
              LucideIcons.alertCircle,
              size: t.spaceMd + 2,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
    }
  }
}
