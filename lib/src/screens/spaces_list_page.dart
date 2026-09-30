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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_rows.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:provider/provider.dart';

/// Every space the user has joined, as a standalone page.
///
/// The single-pane shell needs somewhere for its Spaces destination to
/// land. The dashboard gets it from the sidebar's Spaces section, which is
/// private to that widget and cannot be mounted as a page, so this is a
/// thin page over the two pieces that can be: [SyncPulse] for refreshes and
/// the shared [roomIsSpace] filter so "is this a space" is answered in the
/// same place for every surface.
///
/// It deliberately does not reproduce the sidebar's grouping, ordering or
/// drag-to-reorder. Those are a navigation-sidebar affordance built on
/// `SpacePreferences`; duplicating them here would be a second
/// implementation of the same idea, which is the thing the dashboard
/// unification just removed. A space's home page remains one tap away.
class SpacesListPage extends StatelessWidget {
  const SpacesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: context.watch<SyncPulse>(),
      builder: (context, _) {
        final client = context.read<Client>();
        final spaces =
            client.rooms.where(roomIsSpace).toList(growable: false);

        if (spaces.isEmpty) {
          return EmptyState(
            icon: LucideIcons.layoutGrid,
            title: l10n.spaces,
            message: l10n.noRoomsYet,
          );
        }

        spaces.sort((Room a, Room b) => a
            .getLocalizedDisplayname()
            .toLowerCase()
            .compareTo(b.getLocalizedDisplayname().toLowerCase()));

        return ListView.builder(
          itemCount: spaces.length,
          itemBuilder: (context, index) {
            final Room space = spaces[index];
            return SpaceRow(
              space: space,
              selected: false,
              theme: Theme.of(context),
              onTap: () => context.push(
                '/main/space/${Uri.encodeComponent(space.id)}',
              ),
            );
          },
        );
      },
    );
  }
}