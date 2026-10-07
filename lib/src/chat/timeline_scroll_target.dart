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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

/// Scroll-targeting helpers shared across the chat timeline.
///
/// All three jump sites in the codebase
/// (`TimelineView._scrollToEventId`, `JumpCoordinator.jumpToEvent`, and
/// `JumpCoordinator._scrollToEvent`) duplicated the same fraction-based
/// scroll-to-index heuristic.  This class centralises that logic so
/// future bug fixes only touch one place.
class TimelineScrollTarget {
  TimelineScrollTarget._();

  /// Scrolls [controller] so that the event at [targetIdx] within a list
  /// of [itemCount] events lands roughly one-third from the top of the
  /// viewport.
  ///
  /// This is used as a fallback when the event widget has not been built
  /// yet (no [GlobalKey] available for [Scrollable.ensureVisible]).  The
  /// caller should have already checked `haveDimensions` and
  /// `hasClients` on the controller position before calling.
  ///
  /// When [skipIfClose] is `true`, the scroll is suppressed if the
  /// target is already within 60% of the viewport from the current
  /// scroll position (this avoids a jarring snap when the user is
  /// already near the target).
  ///
  /// [duration] is passed in rather than read from a token because this is a
  /// static helper with no [BuildContext], and the user's animation
  /// preference lives behind one.  Callers pass `Motion.of(context).duration(..)`,
  /// which is [Duration.zero] when the user has turned animations off, so
  /// the timeline's jumps honour the preference instead of gliding past
  /// thirty messages regardless of it.
  static void scrollToFraction(
    ScrollController controller,
    int targetIdx,
    int itemCount, {
    bool skipIfClose = true,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) {
    final position = controller.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = itemCount > 1 ? targetIdx / (itemCount - 1) : 0.0;
    final targetOffset = position.minScrollExtent + range * fraction;

    if (skipIfClose) {
      final distancePx = (targetOffset - position.pixels).abs();
      final viewportHeight = position.viewportDimension;
      if (distancePx < viewportHeight * 0.6) return;
    }

    final paddedOffset = (targetOffset - position.viewportDimension * 0.33)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    controller.animateTo(
      paddedOffset,
      duration: duration,
      curve: curve,
    );
  }
}
