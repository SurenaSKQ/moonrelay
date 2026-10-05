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

// The palette's result model and its ranking.
//
// Two decisions live here rather than in the widget, and both of them used to
// be implicit in a `String.contains`.
//
// **One list, not five modes.** A result carries the kind it came from, and the
// kind knows how to run itself. Sources contribute candidates and the palette
// merges them, so a room called "General" outranks a settings page called
// "General" without anybody deciding that rooms come first. The prefix
// characters survive as filters that *narrow* the list rather than modes that
// replace it.
//
// **Subsequence matching, because substring matching is not search.** The old
// filter was `label.toLowerCase().contains(query)`, which means typing `setng`
// finds nothing in a list containing "Settings", and typing `ops` finds nothing
// in "Appearance". Both of those are the query the user meant. A subsequence
// match gets them, and a rank keeps the ones that matched at a word start above
// the ones that matched by accident.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

// -- Sources -------------------------------------------------------------------

/// Where a result came from, which is also how the prefix filters narrow it.
///
/// The palette's prefixes were `?` search, `>` settings, `#` rooms, `@` users.
/// Those survive as [PaletteSource]s because they are genuinely useful for
/// disambiguating a name that could be a room or a person, and what they do not
/// survive as is the idea that typing without one puts you somewhere else
/// entirely.
enum PaletteSource {
  /// A joined room.
  room(icon: null, prefix: '#'),

  /// A joined space.
  space(icon: null, prefix: '#'),

  /// A message in a room, from the server's message search.
  message(icon: null, prefix: null),

  /// Someone in the user directory.
  user(icon: null, prefix: '@'),

  /// A public room on the homeserver, not yet joined.
  directory(icon: null, prefix: null),

  /// A page in the hub, which is what the old `>` mode listed.
  page(icon: null, prefix: '>'),

  /// An action with no page of its own, like toggling a sidebar.
  action(icon: null, prefix: null);

  const PaletteSource({required this.icon, required this.prefix});

  /// The icon shown in the result row.
  ///
  /// Null here and supplied by the row renderer, because an icon belongs to the
  /// result and not to its category. A space and a room are the same widget
  /// with a different glyph, and they are told apart by [PaletteResult.title]
  /// and the row, not by the enum.
  final IconData? icon;

  /// The character that narrows the palette to this source, or null if this
  /// source has no prefix of its own.
  final String? prefix;

  /// The source a leading [character] narrows to, or null if it narrows to
  /// nothing.
  static PaletteSource? forPrefix(String character) {
    for (final PaletteSource source in PaletteSource.values) {
      if (source.prefix == character) return source;
    }
    return null;
  }

  /// True when [other] is the same kind of thing, ignoring the distinction
  /// between a room and a space.
  bool matches(PaletteSource other) =>
      this == other ||
      (this == space && other == room) ||
      (this == room && other == space);
}

// -- Results -------------------------------------------------------------------

/// One row in the palette, already scored against the current query.
///
/// A result knows how to run itself, so adding a kind of thing to the palette
/// means adding an enum value and a constructor call rather than a branch in a
/// list builder and a second branch in the "what does Enter do" function. That
/// duplication is how the old palette ended up with four copies of the filter
/// logic that could disagree with each other.
class PaletteResult {
  const PaletteResult({
    required this.source,
    required this.title,
    required this.icon,
    required this.run,
    this.subtitle,
    this.keywords = const <String>[],
    this.score = 0,
    this.recency = 0,
  });

  /// Which kind of thing this is.
  final PaletteSource source;

  /// The primary line. This is what the query is matched against first.
  final String title;

  /// The secondary line, if the kind has one: a room's topic, a message's
  /// sender, a directory entry's member count.
  final String? subtitle;

  /// Icon for the row. Supplied per result rather than per [PaletteSource],
  /// because a room and a space differ by glyph and a page and an action
  /// differ by meaning.
  final IconData icon;

  /// Extra text the query may match against, weighted below [title].
  ///
  /// This is how `keybind` finds "Keyboard Shortcuts" without the word
  /// "keybind" appearing anywhere in the user's interface.
  final List<String> keywords;

  /// Ranking score. Higher is better. Set by the palette, not by the source.
  final double score;

  /// Recency boost, newest first: 0 for unseen, then a decreasing ramp.
  ///
  /// The old palette recorded recents and then rendered them as a separate
  /// section below the full command list, under a 24px divider, inside a 420px
  /// scroll view. So the thing it was built to surface was below the fold of
  /// the thing it was built to filter.
  final int recency;

  /// What happens when this row is chosen.
  final void Function(BuildContext context) run;

  PaletteResult withScores({required double score, required int recency}) =>
      PaletteResult(
        source: source,
        title: title,
        subtitle: subtitle,
        icon: icon,
        keywords: keywords,
        score: score,
        recency: recency,
        run: run,
      );

  /// Builds a result for a joined room or space.
  factory PaletteResult.room(Room room, void Function(BuildContext) run) {
    final bool isSpace = room.isSpace;
    return PaletteResult(
      source: isSpace ? PaletteSource.space : PaletteSource.room,
      title: room.getLocalizedDisplayname(),
      subtitle: room.topic,
      icon: isSpace ? Icons.account_tree_outlined : Icons.tag,
      keywords: <String>[
        room.id,
        if (room.canonicalAlias.isNotEmpty) room.canonicalAlias,
      ],
      run: run,
    );
  }
}

// -- Scoring -------------------------------------------------------------------

/// Score bands, chosen so that no two tiers can produce a score that ranks
/// across a tier boundary.
///
/// The gaps are wide because a candidate's *length* penalty can be large: a
/// room called "General Discussion" and one called "General" differ by sixteen
/// points inside the prefix tier, and without the gaps a long exact-prefix hit
/// in a weaker tier could beat a short exact match in a stronger one.
abstract final class MatchBand {
  static const double exact = 1000;
  static const double prefix = 800;
  static const double wordStart = 600;
  static const double contiguous = 400;
  static const double subsequence = 200;

  /// Multiplier applied when the match was found in a keyword or the subtitle
  /// rather than the title.
  static const double secondaryPenalty = 0.4;
}

/// Characters that begin a word, for the word-start tier.
///
/// A space is the obvious one. The rest matter because Matrix names are full of
/// them: `!roomid:server`, `@user:server`, `#alias:server`, and camel case.
const Set<String> _wordSeparators = <String>{
  ' ',
  '-',
  '_',
  '.',
  ':',
  '/',
  '@',
  '#',
  '!',
  '+',
};

/// True when [index] begins a word inside [candidate].
///
/// Index zero always counts, and an upper-case letter counts when the letter
/// before it is lower-case, which is the camel-case rule and the reason
/// `Appearance` is a word-start hit for `app`.
bool _isWordStart(String candidate, int index) {
  if (index == 0) return true;
  final String previous = candidate[index - 1];
  if (_wordSeparators.contains(previous)) return true;
  final String current = candidate[index];
  final bool currentIsUpper = current != current.toLowerCase();
  final bool previousIsLower = previous == previous.toLowerCase();
  return currentIsUpper && previousIsLower;
}

/// How well [candidate] matches [query], or null when it does not match.
///
/// The tiers, in order: exact, prefix, word-start, contiguous, subsequence.
/// Within a tier, a shorter candidate outranks a longer one, and an earlier
/// match outranks a later one.
///
/// An empty [query] matches everything with a score of zero. That is what makes
/// the empty palette show its recents in a sensible order rather than in
/// whatever order the sources happened to fan in.
double? scoreCandidate(String query, String candidate) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  final String c = candidate.trim().toLowerCase();
  if (c.isEmpty) return null;

  // A length penalty that can never lift a candidate across a tier boundary:
  // the widest gap between tiers is 200, and no plausible title is 400
  // characters, so capping the penalty at 150 keeps the ordering a pure
  // function of tiers.
  double lengthPenalty(int extra) => -(extra > 150 ? 150 : extra).toDouble();

  if (c == q) return MatchBand.exact;

  if (c.startsWith(q)) {
    return MatchBand.prefix + lengthPenalty(c.length - q.length);
  }

  // Word start, taking the *best* one rather than the first, so a candidate
  // that matches a word early scores better than one that matches a word late
  // even though both are in the tier.
  double? bestWordStart;
  for (int i = 0; i <= c.length - q.length; i++) {
    if (!c.startsWith(q, i)) continue;
    if (!_isWordStart(c, i)) continue;
    final double score = MatchBand.wordStart + lengthPenalty(i);
    if (bestWordStart == null || score > bestWordStart) bestWordStart = score;
  }
  if (bestWordStart != null) return bestWordStart;

  final int at = c.indexOf(q);
  if (at >= 0) {
    return MatchBand.contiguous + lengthPenalty(at + c.length - q.length);
  }

  // Subsequence. Greedy left-to-right is enough for ranking and is the reason
  // a gap-heavy match scores below a tight one.
  int cursor = 0;
  int gaps = 0;
  for (int i = 0; i < q.length; i++) {
    final int found = c.indexOf(q[i], cursor);
    if (found < 0) return null;
    gaps += found - cursor;
    cursor = found + 1;
  }
  return MatchBand.subsequence + lengthPenalty(gaps + c.length - q.length);
}

/// The score for a whole [PaletteResult], taking the best of its title, its
/// subtitle and its keywords, and adding the recency boost.
///
/// The recency ramp is deliberately small: it breaks ties between candidates of
/// equal textual quality and it never lifts a weak match over a strong one,
/// because the bands are hundreds apart and the whole ramp is worth 30.
double? scoreResult(PaletteResult result, String query) {
  final double? title = scoreCandidate(query, result.title);
  double? best = title;

  final String? subtitle = result.subtitle;
  if (subtitle != null && subtitle.isNotEmpty) {
    final double? asSubtitle = scoreCandidate(query, subtitle) == null
        ? null
        : scoreCandidate(query, subtitle)! * MatchBand.secondaryPenalty;
    if (asSubtitle != null && (best == null || asSubtitle > best)) {
      best = asSubtitle;
    }
  }

  for (final String keyword in result.keywords) {
    if (keyword.isEmpty) continue;
    final double? raw = scoreCandidate(query, keyword);
    if (raw == null) continue;
    final double asKeyword = raw * MatchBand.secondaryPenalty;
    if (best == null || asKeyword > best) best = asKeyword;
  }

  if (best == null) return null;
  return best + result.recency * 10;
}

/// Orders [results] for display: best score first, then a stable tiebreak.
///
/// The tiebreak is the title, lowercased, so two equally good matches sort the
/// same way every time the palette is opened. `List.sort` is not stable, so
/// without it the order of two equal-scoring rows would depend on which source
/// happened to resolve first, which is exactly the sort of thing that looks
/// like a bug and never gets reported.
void sortPaletteResults(List<PaletteResult> results) {
  results.sort((PaletteResult a, PaletteResult b) {
    final int byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final int byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (byTitle != 0) return byTitle;
    return a.source.index.compareTo(b.source.index);
  });
}
