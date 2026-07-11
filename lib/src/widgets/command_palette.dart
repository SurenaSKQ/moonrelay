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
// - **default** (`""`): filter the static command list.
// - **`?`**:  full backend search (rooms/spaces/messages/users/homeserver).
// - **`>`**:  filter settings pages.
// - **`#`**:  restrict to joined rooms/spaces.
// - **`@`**:  restrict to the user directory.
//
// When the result list overflows the palette the user can scroll
// downwards to fetch the next page; every category progressively
// loads more items, and the relevant pagination cursor is plumbed
// through the search provider.
//
// The previous "global search overlay" used to live alongside this
// palette.  It is gone — every search-backed query, including the
// recents lists, runs through the same provider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';
import 'package:provider/provider.dart';

/// Shows the command palette as a modal route.
Future<void> showCommandPalette(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
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

/// The active palette mode.  Determined by the leading character of
/// the input; the rest of the input is the *query*.
enum _PaletteMode {
  /// Filter the static action list by substring.
  commands,

  /// Run a full backend search (rooms/spaces/messages/users/homeserver).
  search,

  /// Filter the in-app settings pages.
  settings,

  /// Restrict search to rooms/spaces.
  rooms,

  /// Restrict search to users.
  users,
}

class _CommandPalettePageState extends State<_CommandPalettePage> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _resultsScroll = ScrollController();

  Timer? _debounce;

  String _rawText = '';
  _PaletteMode _mode = _PaletteMode.commands;
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
  bool _isPaginating = false;
  bool _isInitialSearch = false;
  bool _isInitialUsers = false;

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

  _PaletteMode _detectMode(String input) {
    if (input.isEmpty) return _PaletteMode.commands;
    final first = input[0];
    switch (first) {
      case '?':
        return _PaletteMode.search;
      case '>':
        return _PaletteMode.settings;
      case '#':
        return _PaletteMode.rooms;
      case '@':
        return _PaletteMode.users;
    }
    return _PaletteMode.commands;
  }

  String _stripPrefix(String input, _PaletteMode mode) {
    if (mode == _PaletteMode.commands) return input.trim();
    return input.substring(1).trim();
  }

  // ── Search dispatch ────────────────────────────────────────────────

  /// Trigger the appropriate first-page fetch for the current mode.
  /// Resets pagination cursors so the user sees a clean slate when
  /// the query / mode changes.
  void _kickoffSearch() {
    // Anything other than the empty commands/settings modes goes
    // through the search provider.
    switch (_mode) {
      case _PaletteMode.search:
        if (_query.isEmpty) {
          _resetSearchLists();
          return;
        }
        _runFullSearchFirst(_query);
        break;
      case _PaletteMode.rooms:
        _runRoomsFirst(_query);
        break;
      case _PaletteMode.users:
        _runUsersFirst(_query);
        break;
      case _PaletteMode.settings:
        // Settings list is filtered synchronously in build().
        setState(() {});
        break;
      case _PaletteMode.commands:
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
    });

    // Local categories first — synchronous.
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

    // Server-side message search + homeserver public rooms
    // (in parallel) — both are paged and progressively appended as
    // the user scrolls.
    try {
      final messagesPage = await provider.searchMessagesFirstPage(
        query,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _msgResults = messagesPage.items;
        _nextBatchMessages = messagesPage.nextBatch;
        _hasMoreMessages = messagesPage.hasMore;
      });
    } catch (_) {/* swallow, surface no results */}
    if (!mounted) return;
    try {
      final homeserverPage = await provider.searchHomeserverFirstPage(
        query,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _homeserverResults = homeserverPage.items;
        _nextBatchHomeserver = homeserverPage.nextBatch;
        _hasMoreHomeserver = homeserverPage.hasMore;
        _isInitialSearch = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isInitialSearch = false);
    }
  }

  Future<void> _runFullSearchMoreMessages() async {
    if (_isPaginating || !_hasMoreMessages) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginating = true);
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
        _isPaginating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaginating = false);
    }
  }

  Future<void> _runFullSearchMoreHomeserver() async {
    if (_isPaginating || !_hasMoreHomeserver) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginating = true);
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
        _isPaginating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPaginating = false);
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
    if (_isPaginating) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginating = true);
    // Pages one chunk at a time; the page that hits the cap ends
    // the loop.
    if (_hasMoreRooms) {
      final rooms = provider.nextRoomsPage(
        SearchPageRequest(query: _query, offset: _roomsOffset),
        limit: 10,
      );
      setState(() {
        _matchedRooms = [..._matchedRooms, ...rooms.items];
        _roomsOffset += rooms.items.length;
        _hasMoreRooms = rooms.hasMore;
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
      });
    }
    setState(() => _isPaginating = false);
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
    if (_isPaginating || !_hasMoreUsers) return;
    final client = context.read<Client>();
    final provider = SearchProvider(client: client);
    setState(() => _isPaginating = true);
    final page = provider.nextUsersPage(
      SearchPageRequest(query: _query, offset: _usersOffset),
      limit: 10,
    );
    setState(() {
      _userResults = [..._userResults, ...page.items];
      _usersOffset += page.items.length;
      _hasMoreUsers = page.hasMore;
      _isPaginating = false;
    });
  }

  // ── Scroll-driven pagination ─────────────────────────────────────

  /// Detects when the user has scrolled near the bottom of the
  /// results list and kicks off the appropriate next-page fetch.
  void _onResultsScroll() {
    if (!_resultsScroll.hasClients) return;
    if (_isPaginating) return;
    final pos = _resultsScroll.position;
    // Threshold matches the timeline scroll-to-load: 150 px.
    final atEnd = pos.pixels >= pos.maxScrollExtent - 150;
    if (!atEnd) return;
    switch (_mode) {
      case _PaletteMode.search:
        // Try both paginators in priority order so the user never
        // waits on one when the other has more.
        if (_hasMoreMessages) {
          _runFullSearchMoreMessages();
        } else if (_hasMoreHomeserver) {
          _runFullSearchMoreHomeserver();
        } else {
          _runRoomsMore();
        }
        break;
      case _PaletteMode.rooms:
        _runRoomsMore();
        break;
      case _PaletteMode.users:
        _runUsersMore();
        break;
      case _PaletteMode.commands:
      case _PaletteMode.settings:
        break;
    }
  }

  // ── Run helpers ────────────────────────────────────────────────────

  void _runAction(CommandAction action) {
    Navigator.of(context).pop();
    RecentActivity.instance.recordAction(action.key);
    action.callback(context);
  }

  void _runRoom(Room room) {
    Navigator.of(context).pop();
    RecentActivity.instance.recordRoom(room.id);
    context.go('/main/rooms/${room.id}');
  }

  void _openSettingsRoute(String path) {
    Navigator.of(context).pop();
    context.go(path);
  }

  void _runMessage(MessageSearchResult msg) {
    Navigator.of(context).pop();
    RecentActivity.instance.recordRoom(msg.room.id);
    context.go('/main/rooms/${msg.room.id}');
  }

  void _runUser(Profile user) {
    Navigator.of(context).pop();
    context.push('/main/myprofile?user=${user.userId}');
  }

  void _runHomeserverRoom(PublishedRoomsChunk room) {
    final alias = room.canonicalAlias ?? room.roomId;
    Navigator.of(context).pop();
    context.go('/main/rooms/$alias');
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _locCache = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInput(_locCache),
                    const SizedBox(height: 8),
                    _buildModeHint(_locCache),
                    const SizedBox(height: 8),
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
      _PaletteMode.commands => loc.commandPaletteHint,
      _PaletteMode.search => loc.commandPaletteModeSearch,
      _PaletteMode.settings => loc.commandPaletteModeSettings,
      _PaletteMode.rooms => loc.commandPaletteModeRooms,
      _PaletteMode.users => loc.commandPaletteModeUsers,
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

  IconData _modeIcon(_PaletteMode mode) => switch (mode) {
        _PaletteMode.commands => LucideIcons.command,
        _PaletteMode.search => LucideIcons.search,
        _PaletteMode.settings => LucideIcons.settings,
        _PaletteMode.rooms => LucideIcons.hash,
        _PaletteMode.users => LucideIcons.atSign,
      };

  String _hintForMode(AppLocalizations loc, _PaletteMode mode) =>
      switch (mode) {
        _PaletteMode.commands => loc.commandPaletteHint,
        _PaletteMode.search => loc.commandPaletteSearchHint,
        _PaletteMode.settings => loc.commandPaletteSettingsHint,
        _PaletteMode.rooms => loc.commandPaletteRoomsHint,
        _PaletteMode.users => loc.commandPaletteUsersHint,
      };

  // ── Mode-specific list builders ───────────────────────────────────

  Widget _buildList(AppLocalizations loc) {
    switch (_mode) {
      case _PaletteMode.commands:
        return _buildCommandsList(loc);
      case _PaletteMode.settings:
        return _buildSettingsList(loc);
      case _PaletteMode.rooms:
        return _buildRoomsList(loc);
      case _PaletteMode.users:
        return _buildUsersList(loc);
      case _PaletteMode.search:
        return _buildSearchList(loc);
    }
  }

  Widget _buildCommandsList(AppLocalizations loc) {
    final actions = _buildActions(loc);
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
    final entries = _buildSettingsEntries(loc);
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
    final paginating = _isPaginating || _isInitialSearch || _isInitialUsers;
    final hasMore = _mode == _PaletteMode.search
        ? (_hasMoreMessages ||
            _hasMoreHomeserver ||
            _hasMoreRooms ||
            _hasMoreSpaces)
        : _mode == _PaletteMode.rooms
            ? (_hasMoreRooms || _hasMoreSpaces)
            : _hasMoreUsers;
    if (paginating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
    return const SizedBox(height: 4);
  }

  // ── Recents section helpers ────────────────────────────────────────

  List<Widget> _buildRecentSection(AppLocalizations loc) {
    final actions = _buildActions(loc);
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
  List<_PaletteResult> _currentResults(AppLocalizations loc) {
    switch (_mode) {
      case _PaletteMode.commands:
        final actions = _buildActions(loc);
        final q = _query.toLowerCase();
        return [
          for (final a in actions)
            if (a.label.toLowerCase().contains(q) ||
                a.key.toLowerCase().contains(q))
              _PaletteResult(() => _runAction(a)),
        ];
      case _PaletteMode.settings:
        return [
          for (final e in _buildSettingsEntries(loc))
            if (e.label.toLowerCase().contains(_query.toLowerCase()) ||
                e.description.toLowerCase().contains(_query.toLowerCase()))
              _PaletteResult(() => _openSettingsRoute(e.path)),
        ];
      case _PaletteMode.rooms:
        return [
          for (final r in [..._matchedRooms, ..._matchedSpaces])
            _PaletteResult(() => _runRoom(r)),
        ];
      case _PaletteMode.users:
        return [
          for (final u in _userResults) _PaletteResult(() => _runUser(u)),
        ];
      case _PaletteMode.search:
        return [
          for (final r in [..._matchedRooms, ..._matchedSpaces])
            _PaletteResult(() => _runRoom(r)),
          for (final m in _msgResults) _PaletteResult(() => _runMessage(m)),
          for (final u in _userResults) _PaletteResult(() => _runUser(u)),
          for (final h in _homeserverResults)
            _PaletteResult(() => _runHomeserverRoom(h)),
        ];
    }
  }

  // ── Static data ───────────────────────────────────────────────────

  List<CommandAction> _buildActions(AppLocalizations loc) {
    final settings = _settingsControllerOrNull(context);
    return [
      CommandAction(
        key: 'open_settings',
        label: loc.commandPaletteOpenSettings,
        icon: LucideIcons.settings,
        callback: (ctx) => ctx.go('/hub/settings'),
      ),
      CommandAction(
        key: 'open_accounts',
        label: loc.commandPaletteOpenAccounts,
        icon: LucideIcons.userRound,
        callback: (ctx) => ctx.go('/hub/accounts'),
      ),
      CommandAction(
        key: 'open_logs',
        label: loc.commandPaletteOpenLogs,
        icon: LucideIcons.scrollText,
        callback: (ctx) => ctx.go('/hub/settings/logs'),
      ),
      CommandAction(
        key: 'open_profile',
        label: loc.commandPaletteOpenProfile,
        icon: LucideIcons.userCircle,
        callback: (ctx) => ctx.go('/hub/profile'),
      ),
      CommandAction(
        key: 'open_about',
        label: loc.commandPaletteOpenAbout,
        icon: LucideIcons.info,
        callback: (ctx) => ctx.go('/hub/about'),
      ),
      CommandAction(
        key: 'open_security',
        label: loc.commandPaletteOpenSecurity,
        icon: LucideIcons.shield,
        callback: (ctx) => ctx.go('/hub/settings/security'),
      ),
      CommandAction(
        key: 'toggle_left_sidebar',
        label: loc.commandPaletteToggleSidebar,
        icon: LucideIcons.panelLeft,
        callback: (ctx) {
          if (settings != null) {
            settings.setLeftSidebarVisible(!settings.leftSidebarVisible);
          }
        },
      ),
      CommandAction(
        key: 'toggle_right_sidebar',
        label: loc.commandPaletteToggleRightSidebar,
        icon: LucideIcons.panelRight,
        callback: (ctx) {
          if (settings != null) {
            settings.setRightSidebarVisible(!settings.rightSidebarVisible);
          }
        },
      ),
      CommandAction(
        key: 'add_room',
        label: loc.commandPaletteAddRoom,
        icon: LucideIcons.plusCircle,
        callback: (ctx) => ctx.push('/main/addroom'),
      ),
    ];
  }

  List<_SettingsEntry> _buildSettingsEntries(AppLocalizations loc) => [
        _SettingsEntry(
          label: loc.appearance,
          description: loc.commandPaletteAppearanceDesc,
          icon: LucideIcons.palette,
          path: '/hub/settings/appearance',
        ),
        _SettingsEntry(
          label: loc.layout,
          description: loc.commandPaletteLayoutDesc,
          icon: LucideIcons.layoutDashboard,
          path: '/hub/settings/layout',
        ),
        _SettingsEntry(
          label: loc.encryptionAndSecurity,
          description: loc.commandPaletteSecurityDesc,
          icon: LucideIcons.shield,
          path: '/hub/settings/security',
        ),
        _SettingsEntry(
          label: loc.chatSettings,
          description: loc.commandPaletteChatDesc,
          icon: LucideIcons.messageSquare,
          path: '/hub/settings/chat',
        ),
        _SettingsEntry(
          label: loc.network,
          description: loc.commandPaletteNetworkDesc,
          icon: LucideIcons.activity,
          path: '/hub/settings/network',
        ),
        _SettingsEntry(
          label: loc.backgroundAndTray,
          description: loc.commandPaletteBackgroundDesc,
          icon: LucideIcons.minimize2,
          path: '/hub/settings/background',
        ),
        _SettingsEntry(
          label: loc.notifications,
          description: loc.commandPaletteNotificationsDesc,
          icon: LucideIcons.bell,
          path: '/hub/settings/notifications',
        ),
        _SettingsEntry(
          label: loc.blockedUsers,
          description: loc.commandPaletteBlockedDesc,
          icon: LucideIcons.ban,
          path: '/hub/settings/blocked',
        ),
        _SettingsEntry(
          label: loc.logs,
          description: loc.commandPaletteLogsDesc,
          icon: LucideIcons.fileText,
          path: '/hub/settings/logs',
        ),
      ];
}

class _PaletteResult {
  _PaletteResult(this.run);
  final VoidCallback run;
}

class _SettingsEntry {
  _SettingsEntry({
    required this.label,
    required this.description,
    required this.icon,
    required this.path,
  });
  final String label;
  final String description;
  final IconData icon;
  final String path;
}

SettingsController? _settingsControllerOrNull(BuildContext context) {
  try {
    return context.read<SettingsController>();
  } catch (_) {
    return null;
  }
}

class CommandAction {
  const CommandAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.callback,
  });
  final String key;
  final String label;
  final IconData icon;
  final void Function(BuildContext) callback;
}
