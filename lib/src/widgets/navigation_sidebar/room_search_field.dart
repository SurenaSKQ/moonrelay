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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The room filter, published so the list can read it.
///
/// A `TextEditingController` plus a `ValueNotifier<String>` rather than a
/// stateful parent. The sidebar is not a `StatefulWidget` and making it one
/// to hold a text field would rebuild the whole column, rooms included, on
/// every keystroke. The list subscribes to the notifier; the controller is
/// read directly for the text.
class RoomSearchQuery {
  const RoomSearchQuery._();

  /// The field the room list reads.
  static final ValueNotifier<String> query = ValueNotifier<String>('');

  /// The text controller, so the field and the empty-state button can agree.
  static final TextEditingController controller = TextEditingController();

  /// Clears the filter and the field together.
  static void clear() {
    controller.clear();
    if (query.value.isNotEmpty) query.value = '';
  }
}

/// The search field at the top of the room list.
///
/// The room list had no filter of its own. Global search existed behind the
/// command palette's shortcut, which means anyone who does not know it is
/// looking at an unfiltered list of everything they have ever joined with no
/// way to narrow it. A hundred rooms is not a scannable number.
class RoomSearchField extends StatelessWidget {
  const RoomSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(t.spaceSm, t.spaceSm, t.spaceSm, t.spaceSm),
      child: ValueListenableBuilder<String>(
        valueListenable: RoomSearchQuery.query,
        builder: (context, query, _) {
          return TextField(
            controller: RoomSearchQuery.controller,
            onChanged: (value) => RoomSearchQuery.query.value = value,
            style: TextStyle(
              fontSize: t.spaceSm + 6,
              color: scheme.onSurface,
            ),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.filterRoomsPlaceholder,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spaceSm,
                vertical: t.spaceSm,
              ),
              prefixIcon: Icon(
                LucideIcons.search,
                size: t.iconSizeSmall,
                color: scheme.onSurfaceVariant,
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: t.iconSizeSmall,
                        color: scheme.onSurfaceVariant,
                      ),
                      tooltip: l10n.clearSearch,
                      onPressed: RoomSearchQuery.clear,
                    ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            );
        },
      ),
    );
  }
}