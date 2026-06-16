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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/widgets/own_profile_bar.dart';
import 'package:provider/provider.dart';

/// A bottom bar for the sidebar pane that shows the user's profile.
///
/// Tapping the bar navigates to the Hub screen.
class PermanentPaneBottomItems extends StatelessWidget {
  const PermanentPaneBottomItems({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);

    return GestureDetector(
      onTap: () => context.push('/main/myprofile'),
      child: OwnProfileBar(client: client),
    );
  }
}
