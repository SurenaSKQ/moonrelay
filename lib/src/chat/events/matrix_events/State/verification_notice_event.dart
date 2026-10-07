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
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Renders a verification event (e.g. `m.key.verification.start`,
/// `m.key.verification.done`, `m.key.verification.cancel`) in a compact
/// card with a shield icon and a human-readable description.
///
/// Unlike [VerificationRequestEvent] this widget does not provide
/// interactive accept/decline buttons; it is purely informational.
class VerificationNoticeEvent extends StatelessWidget {
  const VerificationNoticeEvent({
    super.key,
    required this.event,
    this.showTimestamp = true,
  });

  final Event event;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    final description = _description(event.type, event.messageType, l10n);

    final ts = showTimestamp
        ? '  ${event.originServerTs.localizedTimeShort(context)}'
        : '';

    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: t.spaceXs + 2, horizontal: t.spaceMd),
      child: Card(
        color:
            scheme.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: t.spaceMd + 2, vertical: t.spaceMd - 2),
          child: Row(
            children: [
              Icon(LucideIcons.shield,
                  size: t.iconSizeMedium, color: scheme.primary),
              SizedBox(width: t.spaceSm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (ts.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: t.spaceXxs),
                        child: Text(
                          ts,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface
                                .withValues(alpha: t.opacitySubtle),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _description(
    String eventType,
    String messageType,
    AppLocalizations l10n,
  ) {
    // Prefer messageType when it contains the verification event name;
    // fall back to event.type for legacy events.
    final key =
        messageType.startsWith('m.key.verification.') ? messageType : eventType;

    switch (key) {
      case 'm.key.verification.start':
        return l10n.stateVerificationStart;
      case 'm.key.verification.done':
        return l10n.stateVerificationDone;
      case 'm.key.verification.cancel':
        return l10n.stateVerificationCancel;
      default:
        return l10n.stateVerificationEvent;
    }
  }
}
