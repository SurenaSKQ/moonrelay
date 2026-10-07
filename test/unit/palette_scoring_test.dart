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

// Ranking, which is the part of the palette that replaced `String.contains`.
//
// The old filter was `label.toLowerCase().contains(query)`. These cases are
// mostly about the queries that used to return nothing, because that is the
// whole argument for a scorer existing at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_result.dart';

/// Ranks [candidates] for [query] and returns their titles, best first.
List<String> rank(List<String> candidates, String query) {
  final List<PaletteResult> results = <PaletteResult>[
    for (final String title in candidates)
      PaletteResult(
        source: PaletteSource.room,
        title: title,
        icon: Icons.tag,
        run: (_) {},
      ),
  ];
  final List<PaletteResult> scored = <PaletteResult>[
    for (final PaletteResult r in results)
      if (scoreResult(r, query) case final double score)
        r.withScores(score: score, recency: 0),
  ];
  sortPaletteResults(scored);
  return scored.map((PaletteResult r) => r.title).toList();
}

void main() {
  group('the queries substring matching could not find', () {
    // Each of these is a query a user would plausibly type and a candidate that
    // contains the answer, in order, with characters missing.
    test('a dropped vowel still finds the word', () {
      expect(rank(<String>['Settings'], 'setng'), <String>['Settings']);
      expect(rank(<String>['Appearance'], 'apperance'), <String>['Appearance']);
    });

    test('an acronym finds the word it abbreviates', () {
      expect(rank(<String>['Notifications'], 'ntf'), contains('Notifications'));
      expect(rank(<String>['Keyboard Shortcuts'], 'kbind'), isEmpty);
      expect(
        rank(<String>['Keyboard Shortcuts'], 'kshort'),
        contains('Keyboard Shortcuts'),
      );
    });

    test('non-adjacent letters are found', () {
      // `gnl` is what `general` looks like with two vowels dropped, which is
      // the shape of typo people actually make. It has to find `General`.
      expect(rank(<String>['General'], 'gnl'), contains('General'));
    });

    test('but a query with letters out of order is not', () {
      // "eg" cannot be produced from "General" in order, so returning it would
      // mean the matcher is ignoring the query rather than matching it.
      expect(rank(<String>['General'], 'eg'), isEmpty);
    });

    test('and a query longer than the candidate is not', () {
      expect(rank(<String>['General'], 'generaldiscussion'), isEmpty);
    });
  });

  group('ranking is by how good the match is', () {
    test('exact beats prefix beats word start beats inside beats scattered',
        () {
      // One candidate per tier, chosen so each lands in exactly one of them:
      // `gen` exact, `genesis` prefix, `the general store` matching at a word
      // start, `xgenx` contiguous but not at a boundary, and `gxe nx` reachable
      // only by walking the string.
      expect(
        rank(<String>[
          'gxe nx',
          'xgenx',
          'the general store',
          'genesis',
          'gen',
        ], 'gen'),
        <String>['gen', 'genesis', 'the general store', 'xgenx', 'gxe nx'],
      );
    });

    test('within a tier, the shorter candidate wins', () {
      final List<String> ordered = rank(<String>[
        'general purpose',
        'general',
      ], 'general');
      expect(ordered, <String>['general', 'general purpose']);
    });

    test('camel case counts as a word boundary', () {
      // `Appearance` has no space in it, so without the case rule `app` would
      // land in the "inside a word" tier and `Settings` would outrank it.
      expect(
        scoreCandidate('app', 'appearance')!,
        greaterThan(scoreCandidate('app', 'xappearance')!),
      );
    });

    test('Matrix id punctuation counts as a word boundary', () {
      for (final String separator in <String>[
        ' ',
        '-',
        '_',
        '.',
        ':',
        '@',
        '#'
      ]) {
        expect(
          scoreCandidate('gen', 'gen${separator}rest')!,
          greaterThan(scoreCandidate('gen', 'xgen${separator}rest')!),
          reason: 'separator "$separator" should read as a boundary',
        );
      }
    });
  });

  group('what does not match', () {
    test('an empty query matches everything at zero', () {
      expect(scoreCandidate('', 'anything'), 0);
      expect(scoreCandidate('   ', 'anything'), 0);
    });

    test('an empty candidate matches nothing', () {
      expect(scoreCandidate('x', ''), isNull);
    });

    test('matching is case insensitive in both directions', () {
      expect(
          scoreCandidate('GEN', 'general'), scoreCandidate('gen', 'General'));
    });

    test('surrounding whitespace is ignored', () {
      expect(scoreCandidate(' gen ', ' general '),
          scoreCandidate('gen', 'general'));
    });

    test('a missing letter is a miss, not a fuzzy pass', () {
      expect(scoreCandidate('general', 'generall'), isNotNull);
      expect(scoreCandidate('general', 'generxl'), isNull);
    });
  });

  group('the keyword and subtitle penalties', () {
    PaletteResult result({
      String title = 'Settings',
      String? subtitle,
      List<String> keywords = const <String>[],
    }) =>
        PaletteResult(
          source: PaletteSource.room,
          title: title,
          subtitle: subtitle,
          icon: Icons.tag,
          keywords: keywords,
          run: (_) {},
        );

    test('a title hit outranks a keyword hit for the same query', () {
      final double viaTitle = scoreResult(result(title: 'Appearance'), 'app')!;
      final double viaKeyword = scoreResult(
        result(title: 'Something Else', keywords: <String>['appearance']),
        'app',
      )!;
      expect(viaTitle, greaterThan(viaKeyword));
    });

    test('a keyword hit still finds the row at all', () {
      // The penalty is a ranking weight, not an exclusion. Losing the row
      // entirely would mean the `keybinds` key could never match
      // "Keyboard Shortcuts", which is the reason it is in the keywords list.
      expect(
        scoreResult(
          result(title: 'Keyboard Shortcuts', keywords: <String>['keybinds']),
          'keyb',
        ),
        isNotNull,
      );
    });

    test('the penalty cannot lift a weak hit over a strong one', () {
      final double strong = scoreResult(result(title: 'Appearance'), 'app')!;
      final double weak = scoreResult(
        result(title: 'Alphabetical Archive', keywords: <String>['appearance']),
        'app',
      )!;
      expect(weak, lessThan(strong));
    });

    test('an empty subtitle or keyword is skipped rather than scored', () {
      // `scoreCandidate('x', '')` is null, and multiplying null is a crash.
      // Both of these used to be reachable from a room with no topic.
      expect(
        scoreResult(result(subtitle: '', keywords: <String>['']), 'x'),
        isNull,
      );
    });
  });

  group('recency', () {
    PaletteResult recent({required double score, required int rank}) =>
        PaletteResult(
          source: PaletteSource.room,
          title: 'General',
          icon: Icons.tag,
          score: score,
          recency: rank,
          run: (_) {},
        );

    test('breaks a tie between equal text', () {
      expect(
        scoreResult(recent(score: 0, rank: 3), '')!,
        greaterThan(scoreResult(recent(score: 0, rank: 0), '')!),
      );
    });

    test('cannot lift a bad match over a good one', () {
      // The whole ramp is worth 30 and the bands are 200 apart, which is what
      // makes "recent" a tiebreak rather than a ranking force.
      final double? exact = scoreCandidate('gen', 'gen');
      final double? subsequence = scoreCandidate('gen', 'green energy');
      expect(exact, isNotNull);
      expect(subsequence, isNotNull);
      expect(exact! - subsequence!, greaterThan(30));
    });
  });

  group('sorting is stable enough to look intentional', () {
    test('equal scores fall back to the title', () {
      // `List.sort` is not stable, so without this tiebreak two rows with the
      // same score would appear in whatever order their sources happened to
      // resolve in, which reads as a bug and never gets reported.
      expect(rank(<String>['zebra', 'alpha', 'mango'], ''), <String>[
        'alpha',
        'mango',
        'zebra',
      ]);
    });

    test('and the same query gives the same order every time', () {
      final List<String> a = rank(<String>[
        'General Discussion',
        'General',
        'The General Store',
      ], 'general');
      final List<String> b = rank(<String>[
        'The General Store',
        'General',
        'General Discussion',
      ], 'general');
      expect(a, b);
    });
  });

  group('the filter prefixes', () {
    test('each resolves to its own source', () {
      expect(PaletteSource.forPrefix('#'), PaletteSource.room);
      expect(PaletteSource.forPrefix('@'), PaletteSource.user);
      expect(PaletteSource.forPrefix('>'), PaletteSource.page);
    });

    test('a character that is not a prefix resolves to nothing', () {
      // `>` used to mean "settings" in a client whose users are the kind to
      // know what `>` means in a shell, which is a redirect.
      for (final String character in <String>['?', '!', '/', 'a', '1']) {
        expect(
          PaletteSource.forPrefix(character),
          isNull,
          reason: '"$character" should not silently become a filter',
        );
      }
    });

    test('rooms and spaces are one filter', () {
      // They are the same kind of thing to a user typing `#`, and splitting
      // them would need a second prefix for no benefit.
      expect(PaletteSource.room.matches(PaletteSource.space), isTrue);
      expect(PaletteSource.space.matches(PaletteSource.room), isTrue);
      expect(PaletteSource.room.matches(PaletteSource.user), isFalse);
    });
  });
}
