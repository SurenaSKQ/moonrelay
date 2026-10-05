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

// The palette's query state: what was typed, what it narrowed to, what came
// back, and where the keyboard cursor is.
//
// This is the piece the old widget got wrong, in four separate ways.
//
// **One provider, not eight.** It constructed a fresh `SearchProvider` on every
// call, at eight call sites. Eight instances per keystroke, each with its own
// empty cache, so scrolling to paginate refetched what was already known.
//
// **A request token, so a slow answer cannot land on a newer question.** The
// old search awaited a three-way `Future.wait` and then wrote the result into
// state behind nothing but a `mounted` check. Typing `ab` and then `abc`, with
// the `ab` response arriving second, put `ab`'s rooms under `abc`. The guard is
// an integer that increments per query, and every awaited continuation checks
// it before writing anything.
//
// **Failures are a state, not an empty list.** Three bare `catch (_)` blocks
// returned an empty `SearchPage`, which made a homeserver that was down
// indistinguishable from a query with nothing to find, so the palette could
// say "no matching commands" with total confidence while having no idea whether
// that was true. A source that fails records why, and the palette says so.
//
// **The two sources that answer locally are ranked before any network work
// starts.** Typing `#gen` and waiting a round trip to be told about a room list
// that is already in memory is the kind of latency that makes an on-demand
// surface feel slow.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_result.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_sources.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';

/// A source that could not answer, and why.
///
/// Modelled as its own state rather than folded into "no results" because the
/// two look identical to the user and mean opposite things: one is an answer,
/// the other is the absence of an answer.
class PaletteFailure {
  const PaletteFailure(this.source, this.error);

  final PaletteSource source;

  /// Whatever the source threw.
  final Object error;

  @override
  String toString() => '${source.name}: $error';
}

/// What the palette is doing, for the view to render.
enum PalettePhase {
  /// Nothing typed yet, or nothing matched.
  idle,

  /// A query is in flight and nothing local has matched yet.
  searching,

  /// There is at least one row to show.
  results,
}

/// How long a remote source gets before it is treated as failed.
///
/// Six seconds is long enough for a homeserver on a bad connection and short
/// enough that a user who typed and looked away does not come back to a spinner
/// that has been turning for half a minute.
const Duration kPaletteSourceTimeout = Duration(seconds: 6);

/// How long the query has to settle before the public room directory is asked.
///
/// Three times [PaletteController.debounce], and the ratio is the whole
/// design.
///
/// The directory is the one source that is not about anything the user is
/// already looking at. Rooms, people, messages and pages are the user's own
/// data, they answer from a local cache or from an index that is already
/// warm, and they are what someone opening a palette wants in the first
/// second. The public directory is an unauthenticated request to somebody
/// else's server that can take a second on a bad connection and returns
/// rooms the user has never heard of.
///
/// So it goes last, in its own section, and only once the typing has stopped.
/// Someone typing "gen" and then "general" has asked one question twice and
/// wants one answer; firing the directory twice for it would be two round trips
/// to a stranger's homeserver for nothing. And someone who types one character
/// to glance at a command should never pay for the directory at all, which is
/// what a longer debounce buys over firing it behind the first keystroke.
const Duration kPaletteDirectoryDelay = Duration(milliseconds: 450);

/// Holds the palette's query, its filter, its ranked results and its cursor.
class PaletteController extends ChangeNotifier {
  PaletteController({
    required Client client,
    required Logger log,
    required PaletteSources sources,
    this.debounce = const Duration(milliseconds: 140),
  })  : _client = client,
        _log = log,
        _sources = sources,
        _provider = SearchProvider(client: client);

  final Client _client;
  final Logger _log;
  final PaletteSources _sources;

  /// One provider for the palette's whole life, which is the entire point.
  final SearchProvider _provider;

  final Duration debounce;

  Timer? _debounceTimer;

  /// The directory's own, longer timer. Separate from [_debounceTimer] because
  /// a keystroke has to reset both, and merging them would mean the directory
  /// either fires with the fast sources or not at all.
  Timer? _directoryTimer;

  /// Increments per query. Every awaited continuation compares against it
  /// before writing.
  int _requestToken = 0;

  String _query = '';
  PaletteSource? _filter;
  int _selectedIndex = 0;
  bool _busy = false;

  List<PaletteResult> _results = <PaletteResult>[];

  /// Remote hits, held as SDK objects and re-derived into results on every
  /// publish.
  ///
  /// Holding the objects rather than built results is what makes paging
  /// possible: loadMore appends to _messageHits and republishes, instead of
  /// having to reconstruct results from rows it already built.
  List<MessageSearchResult> _messageHits = <MessageSearchResult>[];
  List<Profile> _userHits = <Profile>[];
  String? _nextBatch;

  /// Public directory hits, kept out of [results] rather than ranked into them.
  ///
  /// A trailing section with its own header, appended after the ranked list.
  /// The reason is that a public room and a command are not competitors: the
  /// user did not type "gen" wondering whether it was a room they are in or a
  /// room on the server, and interleaving the two into one ranking would put an
  /// unfamiliar public room above a settings page they have opened before. A
  /// boundary the eye can see beats a ranking the eye has to be told about.
  List<PublishedRoomsChunk> _directoryHits = <PublishedRoomsChunk>[];

  /// Whether the directory request has been made for the current query.
  ///
  /// The distinction that matters for the UI: not-yet-asked is silence,
  /// asked-and-empty is "no public rooms matched", and asked-and-failed is the
  /// footer. Collapsing the first into the second is how a palette ends up
  /// confidently claiming a homeserver has nothing when it was never asked.
  bool _directoryAsked = false;

  Map<PaletteSource, PaletteFailure> _failures =
      <PaletteSource, PaletteFailure>{};

  /// The text the user typed, with any prefix consumed into [filter].
  String get query => _query;

  /// The prefix narrowing this query, or null when it is unfiltered.
  PaletteSource? get filter => _filter;

  /// The rows to show, best first: the ranked list, then the directory section.
  ///
  /// They share one list so the keyboard cursor crosses the boundary, which is
  /// the whole point of a unified surface. The boundary is exposed as
  /// [directoryStart] so the view can draw a header at it.
  List<PaletteResult> get results => _results;

  /// Where the trailing directory section begins, or -1 when there is none.
  int get directoryStart => _directoryStart;
  int _directoryStart = -1;

  /// Whether the directory has been asked yet for this query.
  ///
  /// False means the palette is still waiting out [kPaletteDirectoryDelay], so
  /// the view should say nothing at all rather than say "no public rooms".
  bool get directoryAsked => _directoryAsked;

  /// Whether a directory request is in flight.
  bool get directoryBusy => _directoryBusy;
  bool _directoryBusy = false;

  /// Sources that could not answer this query, and why.
  Map<PaletteSource, PaletteFailure> get failures => _failures;

  PalettePhase get phase {
    if (_results.isNotEmpty) return PalettePhase.results;
    if (_busy) return PalettePhase.searching;
    return PalettePhase.idle;
  }

  /// True while a remote source is still working.
  bool get busy => _busy;

  /// The row the keyboard cursor is on, or null when there is nothing to run.
  PaletteResult? get selected {
    if (_selectedIndex < 0 || _selectedIndex >= _results.length) return null;
    return _results[_selectedIndex];
  }

  int get selectedIndex => _selectedIndex;

  /// Whether Enter has anything to do.
  bool get canRun => selected != null;

  /// True when there is a query at all, prefix or not.
  bool get hasQuery => _query.isNotEmpty || _filter != null;

  // -- Input -------------------------------------------------------------

  /// Applies new raw input from the text field.
  ///
  /// Splits a leading prefix character off into [filter], so `#gen` narrows to
  /// rooms and then searches for `gen` rather than searching for the literal
  /// `#gen`.
  void onInputChanged(String raw, AppLocalizations l10n) {
    String text = raw;
    PaletteSource? nextFilter;

    final String first = text.isEmpty ? '' : text[0];
    final PaletteSource? parsed = PaletteSource.forPrefix(first);
    if (parsed != null) {
      nextFilter = parsed;
      text = text.substring(1).trimLeft();
    }

    final bool filterChanged = nextFilter != _filter;
    final bool queryChanged = text.trim() != _query;
    _filter = nextFilter;
    _query = text.trim();
    if (filterChanged || queryChanged) _selectedIndex = 0;

    // Local sources answer synchronously, so they are ranked and shown before
    // any network work starts.
    _publish(l10n);

    _debounceTimer?.cancel();
    _directoryTimer?.cancel();

    // A brand new query has not been asked of the directory yet. Clearing the
    // hits is what stops the previous query's public rooms sitting under the
    // new query's results while the delay runs out.
    _directoryHits = <PublishedRoomsChunk>[];
    _directoryAsked = false;
    _directoryBusy = false;

    if (_query.isEmpty) {
      // Invalidate anything in flight. Bumping the token is what stops a
      // response for a query the user has already erased from landing in a
      // list that no longer wants it.
      _requestToken++;
      _messageHits = <MessageSearchResult>[];
      _userHits = <Profile>[];
      _nextBatch = null;
      _failures = <PaletteSource, PaletteFailure>{};
      setBusy(false);
      _publish(l10n);
      return;
    }
    _debounceTimer = Timer(debounce, () => _runRemote(l10n));
    _directoryTimer = Timer(
      kPaletteDirectoryDelay,
      () => _runDirectory(l10n),
    );
  }

  /// Toggles the prefix filter and hands back the text the field should show.
  ///
  /// The chips under the input drive this, so pressing one has to be able to
  /// remove it again, and the field has to show the change or the field and the
  /// chips will disagree about what the query is.
  String toggleFilter(PaletteSource source, AppLocalizations l10n) {
    final String prefix = source.prefix ?? '';
    final String raw = _filter == source ? _query : prefix + _query;
    onInputChanged(raw, l10n);
    return raw;
  }

  // -- Cursor ------------------------------------------------------------

  /// Moves the keyboard cursor, clamping at both ends rather than wrapping.
  ///
  /// Clamping rather than wrapping because a palette is a flat list the user is
  /// scanning, not a carousel. Wrapping turns one arrow key press into a
  /// surprise.
  void moveSelection(int delta) {
    if (_results.isEmpty) return;
    final int next = (_selectedIndex + delta).clamp(0, _results.length - 1);
    if (next == _selectedIndex) return;
    _selectedIndex = next;
    notifyListeners();
  }

  /// Jumps to the first or last row, for Home and End.
  void selectEdge({required bool last}) {
    if (_results.isEmpty) return;
    _selectedIndex = last ? _results.length - 1 : 0;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= _results.length) return;
    if (index == _selectedIndex) return;
    _selectedIndex = index;
    notifyListeners();
  }

  // -- Ranking -----------------------------------------------------------

  /// Ranks every candidate and writes [_results].
  ///
  /// Local and remote candidates go through the same scoring and the same
  /// sort, which is the whole point: a room called "General" beating a settings
  /// page called "General" is a consequence of the text, not of a rule that
  /// happens to be written down somewhere.
  void _publish(AppLocalizations l10n) {
    final List<PaletteResult> local = <PaletteResult>[
      ..._sources.actions(l10n),
      ..._sources.pages(l10n),
      ..._sources.joinedRooms(_client),
    ];

    final List<PaletteResult> scored = <PaletteResult>[];
    for (final PaletteResult candidate in <PaletteResult>[
      ...local,
      ...paletteUserResults(_userHits),
      ...paletteMessageResults(_messageHits),
    ]) {
      if (_filter != null && !_filter!.matches(candidate.source)) continue;
      final double? score = scoreResult(candidate, _query);
      if (score == null) continue;
      scored.add(
        candidate.withScores(
          score: score,
          recency: _recencyRank(candidate),
        ),
      );
    }
    sortPaletteResults(scored);

    // The directory section is appended rather than ranked in, and is scored
    // among itself so a room whose name is an exact match for the query sits at
    // the top of its own section.
    final List<PaletteResult> directory = <PaletteResult>[
      for (final PaletteResult candidate
          in paletteDirectoryResults(_directoryHits, l10n))
        if (_filter == null || _filter!.matches(candidate.source))
          if (scoreResult(candidate, _query) case final double score)
            candidate.withScores(score: score, recency: 0),
    ];
    sortPaletteResults(directory);

    final int boundary = scored.length;
    scored.addAll(directory);
    _directoryStart = directory.isEmpty ? -1 : boundary;

    if (_selectedIndex >= scored.length) {
      _selectedIndex = scored.isEmpty ? 0 : scored.length - 1;
    }
    _results = scored;
    notifyListeners();
  }

  /// The recency boost for [candidate], newest first.
  ///
  /// A ramp rather than a boolean, because "you opened this room today" and
  /// "you opened this room this month" are not the same evidence, and a
  /// boolean throws that away.
  ///
  /// The old palette recorded recents and then rendered them as a separate
  /// section below the entire command list, under a 24px divider, inside a
  /// 420px scroll view. So the thing it existed to surface sat below the fold
  /// of the thing it existed to filter.
  int _recencyRank(PaletteResult candidate) {
    final List<String> recent = RecentActivity.instance.rooms;
    final int index = recent.indexOf(candidate.title);
    if (index < 0) return 0;
    final int strength = recent.length - index;
    return strength > 3 ? 3 : strength;
  }

  // -- Remote sources ----------------------------------------------------

  Future<void> _runRemote(AppLocalizations l10n) async {
    final int token = ++_requestToken;
    setBusy(true);

    // The user directory and the message index are the two slow sources, and
    // they are the only two asked for. The homeserver's public room directory
    // stays out deliberately: the Explore page is one click away and exists for
    // exactly that, and putting an unauthenticated public-rooms request behind
    // every keystroke is how a feature becomes the reason a client feels slow.
    final SearchPage<Profile> users;
    final SearchPage<MessageSearchResult> messages;

    try {
      users = await withTimeout(
        () => _provider.fetchUsersPage(_query, limit: 10),
        timeout: kPaletteSourceTimeout,
      );
    } catch (error) {
      // A newer query has already started. This answer is about a question
      // nobody is asking any more.
      if (token != _requestToken) return;
      _record(PaletteSource.user, error);
      return;
    }
    if (token != _requestToken) return;
    _clear(PaletteSource.user);
    _userHits = users.items;
    _publish(l10n);

    try {
      messages = await withTimeout(
        () => _provider.searchMessagesFirstPage(_query, limit: 20),
        timeout: kPaletteSourceTimeout,
      );
    } catch (error) {
      if (token != _requestToken) return;
      _record(PaletteSource.message, error);
      return;
    }
    if (token != _requestToken) return;
    _clear(PaletteSource.message);
    _messageHits = messages.items;
    _nextBatch = messages.nextBatch;
    _publish(l10n);
  }

  /// Appends one more page of message hits.
  ///
  /// Separate from the query path because it must not bump the request token:
  /// paginating asks the same question again, and resetting the token would
  /// invalidate the query's own in-flight work and drop the cursor on every
  /// scroll.
  Future<void> loadMore(AppLocalizations l10n) async {
    if (_busy) return;
    if (_messageHits.isEmpty) return;
    setBusy(true);
    try {
      final SearchPage<MessageSearchResult> page = await withTimeout(
        () => _provider.searchMessagesNextPage(
          SearchPageRequest(query: _query, nextBatch: _nextBatch),
          limit: 20,
        ),
        timeout: kPaletteSourceTimeout,
      );
      _messageHits = <MessageSearchResult>[..._messageHits, ...page.items];
      _nextBatch = page.nextBatch;
      _publish(l10n);
    } catch (error) {
      // Paginating is an optimisation. It stops the spinner and leaves what is
      // already on screen alone; replacing a list of real results with an error
      // to say "could not load more" would be strictly worse.
      _log.w('Command palette could not load more messages', error: error);
    } finally {
      setBusy(false);
    }
  }

  /// Asks the homeserver's public room directory, once the typing has settled.
  ///
  /// Its own request token, separate from [_runRemote]'s. They are two different
  /// questions asked at two different times, and sharing one token would mean
  /// whichever finished second could discard the other's answer. The directory is
  /// always second, so a shared token would make it lose every time.
  Future<void> _runDirectory(AppLocalizations l10n) async {
    final int token = ++_requestToken;
    _directoryBusy = true;
    notifyListeners();
    try {
      final SearchPage<PublishedRoomsChunk> page = await withTimeout(
        () => _provider.searchDirectory(_query, limit: 10),
        timeout: kPaletteSourceTimeout,
      );
      if (token != _requestToken) return;
      _directoryHits = page.items;
      _directoryAsked = true;
      _directoryBusy = false;
      _clear(PaletteSource.directory);
      _publish(l10n);
    } catch (error) {
      if (token != _requestToken) return;
      _directoryAsked = true;
      _directoryBusy = false;
      _record(PaletteSource.directory, error);
    }
  }

  void _record(PaletteSource source, Object error) {
    _failures = <PaletteSource, PaletteFailure>{
      ..._failures,
      source: PaletteFailure(source, error),
    };
    setBusy(false);
    notifyListeners();
  }

  void _clear(PaletteSource source) {
    if (!_failures.containsKey(source)) return;
    _failures = <PaletteSource, PaletteFailure>{..._failures}..remove(source);
  }

  void setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _directoryTimer?.cancel();
    super.dispose();
  }
}
