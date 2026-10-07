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
import 'package:moonrelay/src/services/presence_service.dart';
import 'package:provider/provider.dart';

/// Feeds pointer, keyboard and lifecycle activity to the
/// [PresenceService].
///
/// Wraps the whole app rather than each screen, so typing in the
/// composer, scrolling the timeline and clicking anywhere all count,
/// and so navigating cannot reset the idle window.
///
/// Both handlers are passive: they call [PresenceService.noteActivity],
/// which only does work when the account is currently published offline,
/// so this is cheap enough to sit on the hot path of every event.
///
/// Also the app's only [WidgetsBindingObserver], which it needs for the
/// resume case. A desktop machine that suspends has no timer ticks, so
/// without this the account would stay published as online through a
/// sleep and only be corrected the next time something happened to wake
/// the idle window.
class ActivityTracker extends StatefulWidget {
  const ActivityTracker({super.key, required this.child});

  final Widget child;

  @override
  State<ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends State<ActivityTracker>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Read rather than watch: this runs outside a build, and a missing
    // service just means nothing to re-evaluate.
    context.read<PresenceService?>()?.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    final presence = context.read<PresenceService?>();
    if (presence == null) return widget.child;
    return Focus(
      // An ancestor focus node is in the primary focus's chain, so this
      // receives bubbled key events without stealing focus from the
      // field the user is typing in. `canRequestFocus: false` keeps it
      // out of the tab order, and the ignored result leaves the event
      // for whatever handles it downstream.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        presence.noteActivity();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => presence.noteActivity(),
        onPointerMove: (_) => presence.noteActivity(),
        onPointerSignal: (_) => presence.noteActivity(),
        child: widget.child,
      ),
    );
  }
}
