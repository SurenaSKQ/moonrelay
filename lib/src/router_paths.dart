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

/// The route patterns the shell chrome has to reason about.
///
/// These live outside `router.dart` so that shell widgets can name the
/// routes they decorate without importing the router that mounts them,
/// which would be a cycle: the router imports the layouts, not the other
/// way round.
///
/// Each pattern is a list of path segments. A segment starting with `:`
/// matches any single non-empty segment; anything else matches literally.
/// Patterns are compared against `Uri.pathSegments`, so a room id
/// containing a percent sign or a colon cannot be mistaken for structure.
class MoonRoutePaths {
  const MoonRoutePaths._();

  /// The room list landing page.
  static const String roomListTemplate = '/main/rooms';

  /// The room chat page: a single room's timeline and composer.
  static const String roomChatTemplate = '/main/rooms/:roomid';

  /// Every space the user has joined.
  static const String spacesTemplate = '/main/spaces';

  /// Global search across rooms, spaces, messages and users.

  /// The create-room form.
  ///
  /// This route did not exist until the create form was wired up. The page
  /// itself has been in the tree for a while with no call site anywhere,
  /// which meant the app could render a "create a room" affordance with
  /// nowhere to send it. Two paths rather than one with a flag, because the
  /// shell treats a space and a room as different destinations for the back
  /// stack and a query parameter would have to be threaded through that.
  static const String createRoomPath = '/main/newroom';

  /// The create-space form.
  static const String createSpacePath = '/main/newspace';

  /// The one page for making or finding a room or a space.
  ///
  /// Replaces three separate destinations: this, /main/newroom and
  /// /main/newspace. Creating a room and joining one were different pages
  /// doing different halves of the same question, and the rail had a + that
  /// could only create a space while the room list had one that could only
  /// create a room.
  static const String explorePath = '/main/explore';

  /// The explore page with its mode chosen in the URL.
  ///
  /// A query rather than a path segment because the mode is a view state, not
  /// a destination: /main/explore?mode=create and /main/explore are the
  /// same page in two conditions, and the back button should treat them as one.
  static const String exploreCreatePath = '/main/explore?mode=create';

  /// The signed-in user's own profile and account settings.
  static const String youTemplate = '/main/me';

  /// The hub. A category is required; the bare path redirects.
  static const String hubTemplate = '/hub/:category';

  /// A hub sub-item, e.g. `/hub/settings/layout`.
  static const String hubSubTemplate = '/hub/:category/:sub';

  /// The hub's index. This is the profile, not a section of its own, so
  /// there is nothing to redirect: `/hub` renders it directly.
  ///
  /// `profile` used to be a fourth category alongside App Settings,
  /// Accounts and About, which made the index page and the profile page two
  /// different things holding the same editor. Collapsing them means the
  /// profile is where the hub starts, which is also what makes the narrow
  /// index page read as "your profile, then the list of places you can go".
  static const String hubIndex = '/hub';

  /// The room list, as the segment pattern the matchers compare against.
  static final List<String> roomList = _segmentsOf(roomListTemplate);

  /// The room chat, as the segment pattern the matchers compare against.
  static final List<String> roomChat = _segmentsOf(roomChatTemplate);

  static List<String> _segmentsOf(String template) => template
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .toList(growable: false);

  /// The room chat path for [roomId], percent-encoded for the path segment.
  ///
  /// GoRouter percent-decodes `pathParameters` on the way back out, so a
  /// room id that is put into a path here has to be encoded or the second
  /// pass mangles it. A literal `%` is legal in a Matrix room id, so this
  /// is not hypothetical.
  ///
  /// Pass [query] to attach query parameters, e.g. `event` to have the
  /// timeline focus a permalinked message. Values are encoded here for the
  /// same reason the room id is.
  static String roomChatPath(String roomId, {Map<String, String>? query}) {
    final path = '$roomListTemplate/${Uri.encodeComponent(roomId)}';
    if (query == null || query.isEmpty) return path;
    final encoded = query.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$path?$encoded';
  }
}

/// The hub path for a section, optionally one of its sub-items.
///
/// The one place a hub URL is built. Before the hub was a route this was
/// duplicated as string literals in the command palette (nine of them, one
/// of which named a sub-item that did not exist), so the keys now live in
/// `HubRouteKeys` and this is the only place that joins them.
///
/// A null [category] is the index page.
String hubPath({String? category, String? sub}) {
  if (category == null || category.isEmpty) return MoonRoutePaths.hubIndex;
  if (sub == null || sub.isEmpty) return '/hub/$category';
  return '/hub/$category/$sub';
}

/// The top-level destinations of the single-pane shell's navigation bar.
///
/// These are real routes rather than the `NavigationState` sentinels
/// (`___home___`, `___all___`) the dashboard sidebar uses, for two reasons.
/// A sentinel is not a location, so it cannot be deep linked or arrived at
/// from a cold start; and the shell cannot tell which destination is
/// selected without asking something that already knows, which is what the
/// matched route is.
enum FocusDestination {
  /// Joined rooms. Shares its route with the dashboard's room list.
  chats(MoonRoutePaths.roomListTemplate),

  /// Every joined space.
  spaces(MoonRoutePaths.spacesTemplate),

  /// The signed-in user.
  you(MoonRoutePaths.youTemplate);

  const FocusDestination(this.template);

  /// The declared route path, without a leading segment placeholder.
  final String template;

  /// The path to `go` to in order to select this destination.
  String get path => template;

  /// This destination's path as segments, for comparison against
  /// `Uri.pathSegments`.
  List<String> get segments => template
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .toList(growable: false);
}

/// The destination [segments] name, or null if they name something else.
///
/// Length-exact, like the other matchers here. `/main/rooms/:roomid` is one
/// segment deeper than the chats destination and must not select it, or the
/// bar would light up "Chats" while the user is reading a conversation,
/// which is at least defensible, and light up "Chats" on `/main/rooms/:id/
/// settings`, which is not.
FocusDestination? focusDestinationForSegments(List<String> segments) {
  for (final FocusDestination destination in FocusDestination.values) {
    if (_matchesPattern(segments, destination.segments)) return destination;
  }
  return null;
}

/// True when [segments] match [pattern] exactly, in length and position.
bool _matchesPattern(List<String> segments, List<String> pattern) {
  if (segments.length != pattern.length) return false;
  for (int i = 0; i < pattern.length; i++) {
    final String want = pattern[i];
    if (want.startsWith(':')) {
      if (segments[i].isEmpty) return false;
      continue;
    }
    if (segments[i] != want) return false;
  }
  return true;
}

/// True when [segments] name the room chat page itself.
///
/// The length check is the load-bearing part. A prefix or
/// parameter-presence test is what made the single-pane shell stack a
/// second back arrow above the one `RoomSettingsPage`, `ThreadViewPage` and
/// The room sub-pages already render in their own `AppBar`: they are all
/// children of the room route, so "does this location mention a roomid"
/// was true for every one of them.
bool isRoomChatSegments(List<String> segments) =>
    _matchesPattern(segments, MoonRoutePaths.roomChat);

/// True when [segments] name the room list landing page.
bool isRoomListSegments(List<String> segments) =>
    _matchesPattern(segments, MoonRoutePaths.roomList);

/// Whether the current location is inside the room flow at all: the chat
/// itself, or any of its sub-pages.
///
/// Deliberately a prefix test, unlike [isRoomChatSegments]. The question
/// this answers is "is the user somewhere in a conversation", and a room's
/// settings, thread and room-info pages are all somewhere in a
/// conversation. [isRoomChatSegments] had to stay an exact test for the
/// shell's chrome, where a sub-page renders its own `AppBar` and a second
/// back arrow on top of it is the bug.
bool isInsideRoomFlow(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) return false;
  final List<String> segments = router.state.uri.pathSegments;
  if (segments.length < MoonRoutePaths.roomChat.length) return false;
  return _matchesPattern(
    segments.sublist(0, MoonRoutePaths.roomChat.length),
    MoonRoutePaths.roomChat,
  );
}

/// Whether the page currently on screen is the room chat.
bool isRoomChatLocation(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) return false;
  return isRoomChatSegments(router.state.uri.pathSegments);
}

/// The destination the shell's navigation bar should show as selected, or
/// null when the current page is not a destination at all (a room, a room
/// sub-page, a profile, settings).
///
/// A null result is what makes the shell hide its bottom bar: a
/// conversation is not a tab.
FocusDestination? focusDestinationOf(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) return null;
  return focusDestinationForSegments(router.state.uri.pathSegments);
}

/// Whether the current page is one of the shell's own destinations, i.e.
/// a destination the shell decorates itself.
///
/// Every route that is *not* a shell destination is expected to render an
/// `AppBar` of its own, which already carries a back button through
/// `automaticallyImplyLeading`. The shell adding a second one on top of
/// that is what produced the doubled header bar on every pushed sub-page.
bool isShellDestination(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) return true;
  final List<String> segments = router.state.uri.pathSegments;
  return isRoomListSegments(segments) ||
      isRoomChatSegments(segments) ||
      focusDestinationForSegments(segments) != null;
}
