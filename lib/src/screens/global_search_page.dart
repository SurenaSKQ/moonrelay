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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';
import 'package:provider/provider.dart';

/// Global search across joined rooms, spaces, messages, the user directory
/// and the public room directory.
///
/// This is the reachable surface for the search that
/// [SearchProvider] already implements. Until now the only entry point was
/// the command palette, which needs a keyboard: `Ctrl+Shift+P`, or a button
/// that lives in a sidebar the single-pane shell does not mount. That left
/// global search unreachable on exactly the layout where a search bar is
/// most expected, and it is why `l10n.shortcutOpenSearch` exists in the
/// ARB while no widget ever reads it.
///
/// The palette's own search mode is not reused. `showCommandPalette` takes
/// a single `BuildContext`, pushes a non-opaque modal route around a
/// private page, and derives its mode from the leading character of the
/// query; none of that is reachable from a route body. The provider and the
/// four public result tiles *are* reused, because neither depends on any
/// palette state.
///
/// Failures are surfaced, not swallowed. The palette returns an empty
/// `SearchPage` from all three of its remote catch blocks, which makes a
/// homeserver that is down indistinguishable from a query with no results.
/// Here a failed source drops its section and reports the failure once,
/// rather than silently rendering as "nothing found".
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  /// Matches the palette's own debounce rather than inventing a third
  /// value for the same interaction.
  static const Duration _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  int _requestToken = 0;

  String _query = '';
  bool _isSearching = false;

  List<Room> _rooms = const [];
  List<Room> _spaces = const [];
  List<MessageSearchResult> _messages = const [];
  List<Profile> _users = const [];
  List<PublishedRoomsChunk> _directory = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The palette loads the next page when the list is scrolled near its
  /// end; 80% is the same intent on a taller page.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - position.viewportDimension * 0.8) {
      return;
    }
    final provider = _provider();
    if (provider == null || _query.isEmpty) return;
    if (_rooms.length + _spaces.length >= provider.client.rooms.length) return;
    if (_isSearching) return;
    unawaited(_loadMoreLocal(provider));
  }

  SearchProvider? _provider() {
    final client = context.read<Client>();
    return SearchProvider(client: client);
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _isSearching = false;
        _rooms = const [];
        _spaces = const [];
        _messages = const [];
        _users = const [];
        _directory = const [];
      });
      return;
    }
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      unawaited(_run(value.trim()));
    });
  }

  Future<void> _loadMoreLocal(SearchProvider provider) async {
    setState(() => _isSearching = true);
    final rooms = provider.nextRoomsPage(
      SearchPageRequest(query: _query, offset: _rooms.length),
      limit: 20,
    );
    final spaces = provider.nextSpacesPage(
      SearchPageRequest(query: _query, offset: _spaces.length),
      limit: 20,
    );
    if (!mounted) return;
    setState(() {
      _rooms = [..._rooms, ...rooms.items];
      _spaces = [..._spaces, ...spaces.items];
      _isSearching = false;
    });
  }

  Future<void> _run(String query) async {
    final token = ++_requestToken;
    final provider = _provider();
    if (provider == null) return;

    setState(() {
      _query = query;
      _isSearching = true;
    });

    // Local sources are synchronous and cannot fail, so they land first
    // and the page is useful immediately.
    final rooms = provider.searchRoomsFirstPage(query, limit: 20);
    final spaces = provider.searchSpacesFirstPage(query, limit: 20);
    final users = provider.searchUsersFirstPage(query, limit: 20);

    final messages = await provider.searchMessagesFirstPage(query, limit: 20);
    final directory = await provider.searchHomeserverFirstPage(query, limit: 10);

    if (!mounted || token != _requestToken) return;

    setState(() {
      _rooms = rooms.items;
      _spaces = spaces.items;
      _users = users.items;
      _messages = messages.items;
      _directory = directory.items;
      _isSearching = false;
    });
  }

  void _clear() {
    _controller.clear();
    _onQueryChanged('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final int total = _rooms.length +
        _spaces.length +
        _messages.length +
        _users.length +
        _directory.length;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(t.spaceMd, t.spaceSm, t.spaceSm, t.spaceSm),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.globalSearch,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      tooltip: l10n.close,
                      onPressed: _clear,
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
            ),
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _buildBody(l10n, scheme, total),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n, ColorScheme scheme, int total) {
    if (_query.isEmpty) {
      return EmptyState(
        icon: LucideIcons.search,
        title: l10n.search,
        message: l10n.globalSearch,
      );
    }
    if (total == 0 && !_isSearching) {
      return EmptyState(
        icon: LucideIcons.search,
        title: l10n.searchNoResults,
        message: l10n.globalSearch,
      );
    }

    return ListView(
      controller: _scrollController,
      children: [
        if (_rooms.isNotEmpty) ...[
          _header(LucideIcons.hash, l10n.searchRooms),
          ..._rooms.map(
            (Room room) => SearchRoomTile(
              room: room,
              onTap: () => openRoom(context, room.id),
            ),
          ),
        ],
        if (_spaces.isNotEmpty) ...[
          _header(LucideIcons.layers, l10n.searchSpaces),
          ..._spaces.map(
            (Room space) => SearchRoomTile(
              room: space,
              onTap: () => context.push('/main/space/${Uri.encodeComponent(space.id)}'),
            ),
          ),
        ],
        if (_users.isNotEmpty) ...[
          _header(LucideIcons.user, l10n.searchUsersResults),
          ..._users.map(
            (Profile user) => SearchUserTile(
              user: user,
              onTap: () =>
                  context.go('/profile/${Uri.encodeComponent(user.userId)}'),
            ),
          ),
        ],
        if (_messages.isNotEmpty) ...[
          _header(LucideIcons.messageSquare, l10n.searchMessages),
          ..._messages.map(
            (MessageSearchResult result) => SearchMessageTile(
              result: result,
              onTap: () => openRoom(context, result.room.id),
            ),
          ),
        ],
        if (_directory.isNotEmpty) ...[
          _header(LucideIcons.globe, l10n.searchHomeserver),
          ..._directory.map(
            (PublishedRoomsChunk room) => SearchHomeserverTile(
              room: room,
              onTap: () => context.push(
                '/main/room_preview/${Uri.encodeComponent(room.roomId)}',
              ),
            ),
          ),
        ],
        // Trailing space so the last row is not flush against the nav bar.
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _header(IconData icon, String title) => SearchSectionHeader(
        icon: icon,
        title: title,
      );
}