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

// Full-text search within one room.
//
// This replaces `InRoomSearchPanel`, which is where most of the work is. That
// panel was not slow or ugly so much as wrong, in four ways that compounded.
//
// **It was not searching.** It called `Room.searchEvents`, which is a
// `/messages` backwards pager with a *client-side substring* filter. That has
// three consequences the old UI hid:
//
//   - Page one was a full local SQLite table scan in `limit`-sized chunks until
//     it hit `m.room.create`. A twenty-thousand-event room at the default 100 is
//     two hundred sequential database queries for one keystroke.
//   - The SDK's own predicate matches `event.body`, and for any non-text event
//     `Event.body` returns the literal string
//     `'Unknown message format of type "..."'`. So the Image, File, Audio and
//     Video filter chips could essentially never match anything. Four of six
//     filters were dead.
//   - Multi-keyword AND was applied on top of a stream pre-filtered by
//     `keywords.first`, so a message containing "bar baz" but not "bar" was
//     unfindable.
//
// This uses `client.search` with a `SearchFilter` scoped to this room, which is
// the actual full-text endpoint. It ranks server-side, it paginates honestly,
// and it can filter by sender and type without the server handing back a
// thousand rows that are then discarded locally.
//
// **The query guard was below the mutex.** The old `_searchServerHistory` tested
// `_isLoadingMore` and returned *before* bumping its staleness token, so a query
// typed while a page was in flight was silently dropped: no request went out, the
// in-flight page landed and was appended to the old results, and its matches
// were then filtered by the *new* keyword list. The panel was then permanently
// wrong, because the input listener compared keyword sets and refused to re-arm.
// There was no way back short of retyping the whole query. Here the token is
// bumped by [RoomSearchController.query], which every input path goes through,
// and paging has its own flag and never touches it.
//
// **End-of-results was inferred from a nullable cursor.** `nextBatch == ''` was
// never checked, so a homeserver that echoed the token back, which is permitted
// and common, left the "load more" button on screen forever with nothing behind
// it. Now `hasMore` is explicit, an empty page ends the list, and results are
// deduplicated by event id.
//
// **Failure and emptiness were the same pixels.** One bare `catch (_)` with no
// comment and no log left the results untouched, so a 500 rendered "no messages
// match your search". [RoomSearchController] has a failure state like the
// command palette's, and the tab renders it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/widgets/highlighted_text.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';
import 'package:provider/provider.dart';

/// How long a search request gets before it is treated as failed.
const Duration kRoomSearchTimeout = Duration(seconds: 10);

/// The state of an in-room search.
enum RoomSearchPhase {
  /// Nothing typed.
  idle,

  /// A request is in flight and there is nothing to show yet.
  searching,

  /// At least one result.
  results,

  /// The query ran and matched nothing.
  empty,

  /// The request failed. Distinct from [empty] on purpose: one is an answer and
  /// the other is the absence of one.
  failed,
}

/// Owns one in-room search: the query, the filters, the pages and the cursor.
///
/// A `ChangeNotifier` rather than widget state, because the tab's header, its
/// filter chips, its results and its footer all read different parts of it and
/// none of them should rebuild the others.
class RoomSearchController extends ChangeNotifier {
  RoomSearchController({
    required Room room,
    required Logger log,
    required this.l10n,
    this.debounce = const Duration(milliseconds: 300),
    this.pageSize = 100,
  })  : _room = room,
        _log = log,
        _provider = SearchProvider(client: room.client);

  final Room _room;
  final Logger _log;
  final SearchProvider _provider;
  final AppLocalizations l10n;

  /// How long typing has to settle before a request goes out.
  ///
  /// Settable, and set from the user's preference by the tab rather than read
  /// from a provider inside this constructor. A `ChangeNotifier` reading
  /// `context` in its own construction is a thing that works until the widget
  /// is built somewhere without that provider.
  Duration debounce;

  /// How many results a page asks for.
  int pageSize;

  Timer? _debounceTimer;
  final TextEditingController _queryField = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Bumped by [query] only. Paging must not touch it: paging asks the same
  /// question again, and invalidating here would drop the user's scroll
  /// position on every page.
  int _token = 0;

  bool _busy = false;
  bool _paging = false;
  bool _searching = false;
  bool _failed = false;

  List<String> _keywords = <String>[];
  String _sender = '';
  String _msgType = '';

  List<MessageSearchResult> _results = <MessageSearchResult>[];
  final Set<String> _seenEventIds = <String>{};
  String? _nextBatch;
  bool _hasMore = false;

  int _requestCount = 0;

  /// The room's field, exposed so the tab can bind its listener without owning
  /// the controller.
  TextEditingController get queryField => _queryField;

  ScrollController get scroll => _scroll;

  List<MessageSearchResult> get results => _results;
  List<String> get keywords => _keywords;
  String get senderFilter => _sender;
  String get msgType => _msgType;
  bool get busy => _busy;
  bool get hasMore => _hasMore && !_busy && !_paging;

  /// How many requests have actually been issued, for tests.
  ///
  /// Exposed because the bug this class exists to fix was a request that was
  /// silently *not* made. Counting the attempts is the only way a test can see
  /// that.
  int get requestCount => _requestCount;

  RoomSearchPhase get phase {
    if (_results.isNotEmpty) return RoomSearchPhase.results;
    if (_failed) return RoomSearchPhase.failed;
    if (_busy || _searching) return RoomSearchPhase.searching;
    if (_keywords.isNotEmpty || _sender.isNotEmpty || _msgType.isNotEmpty) {
      return RoomSearchPhase.empty;
    }
    return RoomSearchPhase.idle;
  }

  /// Runs [query] after the debounce.
  ///
  /// Every input path funnels through here: typing, submitting, changing a
  /// filter chip. There is nowhere else to bump the token, which is the property
  /// the old panel lacked.
  void query(String raw, {String? sender, String? msgType}) {
    final List<String> parsed = parseKeywords(raw);
    final String nextSender = (sender ?? _sender).trim().toLowerCase();
    final String nextType = msgType ?? _msgType;

    if (_sameQuery(parsed, nextSender, nextType)) return;

    _keywords = parsed;
    _sender = nextSender;
    _msgType = nextType;
    // Bumped before anything can refuse to run, which is the whole point. The
    // old panel checked its in-flight flag first and returned without bumping,
    // so a new query during a load was thrown away.
    final int token = ++_token;

    _reset(token);
    notifyListeners();

    _debounceTimer?.cancel();
    if (_keywords.isEmpty && _sender.isEmpty && _msgType.isEmpty) {
      // Nothing to ask for. Refusing here rather than sending an empty search
      // is deliberate: an empty search term returns the whole room.
      //
      // The type filter counts as something to ask for, and that is the point
      // of moving off the old pager. That API needed a search term in order to
      // paginate, so "every image in this room" was inexpressible and its type
      // chips were only ever narrowers on a keyword query. The full-text
      // endpoint filters without a term.
      return;
    }
    _debounceTimer = Timer(debounce, () => _run(token));
  }

  bool _sameQuery(List<String> parsed, String sender, String msgType) {
    if (parsed.length != _keywords.length) return false;
    for (int i = 0; i < parsed.length; i++) {
      if (parsed[i] != _keywords[i]) return false;
    }
    return sender == _sender && msgType == _msgType;
  }

  void _reset(int token) {
    _results = <MessageSearchResult>[];
    _seenEventIds.clear();
    _nextBatch = null;
    _hasMore = false;
    _busy = false;
    _paging = false;
    _searching = false;
    _failed = false;
    if (token != _token) return;
  }

  Future<void> _run(int token) async {
    _searching = true;
    _busy = true;
    _requestCount++;
    notifyListeners();
    try {
      final SearchPage<MessageSearchResult> page = await withTimeout(
        () => _provider.searchRoomMessages(
          roomId: _room.id,
          keywords: _keywords,
          sender: _sender,
          msgType: _msgType,
          limit: pageSize,
        ),
        timeout: kRoomSearchTimeout,
      );
      if (token != _token) return;
      _absorb(page, reset: true);
      _searching = false;
      _busy = false;
      notifyListeners();
    } catch (error) {
      if (token != _token) return;
      _searching = false;
      _busy = false;
      _failed = true;
      // Logged, and rendered. The old catch did neither, so a homeserver error
      // and an empty result set were the same pixels.
      _log.w('In-room search failed', error: error);
      notifyListeners();
    }
  }

  /// Appends the next page.
  ///
  /// A separate flag from [_busy] and no token bump, so scrolling to the end
  /// cannot cancel the query that is running and cannot drop the cursor.
  Future<void> loadMore() async {
    if (!_hasMore || _paging || _busy) return;
    _paging = true;
    notifyListeners();
    final int token = _token;
    try {
      final SearchPage<MessageSearchResult> page = await withTimeout(
        () => _provider.searchRoomMessages(
          roomId: _room.id,
          keywords: _keywords,
          sender: _sender,
          msgType: _msgType,
          limit: pageSize,
          nextBatch: _nextBatch,
        ),
        timeout: kRoomSearchTimeout,
      );
      if (token != _token) return;
      _absorb(page, reset: false);
      _paging = false;
      notifyListeners();
    } catch (error) {
      if (token != _token) return;
      // A failed page is not a failed search. The rows already on screen stay,
      // paging stops, and the reason is logged. Throwing away real results to
      // report "could not load more" would be strictly worse.
      _hasMore = false;
      _paging = false;
      _log.w('In-room search could not load more', error: error);
      notifyListeners();
    }
  }

  void _absorb(SearchPage<MessageSearchResult> page, {required bool reset}) {
    if (reset) {
      _results = <MessageSearchResult>[];
      _seenEventIds.clear();
    }
    for (final MessageSearchResult hit in page.items) {
      // Deduplicated by event id. The old panel had no `seen` set, so a server
      // that returned an overlapping page produced duplicate rows with no way
      // to tell.
      if (_seenEventIds.add(hit.event.eventId)) _results.add(hit);
    }
    _nextBatch = page.nextBatch;
    // Explicit rather than a nullable cursor. `nextBatch == ''` is a legal and
    // common end-of-results signal, and the old panel only tested for null, so
    // the load-more button could stay on screen forever.
    _hasMore = page.hasMore && page.items.isNotEmpty;
    _failed = false;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryField.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Splits raw input into tokens, respecting double-quoted phrases.
  ///
  /// `'foo "bar baz" qux'` becomes `['foo', 'bar baz', 'qux']`.
  ///
  /// Empty tokens are dropped. The old parser did not, so a stray `"` while
  /// composing a phrase produced `['']`, which is not empty, so the guard
  /// "are there keywords" passed, so the search ran with an empty term, which
  /// matches *every message in the room*. Typing a quote silently turned the
  /// query into "show me everything".
  static List<String> parseKeywords(String raw) {
    final String trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return <String>[];

    final List<String> tokens = <String>[];
    int i = 0;
    while (i < trimmed.length) {
      if (trimmed[i] == ' ') {
        i++;
        continue;
      }
      if (trimmed[i] == '"') {
        final int end = trimmed.indexOf('"', i + 1);
        // An unbalanced quote takes the rest of the input as one phrase, which
        // is what the user was in the middle of typing. It does not error,
        // because half a query is not an error, it is a query in progress.
        final String phrase = end == -1
            ? trimmed.substring(i + 1)
            : trimmed.substring(i + 1, end);
        if (phrase.trim().isNotEmpty) tokens.add(phrase.trim());
        if (end == -1) break;
        i = end + 1;
      } else {
        final int end = trimmed.indexOf(' ', i);
        final String word =
            end == -1 ? trimmed.substring(i) : trimmed.substring(i, end);
        if (word.isNotEmpty) tokens.add(word);
        if (end == -1) break;
        i = end + 1;
      }
    }
    return tokens;
  }
}

/// The search tab of the room's side pane.
class SearchTab extends StatefulWidget {
  const SearchTab({
    super.key,
    required this.room,
    this.onJumpToEvent,
  });

  final Room room;

  /// Brings an event into view in the timeline.
  final void Function(String eventId)? onJumpToEvent;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late RoomSearchController _controller;
  final FocusNode _focus = FocusNode();
  final TextEditingController _senderField = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = RoomSearchController(
      room: widget.room,
      log: context.read<Logger>(),
      l10n: AppLocalizations.of(context)!,
    );
    // The user's own debounce preference, read now rather than in the
    // controller's constructor, where there is no context.
    _controller.debounce = Duration(
      milliseconds: context.read<SettingsController>().searchDebounceMs,
    );
    _controller.pageSize = context.read<SettingsController>().searchPageSize;
    _controller.scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onScroll() {
    if (!_controller.scroll.hasClients) return;
    final ScrollPosition position = _controller.scroll.position;
    // 120px from the end, matching the command palette. Paging on scroll rather
    // than behind a button is what makes the list feel like a list.
    if (position.pixels < position.maxScrollExtent - 120) return;
    unawaited(_controller.loadMore());
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id == widget.room.id) return;
    // The pane passes a room-keyed key, so this is belt and braces; a stale
    // controller would still be searching the previous room.
    _controller.dispose();
    _controller = RoomSearchController(
      room: widget.room,
      log: context.read<Logger>(),
      l10n: AppLocalizations.of(context)!,
    );
  }

  @override
  void dispose() {
    _controller.scroll.removeListener(_onScroll);
    _controller.dispose();
    _focus.dispose();
    _senderField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _QueryField(
            controller: _controller,
            focus: _focus,
            senderField: _senderField,
          ),
          _TypeChips(
            selected: _controller.msgType,
            onChanged: (String type) => _controller.query(
              _controller.queryField.text,
              msgType: type,
            ),
          ),
          Expanded(child: _body(l10n, scheme, t)),
          _Footer(controller: _controller),
        ],
      ),
    );
  }

  Widget _body(
      AppLocalizations l10n, ColorScheme scheme, MoonrelayDesignTokens t) {
    switch (_controller.phase) {
      case RoomSearchPhase.idle:
        return _Message(
          icon: LucideIcons.search,
          text: l10n.inRoomSearchHint,
          scheme: scheme,
        );
      case RoomSearchPhase.searching:
        return const Center(child: CircularProgressIndicator());
      case RoomSearchPhase.failed:
        return _Message(
          icon: LucideIcons.cloudOff,
          text: l10n.inRoomSearchFailed,
          scheme: scheme,
        );
      case RoomSearchPhase.empty:
        return _Message(
          icon: LucideIcons.searchX,
          text: l10n.inRoomSearchNoResults,
          scheme: scheme,
        );
      case RoomSearchPhase.results:
        final List<MessageSearchResult> results = _controller.results;
        return ListView.builder(
          controller: _controller.scroll,
          padding: EdgeInsets.only(bottom: t.spaceSm),
          itemCount: results.length + (_controller.hasMore ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index >= results.length) {
              return Padding(
                padding: EdgeInsets.all(t.spaceMd),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final MessageSearchResult hit = results[index];
            return _ResultRow(
              hit: hit,
              keywords: _controller.keywords,
              onTap: widget.onJumpToEvent == null
                  ? null
                  : () => widget.onJumpToEvent!(hit.event.eventId),
            );
          },
        );
    }
  }
}

class _QueryField extends StatelessWidget {
  const _QueryField({
    required this.controller,
    required this.focus,
    required this.senderField,
  });

  final RoomSearchController controller;
  final FocusNode focus;
  final TextEditingController senderField;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(t.spaceMd, t.spaceSm, t.spaceMd, t.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: controller.queryField,
            focusNode: focus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.inRoomSearchHint,
              prefixIcon: const Icon(LucideIcons.search, size: 16),
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spaceMd,
                vertical: t.spaceSm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusSm),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (String value) =>
                controller.query(value, sender: senderField.text),
            onSubmitted: (String value) => controller.query(
              value,
              sender: senderField.text,
            ),
          ),
          SizedBox(height: t.spaceXs),
          TextField(
            controller: senderField,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.inRoomSearchSenderHint,
              prefixIcon: const Icon(LucideIcons.userRound, size: 16),
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spaceMd,
                vertical: t.spaceSm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusSm),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (String value) =>
                controller.query(controller.queryField.text, sender: value),
            onSubmitted: (String value) => controller.query(
              controller.queryField.text,
              sender: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onChanged});

  final String selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final List<(String, String, IconData)> options =
        <(String, String, IconData)>[
      ('', l10n.inRoomSearchTypeAll, LucideIcons.list),
      ('m.text', l10n.inRoomSearchTypeText, LucideIcons.type),
      ('m.image', l10n.inRoomSearchTypeImage, LucideIcons.image),
      ('m.file', l10n.inRoomSearchTypeFile, LucideIcons.file),
      ('m.audio', l10n.inRoomSearchTypeAudio, LucideIcons.music),
      ('m.video', l10n.inRoomSearchTypeVideo, LucideIcons.video),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(width: t.spaceXs),
        itemBuilder: (BuildContext context, int index) {
          final (String value, String label, IconData icon) = options[index];
          final bool isSelected = value == selected;
          return Material(
            color: isSelected
                ? scheme.primary.withValues(alpha: t.opacitySubtle)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(t.radiusFull),
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(t.radiusFull),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusFull),
                  border: Border.all(
                    color: isSelected ? scheme.primary : scheme.outlineVariant,
                    width: t.borderWidthThin,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 13,
                      color:
                          isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    SizedBox(width: t.spaceXs),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.hit,
    required this.keywords,
    required this.onTap,
  });

  final MessageSearchResult hit;
  final List<String> keywords;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final User sender = hit.event.senderFromMemoryOrFallback;
    final String senderName = sender.calcDisplayname();
    final String body = hit.event.body;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spaceMd,
          vertical: t.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: 2),
            HighlightedText(
              text: body,
              keywords: keywords,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              highlightStyle: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                backgroundColor: scheme.primary.withValues(alpha: 0.2),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// The pane's last strip: result count, and paging state.
///
/// One footer for every phase rather than a count in the header and a spinner
/// under the list, because those two moved independently and could disagree.
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final RoomSearchController controller;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final RoomSearchPhase phase = controller.phase;
    if (phase != RoomSearchPhase.results) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Theme.of(context).moonrelay.layers.hover,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceMd,
        vertical: t.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            controller.hasMore
                ? LucideIcons.arrowDown
                : LucideIcons.circleCheck,
            size: t.iconSizeSmall,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(width: t.spaceSm),
          Expanded(
            child: Text(
              controller.hasMore
                  ? l10n.inRoomSearchMoreResults(controller.results.length)
                  : l10n.inRoomSearchResultCount(controller.results.length),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.scheme,
  });

  final IconData icon;
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: t.iconSizeLarge,
              color:
                  scheme.onSurfaceVariant.withValues(alpha: t.opacityDisabled),
            ),
            SizedBox(height: t.spaceMd),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
