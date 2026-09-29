// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';

class ProfileOverlayPage extends StatelessWidget {
  const ProfileOverlayPage({
    super.key,
    required this.client,
    required this.userId,
    this.room,
  });

  final Client client;
  final String userId;
  final Room? room;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      // Wrap the page body in a fullscreen outside-tap detector so
      // tapping the dim background dismisses the profile overlay.  The
      // PageRoute's barrierDismissible flag is not sufficient on its
      // own because the page is laid out over the barrier; see
      // [BarrierDismissableOverlay] for the full rationale.  The
      // card is wrapped in [BarrierDismissBoundary] so taps inside
      // the profile (including empty padding) don't dismiss it.
      child: BarrierDismissableOverlay(
        // Plain dim background (not blur) so the underlying chat stays
        // legible and the user can still see what they were looking at.
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BarrierDismissBoundary(
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).colorScheme.surface,
                    child: ProfilePage(
                      client: client,
                      userID: userId,
                      room: room,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
