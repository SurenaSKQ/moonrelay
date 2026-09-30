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

// Command palette (`Ctrl+Shift+P`).
//
// Inspired by VSCode's command palette.  When opened, the input is
// empty and the user sees recents (recently used actions and
// recently visited rooms).  As soon as the user types, the palette
// infers a "mode" from the leading character:
//
// - default (`""`): filter the static command list.
// - `?`:  full backend search (rooms/spaces/messages/users/homeserver).
// - `>`:  filter settings pages.
// - `#`:  restrict to joined rooms/spaces.
// - `@`:  restrict to the user directory.
//
// When the result list overflows the palette the user can scroll
// downwards to fetch the next page; every category progressively
// loads more items, and the relevant pagination cursor is plumbed
// through the search provider.
//
// The previous "global search overlay" used to live alongside this
// palette.  It is gone: every search-backed query, including the
// recents lists, runs through the same provider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_commands.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_models.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';
import 'package:provider/provider.dart';

/// Shows the command palette as a modal route.
Future<void> showCommandPalette(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => const _CommandPalettePage(),
    ),
  );
}

class _CommandPalettePage extends StatefulWidget {
  const _CommandPalettePage();

  @override
  State<_CommandPalettePage> createState() => _CommandPalettePageState();
}

/// Helper struct that lets the parallel `Future.wait` in
/// [_CommandPalettePageState._runFullSearchFirst] collect
/// heterogeneous `SearchPage` results without a fan-out of

class _CommandPalettePageState extends State<_CommandPalettePage> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _resultsScroll = ScrollController();

  Timer? _debounce;

  String _rawText = '';
  PaletteMode _mode = PaletteMode.commands;
  String _query = '';

  // Aggregated paginated state for search-driven modes.  Each list has
  // a parallel `hasMore*` flag plus a continuation cursor (`nextBatch*`
  // for server-side cursors, `offset*` for local-cache pagination).
  List<Room> _matchedRooms = [];
  List<Room> _matchedSpaces = [];
  List<MessageSearchResult> _msgResults = [];
  List<Profile> _userResults = [];
  List<PublishedRoomsChunk> _homeserverResults = [];
  String? _nextBatchMessages;
  String? _nextBatchHomeserver;
  int _roomsOffset = 0;
  int _spacesOffset = 0;
  int _usersOffset = 0;
  bool _hasMoreMessages = false;
  bool _hasMoreHomeserver = false;
  bool _hasMoreRooms = false;
  bool _hasMoreSpaces = false;
  bool _hasMoreUsers = false;

  // Loading guard: when a list has scrolled to its bottom we request
  // the next page; the in-flight flag prevents duplicate requests.
  // We track per-category flags so scroll-driven pagination in the
  // `?` (search) mode can fetch from every category that still has
  // results in parallel without one in-flight call blocking the rest.
  bool _isInitialSearch = false;
  bool _isInitialUsers = false;
  bool _isPaginatingMessages = false;
  bool _isPaginatingHomeserver = false;
  bool _isPaginatingRooms = false;
  bool _isPaginatingSpaces = false;
  bool _isPaginatingUsers = false;

  // Cache the most recent localisation so widgets that read it
  // inside [build] don't have to do an O(1) but unmemoised lookup
  // each time they're constructed.
  late AppLocalizations _locCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _ctl.addListener(_onChanged);
    _resultsScroll.addListener(_onResultsScroll);
    RecentActivity.instance.addListener(_onRecentsChanged);
  }

  @override
  void dispose() {
    RecentActivity.instance.removeListener(_onRecentsChanged);
    _resultsScroll.removeListener(_onResultsScroll);
    _debounce?.cancel();
    _ctl.removeListener(_onChanged);
    _ctl.dispose();
    _focus.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  void _onRecentsChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _rawText = _ctl.text;
        _mode = _detectMode(_rawText);
        _query = _stripPrefix(_rawText, _mode);
      });
      _kickoffSearch();
    });
  }

  PaletteMode _detectMode(String input) {
    if (input.isEmpty) return PaletteMode.commands;
    final first = input[0];
    switch (first) {
      case '?':
        return PaletteMode.search;
      case '>':
        return PaletteMode.settings;
      case '#':
        return PaletteMode.rooms;
      case '@':
        return PaletteMode.users;
    }
    return PaletteMode.commands;
  }

  String _stripPrefix(String input, PaletteMode mode) {
    if (mode == PaletteMode.commands) return input.trim();
    return input.substring(1).trim();
  }

  // -- Search dispatch ------------------------------------------------

  /// Trigger the appropriate first-page fetch for the current mode.
  /// Resets pagination cursors so the user sees a clean slate when
  /// the query / mode changes.
  void _kickoffSearch() {
    // Anything other than the empty commands/settings modes goes
    // through the search provider.
    switch (_mode) {
      case PaletteMode.search:
        if (_query.isEmpty) {
          _resetSearchLists();
          return;
        }
        _runFullSearchFirst(_query);
        break;
      case PaletteMode.rooms:
        _runRoomsFirst(_query);
        break;
      case PaletteMode.users:
        _runUsersFirst(_query);
        break;
      case PaletteMode.settings:
        // Settings list is filtered synchronously in build().
        setState(() {});
        break;
      case PaletteMode.commands:
        // Commands list is filtered synchronously in build().
        setState(() {});
        break;
    }
  }

  void _resetSearchLists() {
    setState(() {
      _matchedRooms = [];
      _matchedSpaces = [];
      _msgResults = [];
      _userResults = [];
      _homeserverResults = [];
      _roomsOffset = 0;
      _spacesOffset = 0;
      _usersOffset = 0;
      _nextBatchMessages = null;
      _nextBatchHomeserver = null;
      _hasMoreMessages = false;
      _hasMoreHomeserver = false;
      _hasMoreRooms = false;
      _hasMoreSpaces = false;
      _hasMoreUsers = false;
      _isInitialSearch = false;
      _isInitialUsers = false;
    });
  }

  Future<void> _runFullSearchFirst(String query) async {
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() {
      // Reset everything; we'll replace pieces as each sub-page returns.
      _matchedRooms = [];
      _matchedSpaces = [];
      _msgResults = [];
      _userResults = [];
      _homeserverResults = [];
      _roomsOffset = 0;
      _spacesOffset = 0;
      _usersOffset = 0;
      _nextBatchMessages = null;
      _nextBatchHomeserver = null;
      _isInitialSearch = true;
      _hasMoreMessages = false;
      _hasMoreHomeserver = false;
      _hasMoreUsers = false;
    });

    // Local categories first: synchronous.
    final localRooms = provider.searchRoomsFirstPage(query, limit: 10);
    final localSpaces = provider.searchSpacesFirstPage(query, limit: 5);

    setState(() {
      _matchedRooms = localRooms.items;
      _matchedSpaces = localSpaces.items;
      _roomsOffset = localRooms.items.length;
      _spacesOffset = localSpaces.items.length;
      _hasMoreRooms = localRooms.hasMore;
      _hasMoreSpaces = localSpaces.hasMore;
    });

    // Server-side message search, homeserver public rooms, and
    // user-directory search all run in parallel; the user sees the
    // local rooms/spaces immediately, then each server result
    // streams in as it returns.  Each sub-page is independent so a
    // slow homeserver doesn't block messages, and vice versa.
    final results = await Future.wait<InitialSearchResult>([
      provider.searchMessagesFirstPage(query, limit: 20).then(
        (v) => InitialSearchResult(messages: v),
        onError: (_) => InitialSearchResult.empty(),
      ),
      provider.searchHomeserverFirstPage(query, limit: 10).then(
        (v) => InitialSearchResult(homeserver: v),
        onError: (_) => InitialSearchResult.empty(),
      ),
      provider.fetchUsersPage(query, limit: 10).then(
        (v) => InitialSearchResult(users: v),
        onError: (_) => InitialSearchResult.empty(),
      ),
    ]);
    if (!mounted) return;
    final messages = results[0].messages;
    final homeserver = results[1].homeserver;
    final users = results[2].users;
    setState(() {
      if (messages != null) {
        _msgResults = messages.items;
        _nextBatchMessages = messages.nextBatch;
        _hasMoreMessages = messages.hasMore;
      }
      if (homeserver != null) {
        _homeserverResults = homeserver.items;
        _nextBatchHomeserver = homeserver.nextBatch;
        _hasMoreHomeserver = homeserver.hasMore;
      }
      if (users != null) {
        _userResults = users.items;
        _usersOffset = users.items.length;
        _hasMoreUsers = users.hasMore;
      }
      _isInitialSearch = false;
    });
  }

  Future<void> _runFullSearchMoreMessages() async {
    if (_isPaginatingMessages || !_hasMoreMessages) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginatingMessages = true);
    try {
      final page = await provider.searchMessagesNextPage(
        SearchPageRequest(query: _query, nextBatch: _nextBatchMessages),
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _msgResults = [..._msgResults, ...page.items];
        _nextBatchMessages = page.nextBatch;
        _hasMoreMessages = page.hasMore;
        _isPaginatingMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaginatingMessages = false);
    }
  }

  Future<void> _runFullSearchMoreHomeserver() async {
    if (_isPaginatingHomeserver || !_hasMoreHomeserver) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginatingHomeserver = true);
    try {
      final page = await provider.searchHomeserverNextPage(
        SearchPageRequest(query: _query, nextBatch: _nextBatchHomeserver),
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _homeserverResults = [..._homeserverResults, ...page.items];
        _nextBatchHomeserver = page.nextBatch;
        _hasMoreHomeserver = page.hasMore;
        _isPaginatingHomeserver = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaginatingHomeserver = false);
    }
  }

  Future<void> _runFullSearchMoreUsers() async {
    if (_isPaginatingUsers || !_hasMoreUsers) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginatingUsers = true);
    try {
      final page = provider.nextUsersPage(
        SearchPageRequest(query: _query, offset: _usersOffset),
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _userResults = [..._userResults, ...page.items];
        _usersOffset += page.items.length;
        _hasMoreUsers = page.hasMore;
        _isPaginatingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaginatingUsers = false);
    }
  }

  void _runRoomsFirst(String query) {
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    final rooms = provider.searchRoomsFirstPage(query, limit: 10);
    final spaces = provider.searchSpacesFirstPage(query, limit: 10);
    setState(() {
      _matchedRooms = rooms.items;
      _matchedSpaces = spaces.items;
      _roomsOffset = rooms.items.length;
      _spacesOffset = spaces.items.length;
      _hasMoreRooms = rooms.hasMore;
      _hasMoreSpaces = spaces.hasMore;
    });
  }

  Future<void> _runRoomsMore() async {
    // Local-cache pagination is synchronous, so we just guard with
    // a single flag and fan out the room/space pages inside.
    if (_isPaginatingRooms || _isPaginatingSpaces) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() {
      _isPaginatingRooms = _hasMoreRooms;
      _isPaginatingSpaces = _hasMoreSpaces;
    });
    if (_hasMoreRooms) {
      final rooms = provider.nextRoomsPage(
        SearchPageRequest(query: _query, offset: _roomsOffset),
        limit: 10,
      );
      setState(() {
        _matchedRooms = [..._matchedRooms, ...rooms.items];
        _roomsOffset += rooms.items.length;
        _hasMoreRooms = rooms.hasMore;
        _isPaginatingRooms = false;
      });
    }
    if (_hasMoreSpaces) {
      final spaces = provider.nextSpacesPage(
        SearchPageRequest(query: _query, offset: _spacesOffset),
        limit: 10,
      );
      setState(() {
        _matchedSpaces = [..._matchedSpaces, ...spaces.items];
        _spacesOffset += spaces.items.length;
        _hasMoreSpaces = spaces.hasMore;
        _isPaginatingSpaces = false;
      });
    }
    // Defensive: clear any flags that may have been set above but
    // didn't get a chance to clear because the matching hasMore was
    // false on entry.  Without this, a 0-item pagination would leave
    // the spinner spinning forever.
    if (!mounted) return;
    setState(() {
      _isPaginatingRooms = false;
      _isPaginatingSpaces = false;
    });
  }

  Future<void> _runUsersFirst(String query) async {
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _usersOffset = 0;
        _hasMoreUsers = false;
        _isInitialUsers = false;
      });
      return;
    }
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isInitialUsers = true);
    try {
      final page = await provider.fetchUsersPage(query, limit: 10);
      if (!mounted) return;
      setState(() {
        _userResults = page.items;
        _usersOffset = page.items.length;
        _hasMoreUsers = page.hasMore;
        _isInitialUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isInitialUsers = false);
    }
  }

  Future<void> _runUsersMore() async {
    if (_isPaginatingUsers || !_hasMoreUsers) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginatingUsers = true);
    final page = provider.nextUsersPage(
      SearchPageRequest(query: _query, offset: _usersOffset),
      limit: 10,
    );
    setState(() {
      _userResults = [..._userResults, ...page.items];
      _usersOffset += page.items.length;
      _hasMoreUsers = page.hasMore;
      _isPaginatingUsers = false;
    });
  }

  // -- Scroll-driven pagination -------------------------------------

  /// Detects when the user has scrolled near the bottom of the
  /// results list and kicks off the appropriate next-page fetch.
  ///
  /// In the `?` (search) mode we fire every category that still
  /// has more results in parallel.  The previous implementation
  /// picked a single category per scroll-tick and walked the
  /// priority list (messages -> homeserver -> rooms) which meant
  /// hundreds of pixels of scroll were needed to drain each
  /// category in turn.  Firing them in parallel keeps the result
  /// list "topped up" smoothly without one slow endpoint blocking
  /// the rest.
  void _onResultsScroll() {
    if (!_resultsScroll.hasClients) return;
    final pos = _resultsScroll.position;
    // Threshold matches the timeline scroll-to-load: 150 px.
    final atEnd = pos.pixels >= pos.maxScrollExtent - 150;
    if (!atEnd) return;
    switch (_mode) {
      case PaletteMode.search:
        // Local categories first; they're synchronous, so the
        // user sees the new entries immediately on the next frame.
        if (_hasMoreRooms || _hasMoreSpaces) _runRoomsMore();
        // Server-side categories: fire all in parallel; the
        // per-paginator flags prevent duplicate in-flight requests.
        if (_hasMoreMessages) _runFullSearchMoreMessages();
        if (_hasMoreHomeserver) _runFullSearchMoreHomeserver();
        if (_hasMoreUsers) _runFullSearchMoreUsers();
        break;
      case PaletteMode.rooms:
        _runRoomsMore();
        break;
      case PaletteMode.users:
        _runUsersMore();
        break;
      case PaletteMode.commands:
      case PaletteMode.settings:
        break;
    }
  }

  // -- Run helpers ----------------------------------------------------

  void _runAction(CommandAction action) {
    // Pop first so the callback receives a context that lives in the
    // parent route: calling Navigator.pop from inside the callback
    // would pop whatever the callback just pushed.
    Navigator.of(context).pop();
    if (!mounted) return;
    RecentActivity.instance.recordAction(action.key);
    action.callback(context);
  }

  void _runRoom(Room room) {
    Navigator.of(context).pop();
    if (!mounted) return;
    RecentActivity.instance.recordRoom(room.id);
    openRoom(context, room.id);
  }

  /// Opens the selected settings location, which is a real hub route
  /// (e.g. `/hub/settings/appearance`).
  ///
  /// `push`, so the palette closes and the hub covers the window with the
  /// chat still underneath it. This is what the modal overlay was for; the
  /// overlay is gone and the route does the same job, except that the URL
  /// now matches what is on screen and a stale `/hub/...` link from the
  /// palette resolves instead of silently rendering an empty pane.
  void _openSettingsRoute(String path) {
    Navigator.of(context).pop();
    if (!mounted) return;
    context.push(path);
  }

  void _runMessage(MessageSearchResult msg) {
    Navigator.of(context).pop();
    if (!mounted) return;
    RecentActivity.instance.recordRoom(msg.room.id);
    openRoom(context, msg.room.id);
  }

  void _runUser(Profile user) {
    Navigator.of(context).pop();
    if (!mounted) return;
    // The profile is decoupled from the room route: push the top-level
    // profile route.  The router redirects to /main/myprofile when the
    // userid matches the active account.
    final encoded = Uri.encodeComponent(user.userId);
    context.go('/profile/$encoded');
  }

  void _runHomeserverRoom(PublishedRoomsChunk room) {
    // Homeserver rooms are not yet joined, so /main/rooms/:roomid (which
    // expects RoomResolver to find the room) would spin forever.  Use
    // the dedicated preview route instead.
    Navigator.of(context).pop();
    if (!mounted) return;
    context.go('/main/room_preview/${room.roomId}');
  }

  // -- Build ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _locCache = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Material(
      color: Colors.transparent,
      // Wrap the page body in a fullscreen outside-tap detector so
      // tapping the dimmed background dismisses the palette.  The
      // PageRoute's barrierDismissible flag is not sufficient because
      // the page is laid out over the barrier in the overlay and the
      // barrier's gesture detector loses the gesture arena.  See
      // [BarrierDismissableOverlay] for the full rationale.  The
      // card itself is wrapped in [BarrierDismissBoundary] so taps
      // inside the palette (including the empty padding around
      // widgets) don't dismiss the overlay.
      child: BarrierDismissableOverlay(
        child: BlurBackground(
          overlayColor: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.all(t.spaceXl),
                child: BarrierDismissBoundary(
                  child: Material(
                    elevation: t.elevationOverlay,
                    borderRadius: BorderRadius.circular(t.radiusLg),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: EdgeInsets.all(t.spaceLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInput(_locCache),
                          SizedBox(height: t.spaceSm),
                          _buildModeHint(_locCache),
                          SizedBox(height: t.spaceSm),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 420),
                            child: _buildList(_locCache),
                          ),
                        ],
                      ),
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

  Widget _buildInput(AppLocalizations loc) {
    return TextField(
      controller: _ctl,
      focusNode: _focus,
      autofocus: true,
      decoration: InputDecoration(
        prefixIcon: Icon(_modeIcon(_mode)),
        hintText: _hintForMode(loc, _mode),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) {
        final results = _currentResults(loc);
        if (results.length == 1) {
          results.first.run();
        }
      },
    );
  }

  /// Inline pill explaining what mode the palette is currently in.
  Widget _buildModeHint(AppLocalizations loc) {
    final hint = switch (_mode) {
      PaletteMode.commands => loc.commandPaletteHint,
      PaletteMode.search => loc.commandPaletteModeSearch,
      PaletteMode.settings => loc.commandPaletteModeSettings,
      PaletteMode.rooms => loc.commandPaletteModeRooms,
      PaletteMode.users => loc.commandPaletteModeUsers,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Icon(
            _modeIcon(_mode),
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(PaletteMode mode) => switch (mode) {
        PaletteMode.commands => LucideIcons.command,
        PaletteMode.search => LucideIcons.search,
        PaletteMode.settings => LucideIcons.settings,
        PaletteMode.rooms => LucideIcons.hash,
        PaletteMode.users => LucideIcons.atSign,
      };

  String _hintForMode(AppLocalizations loc, PaletteMode mode) =>
      switch (mode) {
        PaletteMode.commands => loc.commandPaletteHint,
        PaletteMode.search => loc.commandPaletteSearchHint,
        PaletteMode.settings => loc.commandPaletteSettingsHint,
        PaletteMode.rooms => loc.commandPaletteRoomsHint,
        PaletteMode.users => loc.commandPaletteUsersHint,
      };

  // -- Mode-specific list builders -----------------------------------

  Widget _buildList(AppLocalizations loc) {
    switch (_mode) {
      case PaletteMode.commands:
        return _buildCommandsList(loc);
      case PaletteMode.settings:
        return _buildSettingsList(loc);
      case PaletteMode.rooms:
        return _buildRoomsList(loc);
      case PaletteMode.users:
        return _buildUsersList(loc);
      case PaletteMode.search:
        return _buildSearchList(loc);
    }
  }

  Widget _buildCommandsList(AppLocalizations loc) {
    final actions = buildPaletteActions(context, loc);
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? actions
        : actions
            .where((a) =>
                a.label.toLowerCase().contains(q) ||
                a.key.toLowerCase().contains(q))
            .toList(growable: false);

    if (filtered.isEmpty && q.isNotEmpty) {
      return Center(child: Text(loc.commandPaletteNoResults));
    }

    return ListView(
      controller: _resultsScroll,
      shrinkWrap: true,
      children: [
        if (filtered.isNotEmpty) _sectionHeader(loc.commandPaletteActions),
        for (final action in filtered)
          _recencyRow(
            key: action.key,
            child: ListTile(
              dense: true,
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () => _runAction(action),
            ),
          ),
        ..._buildRecentSection(loc),
        ..._buildRecentRoomsSection(loc),
      ],
    );
  }

  Widget _buildSettingsList(AppLocalizations loc) {
    final entries = buildSettingsEntries(loc);
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? entries
        : entries
            .where((e) =>
                e.label.toLowerCase().contains(q) ||
                e.description.toLowerCase().contains(q))
            .toList(growable: false);

    if (filtered.isEmpty) {
      return Center(child: Text(loc.commandPaletteNoResults));
    }

    return ListView(
      controller: _resultsScroll,
      shrinkWrap: true,
      children: [
        _sectionHeader(loc.commandPaletteActions),
        for (final entry in filtered)
          ListTile(
            dense: true,
            leading: Icon(entry.icon),
            title: Text(entry.label),
            subtitle: entry.description.isNotEmpty
                ? Text(
                    entry.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            onTap: () => _openSettingsRoute(entry.path),
          ),
      ],
    );
  }

  Widget _buildRoomsList(AppLocalizations loc) {
    if (_matchedRooms.isEmpty && _matchedSpaces.isEmpty) {
      return Center(child: Text(loc.commandPaletteNoResults));
    }
    return ListView(
      controller: _resultsScroll,
      shrinkWrap: true,
      children: [
        if (_matchedRooms.isNotEmpty) _sectionHeader(loc.searchRooms),
        for (final r in _matchedRooms)
          SearchRoomTile(room: r, onTap: () => _runRoom(r)),
        if (_matchedSpaces.isNotEmpty) _sectionHeader(loc.searchSpaces),
        for (final s in _matchedSpaces)
          SearchRoomTile(room: s, onTap: () => _runRoom(s)),
        _loadingTail(loc),
      ],
    );
  }

  Widget _buildUsersList(AppLocalizations loc) {
    if (_userResults.isEmpty && !_isInitialUsers && _query.isNotEmpty) {
      return Center(child: Text(loc.commandPaletteNoResults));
    }
    return ListView(
      controller: _resultsScroll,
      shrinkWrap: true,
      children: [
        if (_userResults.isNotEmpty) _sectionHeader(loc.searchUsersResults),
        for (final u in _userResults)
          SearchUserTile(user: u, onTap: () => _runUser(u)),
        _loadingTail(loc),
      ],
    );
  }

  Widget _buildSearchList(AppLocalizations loc) {
    final empty =
        _matchedRooms.isEmpty &&
            _matchedSpaces.isEmpty &&
            _msgResults.isEmpty &&
            _userResults.isEmpty &&
            _homeserverResults.isEmpty &&
            !_isInitialSearch;
    if (empty && _query.isNotEmpty) {
      return Center(child: Text(loc.commandPaletteNoResults));
    }
    return ListView(
      controller: _resultsScroll,
      shrinkWrap: true,
      children: [
        if (_matchedRooms.isNotEmpty) _sectionHeader(loc.searchRooms),
        for (final r in _matchedRooms)
          SearchRoomTile(room: r, onTap: () => _runRoom(r)),
        if (_matchedSpaces.isNotEmpty) _sectionHeader(loc.searchSpaces),
        for (final s in _matchedSpaces)
          SearchRoomTile(room: s, onTap: () => _runRoom(s)),
        if (_msgResults.isNotEmpty) _sectionHeader(loc.searchMessages),
        for (final m in _msgResults)
          SearchMessageTile(result: m, onTap: () => _runMessage(m)),
        if (_userResults.isNotEmpty) _sectionHeader(loc.searchUsersResults),
        for (final u in _userResults)
          SearchUserTile(user: u, onTap: () => _runUser(u)),
        if (_homeserverResults.isNotEmpty) _sectionHeader(loc.searchHomeserver),
        for (final h in _homeserverResults)
          SearchHomeserverTile(room: h, onTap: () => _runHomeserverRoom(h)),
        _loadingTail(loc),
      ],
    );
  }

  /// Spinner / "no more results" footer used by the paginatable
  /// modes.  Showing it at the bottom of every list gives the user
  /// visual feedback that the palette is loading more items.
  Widget _loadingTail(AppLocalizations loc) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final paginating = _isInitialSearch ||
        _isInitialUsers ||
        _isPaginatingMessages ||
        _isPaginatingHomeserver ||
        _isPaginatingUsers ||
        _isPaginatingRooms ||
        _isPaginatingSpaces;
    final hasMore = _mode == PaletteMode.search
        ? (_hasMoreMessages ||
            _hasMoreHomeserver ||
            _hasMoreUsers ||
            _hasMoreRooms ||
            _hasMoreSpaces)
        : _mode == PaletteMode.rooms
            ? (_hasMoreRooms || _hasMoreSpaces)
            : _hasMoreUsers;
    if (paginating) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: t.spaceMd),
        child: const Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore && _query.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: t.spaceMd),
        child: Center(
          child: Text(
            loc.searchNoResults,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(height: t.spaceXs);
  }

  // -- Recents section helpers ----------------------------------------

  List<Widget> _buildRecentSection(AppLocalizations loc) {
    final actions = buildPaletteActions(context, loc);
    final recents = RecentActivity.instance.actions;
    if (recents.isEmpty) return const [];
    return [
      const Divider(height: 24),
      _sectionHeader(loc.commandPaletteRecent),
      for (final key in recents)
        for (final action in actions.where((a) => a.key == key))
          _recencyRow(
            key: key,
            child: ListTile(
              dense: true,
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () => _runAction(action),
            ),
          ),
    ];
  }

  List<Widget> _buildRecentRoomsSection(AppLocalizations loc) {
    final ids = RecentActivity.instance.rooms;
    final client = context.read<Client?>();
    if (client == null || ids.isEmpty) return const [];
    final rooms = <Room>[];
    for (final id in ids) {
      try {
        final r = client.getRoomById(id);
        if (r != null) rooms.add(r);
      } catch (_) {/* ignore */}
    }
    if (rooms.isEmpty) return const [];
    return [
      const Divider(height: 24),
      _sectionHeader(loc.commandPaletteRooms),
      for (final r in rooms)
        SearchRoomTile(
          room: r,
          onTap: () => _runRoom(r),
        ),
    ];
  }

  Widget _recencyRow({required String key, required Widget child}) {
    return KeyedSubtree(key: ValueKey(key), child: child);
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }

  /// Returns the first selectable result for the current mode.  Used
  /// by the "Enter on single match" shortcut.
  List<PaletteResult> _currentResults(AppLocalizations loc) {
    switch (_mode) {
      case PaletteMode.commands:
        final actions = buildPaletteActions(context, loc);
        final q = _query.toLowerCase();
        return [
          for (final a in actions)
            if (a.label.toLowerCase().contains(q) ||
                a.key.toLowerCase().contains(q))
              PaletteResult(() => _runAction(a)),
        ];
      case PaletteMode.settings:
        return [
          for (final e in buildSettingsEntries(loc))
            if (e.label.toLowerCase().contains(_query.toLowerCase()) ||
                e.description.toLowerCase().contains(_query.toLowerCase()))
              PaletteResult(() => _openSettingsRoute(e.path)),
        ];
      case PaletteMode.rooms:
        return [
          for (final r in [..._matchedRooms, ..._matchedSpaces])
            PaletteResult(() => _runRoom(r)),
        ];
      case PaletteMode.users:
        return [
          for (final u in _userResults) PaletteResult(() => _runUser(u)),
        ];
      case PaletteMode.search:
        return [
          for (final r in [..._matchedRooms, ..._matchedSpaces])
            PaletteResult(() => _runRoom(r)),
          for (final m in _msgResults) PaletteResult(() => _runMessage(m)),
          for (final u in _userResults) PaletteResult(() => _runUser(u)),
          for (final h in _homeserverResults)
            PaletteResult(() => _runHomeserverRoom(h)),
        ];
    }
  }
}
