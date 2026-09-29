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
import 'package:moonrelay/src/chat/in_room_search_panel/search_result_tile.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// A panel for searching messages inside a single room.
///
/// Supports:
/// - Keyword search with AND logic (space-separated, quoted phrases supported)
/// - Filter by message type (All, Text, Image, File, Audio, Video)
/// - Filter by sender
/// - Paginated history search via [Room.searchEvents]
///
/// Keywords are matched against the event body, filename (for media), and
/// content description.  Quoted phrases like `"hello world"` are treated as
/// a single token.
///
/// Designed to be shown as a slide-in panel within the room page.
class InRoomSearchPanel extends StatefulWidget {
  final Room room;
  final VoidCallback onClose;

  /// Called when the user taps a search result so the parent can scroll
  /// the timeline to that event.  No-op if null.
  final void Function(String eventId)? onJumpToEvent;

  const InRoomSearchPanel({
    super.key,
    required this.room,
    required this.onClose,
    this.onJumpToEvent,
  });

  @override
  State<InRoomSearchPanel> createState() => _InRoomSearchPanelState();
}

class _InRoomSearchPanelState extends State<InRoomSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  // Search state
  List<String> _keywords = []; // parsed tokens, all must match (AND)
  String _senderFilter = '';
  String _selectedType = ''; // empty = all

  List<Event> _results = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _nextBatch;

  /// Bumped on every new (reset) search.  Responses carry the token of
  /// their originating request so stale results are dropped.
  int _searchToken = 0;

  // Message type filter options
  static const List<InRoomResultFilter> inRoomResultFilters = [
    InRoomResultFilter('', LucideIcons.fileText), // All
    InRoomResultFilter(MessageTypes.Text, LucideIcons.type),
    InRoomResultFilter(MessageTypes.Image, LucideIcons.image),
    InRoomResultFilter(MessageTypes.File, LucideIcons.file),
    InRoomResultFilter(MessageTypes.Audio, LucideIcons.headphones),
    InRoomResultFilter(MessageTypes.Video, LucideIcons.video),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _senderController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _senderController.removeListener(_onSearchChanged);
    _senderController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Splits raw input into tokens respecting double-quoted phrases.
  ///
  /// `'foo "bar baz" qux'` -> `['foo', 'bar baz', 'qux']`
  List<String> _parseKeywords(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return [];

    final tokens = <String>[];
    var i = 0;
    while (i < trimmed.length) {
      if (trimmed[i] == ' ') {
        i++;
        continue;
      }
      if (trimmed[i] == '"') {
        // Quoted phrase.
        final end = trimmed.indexOf('"', i + 1);
        if (end == -1) {
          tokens.add(trimmed.substring(i + 1));
          break;
        }
        tokens.add(trimmed.substring(i + 1, end));
        i = end + 1;
      } else {
        // Regular word.
        final end = trimmed.indexOf(' ', i);
        if (end == -1) {
          tokens.add(trimmed.substring(i));
          break;
        }
        tokens.add(trimmed.substring(i, end));
        i = end + 1;
      }
    }
    return tokens;
  }

  void _onSearchChanged() {
    final raw = _searchController.text;
    final sender = _senderController.text.trim().toLowerCase();
    final keywords = _parseKeywords(raw);

    final queryChanged = keywords.length != _keywords.length ||
        !keywords.every((k) => _keywords.contains(k));
    final senderChanged = sender != _senderFilter;

    if (!queryChanged && !senderChanged) return;

    _debounce?.cancel();
    _debounce = Timer(
      Duration(
        milliseconds: context.read<SettingsController>().searchDebounceMs,
      ),
      () {
        _keywords = keywords;
        _senderFilter = sender;
        _performSearch();
      },
    );
  }

  void _onTypeChanged(String type) {
    setState(() => _selectedType = type);
    _performSearch();
  }

  void _performSearch() {
    if (_keywords.isEmpty && _senderFilter.isEmpty && _selectedType.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    // No point hitting the server if we only have type/sender filters
    // searchEvents needs a searchTerm to paginate.  We can still match
    // locally against the server-streamed results when a keyword is present.
    if (_keywords.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchServerHistory(reset: true);
  }

  /// Checks whether [event] satisfies ALL active filters.
  ///
  /// Keyword matching uses AND logic: every parsed token must appear
  /// somewhere in the event body, filename (if media), or a plain-text
  /// fallback.  Quoted phrases must appear verbatim.
  bool _matchesFilter(Event event) {
    // Only search message events
    if (event.type != EventTypes.Message && event.type != EventTypes.Sticker) {
      return false;
    }

    // Message type filter
    if (_selectedType.isNotEmpty) {
      final msgType = event.messageType;
      if (msgType != _selectedType) return false;
    }

    // Sender filter
    if (_senderFilter.isNotEmpty) {
      final sender = event.senderFromMemoryOrFallback;
      final displayName = sender.displayName?.toLowerCase() ?? '';
      final userId = sender.id.toLowerCase();
      if (!displayName.contains(_senderFilter) &&
          !userId.contains(_senderFilter)) {
        return false;
      }
    }

    // Keyword search: AND across all tokens.
    if (_keywords.isNotEmpty) {
      final haystack = _eventSearchText(event);
      if (!_keywords.every((kw) => haystack.contains(kw))) return false;
    }

    return true;
  }

  /// Builds a single lower-case searchable string from [event] covering
  /// the body, filename (if any), and a content fallback.
  String _eventSearchText(Event event) {
    final buf = StringBuffer(event.body.toLowerCase());

    // Try to extract a filename from content (images, files, audio, video).
    final filename = event.content.tryGet<String>('filename') ?? '';
    if (filename.isNotEmpty) {
      buf.write(' ');
      buf.write(filename.toLowerCase());
    }

    // Also try the "name" key (used by some audio events, stickers, etc.).
    final name = event.content.tryGet<String>('name') ?? '';
    if (name.isNotEmpty) {
      buf.write(' ');
      buf.write(name.toLowerCase());
    }

    return buf.toString();
  }

  Future<void> _searchServerHistory({bool reset = false}) async {
    if (_keywords.isEmpty) return;
    if (_isLoadingMore) return;

    // Stamp this request with the current query generation.  A stale
    // in-flight response (from an older keyword) must never overwrite
    // results for a newer one, so it is discarded on arrival.
    final int token = ++_searchToken;
    if (reset) _nextBatch = null;

    setState(() => _isLoadingMore = true);

    try {
      // Room.searchEvents uses a single searchTerm for downloading history
      // and applies searchFunc for the actual matching.  We pass the first
      // keyword as the server-side hint and rely on _matchesFilter for the
      // full multi-keyword + type + sender filtering.
      final result = await widget.room.searchEvents(
        searchTerm: _keywords.first,
        nextBatch: reset ? null : _nextBatch,
        limit: context.read<SettingsController>().searchPageSize,
      );

      if (!mounted || token != _searchToken) return;

      final matches = result.events.where(_matchesFilter).toList();

      setState(() {
        if (reset) {
          _results = matches;
        } else {
          _results.addAll(matches);
        }
        _nextBatch = result.nextBatch;
        _isSearching = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _isSearching = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_nextBatch != null && !_isLoadingMore) {
      _searchServerHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;

    // Adapt to layout size: on compact screens the panel becomes a
    // full-width drawer instead of a fixed 320px column.
    final layoutSize = LayoutScope.of(context).size;
    final isCompact = layoutSize.isCompact;

    final width = isCompact
        ? MediaQuery.sizeOf(context).width * 0.92
        : LayoutBreakpoints.searchPanelWidth;
    final maxWidth = isCompact ? 420.0 : LayoutBreakpoints.searchPanelWidth;

    return Container(
      width: width.clamp(220.0, maxWidth),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: isCompact
            ? null
            : Border(
                left: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
      ),
      child: Column(
        children: [
          // -- Header ----------------------------------------------
          _buildHeader(scheme, l10n, t),

          // -- Keyword chips ---------------------------------------
          if (_keywords.isNotEmpty) _buildKeywordChips(scheme, t),

          // -- Type filter chips -----------------------------------
          _buildTypeFilters(scheme, l10n, t),

          // -- Sender filter ---------------------------------------
          _buildSenderFilter(scheme, l10n, t),

          // -- Results ---------------------------------------------
          Expanded(child: _buildResults(scheme, l10n, t)),

          // -- Load more -------------------------------------------
          if (_nextBatch != null) _buildLoadMore(scheme, l10n, t),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ColorScheme scheme,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          t.spaceMd, t.spaceSm, t.spaceXs, t.spaceXs),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.search,
                  size: 18, color: scheme.onSurfaceVariant),
              SizedBox(width: t.spaceSm),
              Text(
                l10n.inRoomSearch,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: widget.onClose,
                tooltip: l10n.close,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: t.spaceXs),
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: l10n.inRoomSearchHint,
              prefixIcon: Icon(LucideIcons.search, size: t.iconSizeSmall),
              suffixIcon: _keywords.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => _searchController.clear(),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spaceMd,
                vertical: t.spaceSm,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _debounce?.cancel();
              _keywords = _parseKeywords(_searchController.text);
              _performSearch();
            },
          ),
        ],
      ),
    );
  }

  /// Shows the individual parsed keywords as chips so the user can see
  /// how their query was split (AND logic, quoted phrases stay together).
  Widget _buildKeywordChips(ColorScheme scheme, MoonrelayDesignTokens t) {
    return Padding(
      padding: EdgeInsets.fromLTRB(t.spaceMd, 6, t.spaceMd, t.spaceXxs),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: _keywords.map((kw) {
          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: t.spaceSm, vertical: t.spaceXxs),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(t.radiusMd),
            ),
            child: Text(
              kw,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onPrimaryContainer,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypeFilters(
    ColorScheme scheme,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
  ) {
    final labels = [
      l10n.inRoomSearchAll,
      l10n.inRoomSearchText,
      l10n.inRoomSearchImages,
      l10n.inRoomSearchFiles,
      l10n.inRoomSearchAudio,
      l10n.inRoomSearchVideo,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          t.spaceMd, t.spaceSm, t.spaceMd, t.spaceXs),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: List.generate(inRoomResultFilters.length, (i) {
          final filter = inRoomResultFilters[i];
          final isSelected = _selectedType == filter.type;
          return FilterChip(
            label: Text(
              labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            selected: isSelected,
            avatar: Icon(filter.icon, size: 14),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => _onTypeChanged(filter.type),
            selectedColor: scheme.primaryContainer,
            checkmarkColor: scheme.onPrimaryContainer,
          );
        }),
      ),
    );
  }

  Widget _buildSenderFilter(
    ColorScheme scheme,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          t.spaceMd, t.spaceXs, t.spaceMd, t.spaceSm),
      child: TextField(
        controller: _senderController,
        decoration: InputDecoration(
          hintText: l10n.inRoomSearchByUser,
          prefixIcon: Icon(LucideIcons.user, size: t.iconSizeSmall),
          suffixIcon: _senderFilter.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 14),
                  onPressed: () => _senderController.clear(),
                  visualDensity: VisualDensity.compact,
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.radiusMd),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spaceMd,
            vertical: t.spaceSm,
          ),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildResults(
    ColorScheme scheme,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
  ) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacityDisabled),
            ),
            SizedBox(height: t.spaceSm),
            Text(
              _keywords.isEmpty && _senderFilter.isEmpty
                  ? l10n.inRoomSearchHint
                  : l10n.inRoomSearchNoResults,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: t.spaceMd, vertical: t.spaceXs),
          child: Text(
            l10n.inRoomSearchResults(_results.length),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
            itemCount: _results.length,
            separatorBuilder: (_, __) => Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              return InRoomResultTile(
                event: _results[index],
                keywords: _keywords,
                onJumpToEvent: widget.onJumpToEvent,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMore(
    ColorScheme scheme,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
  ) {
    return Container(
      padding: EdgeInsets.all(t.spaceSm),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoadingMore ? null : _loadMore,
          icon: _isLoadingMore
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(LucideIcons.chevronDown, size: t.iconSizeSmall),
          label: Text(
            _isLoadingMore ? l10n.searching : l10n.loadMore,
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    );
  }
}

// --- Internal models ----------------------------------------------------------

// --- Result tile --------------------------------------------------------------
