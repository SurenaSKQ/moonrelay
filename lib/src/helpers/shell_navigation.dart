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

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:provider/provider.dart';

// -- Shell-aware navigation ---------------------------------------------------

/// Navigation expressed as intent, with the mechanism chosen here rather
/// than at each call site.
///
/// Two things were wrong with the previous arrangement, and they are the
/// same mistake seen from two ends. `RoomsPane` called `pushReplacement`
/// unconditionally, hard-coding the dashboard's answer into a shared leaf
/// widget, and the single-pane shell then had to paper over it by treating
/// a pop failure as "go back to the list". The room list was destroyed on
/// every room switch, so the user's scroll position, and eventually their
/// search text, died with it, and the shell's back button performed a route
/// reset rather than a pop.
///
/// The split is by intent, not by widget:
///
///  * [openRoom] means "switch to this conversation". It pushes in the
///    single-pane shell, where the list is the only navigation there is and
///    must survive, and replaces on the dashboard, where the list is
///    already on screen beside the room and a growing history would just
///    walk the user backwards through rooms they have already read.
///  * [openRoomSubpage] means "drill into something owned by this room"
///    (settings, room details, a thread). It pushes in both shells,
///    because a back button is the correct affordance for it everywhere.
///
/// Anything that wants to reach a room goes through one of these, so the
/// two shells can never disagree about what "open this room" means.

/// Whether the single-pane shell is the one currently on screen.
bool _isSinglePane(BuildContext context) {
  try {
    return context.read<LayoutShellController>().isMobile;
  } catch (_) {
    // Expected only where a shell is genuinely absent: a widget test or a
    // storybook mounting a room row on its own. Falling back to the
    // dashboard behaviour is the safe direction, because replacing is what
    // every call site did before this seam existed, so a missing provider
    // must not change where the user ends up.
    return false;
  }
}

/// Switches to the chat for [roomId].
///
/// [roomId] is the decoded id as the SDK reports it; this encodes it into
/// the path, which GoRouter decodes again on the way out.
///
/// In the single-pane shell this pushes the first room and *replaces* every
/// room after it. That is the difference between a navigator's back and a
/// user's back, and it was worth getting right rather than leaving to the
/// route stack.
///
/// A `Navigator` pops what was pushed, in the order it was pushed, so
/// room A then room B then Back lands on room A. That is strictly correct
/// and it is not what anyone means by Back in a chat client: switching to
/// another conversation is a lateral move, not a step into a new place, and
/// walking the user back through rooms they have already read is the
/// behaviour that makes a list-backed shell feel like a trapdoor. The
/// dashboard shell already had this right, because it replaces on every
/// open; the single-pane shell pushed, and so accumulated.
///
/// The first room still pushes, because the list underneath has to survive:
/// it is the only navigation the shell has, and replacing it would throw
/// away the user's scroll position and their search text.
void openRoom(BuildContext context, String roomId) {
  final String path = MoonRoutePaths.roomChatPath(roomId);
  if (_isSinglePane(context) && !isInsideRoomFlow(context)) {
    context.push(path);
  } else {
    context.pushReplacement(path);
  }
}

/// Opens [subPath] as a child of the room route, e.g. `settings` or
/// `thread/$eventId`.
///
/// [subPath] is a relative, already-encoded path; each is appended to the
/// room's own path by the router.
void openRoomSubpage(BuildContext context, String roomId, String subPath) {
  context.push('${MoonRoutePaths.roomChatPath(roomId)}/$subPath');
}

/// Leaves the current page, falling back to [fallback] when there is
/// nothing left to pop.
///
/// A pop and a `go` are not interchangeable: one is a history step and the
/// other is a route reset that discards the pages in between. Reaching for
/// a route reset because `canPop()` was false is what turned the
/// single-pane shell's back button into a page rebuild.
void backTo(BuildContext context, {required String fallback}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Returns to the room list, from anywhere inside the room flow.
void backToRoomList(BuildContext context) =>
    backTo(context, fallback: MoonRoutePaths.roomListTemplate);

/// Leaves for the room list, discarding whatever is on the stack.
///
/// The deliberate opposite of [backToRoomList]. Back is a history step and
/// keeps what is behind it, which is right for "undo the last thing I
/// opened" and wrong for "take me out of this whole surface". The hub
/// needs both: Back walks out of the sections it pushed through, and Close
/// drops the lot and goes to the dashboard.
///
/// `go` rather than `pop` on purpose. Popping until the list is reached
/// would mean the user has to press Back once per section they visited to
/// escape a surface they did not think of as a stack in the first place.
void closeToRoomList(BuildContext context) =>
    context.go(MoonRoutePaths.roomListTemplate);

/// Opens the create-room form, optionally pre-set to create a space.
///
/// One route for both, with a flag rather than two paths: the page is the
/// same form with a title and an icon that change, and two routes would mean
/// two ways to be on that screen and therefore two back behaviours.
/// Sends the user to the one page for making or finding a room or a space.
///
/// The sSpace flag went away with the page it used to choose between. A
/// room and a space are the same create call with one flag and the form on the
/// destination already toggles between them, so a second route could only
/// ever be a second URL for the same question.
void openCreateRoom(BuildContext context, {bool asSpace = false}) {
  context.push(
    asSpace ? MoonRoutePaths.createSpacePath : MoonRoutePaths.createRoomPath,
  );
}
