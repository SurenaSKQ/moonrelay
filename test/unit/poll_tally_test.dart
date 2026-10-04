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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/poll_message_type.dart';

void main() {
  group('pollBarShare', () {
    // The regression. Every bar used to be drawn relative to the leading
    // option, so the leading bar was always full width no matter how the
    // votes had actually split, and a poll with one vote per option rendered
    // as N full bars.
    test('splits the width between the options rather than filling the winner',
        () {
      expect(pollBarShare(3, 10), closeTo(0.3, 1e-9));
      expect(pollBarShare(7, 10), closeTo(0.7, 1e-9));
    });

    test('an even split is an even set of bars', () {
      expect(pollBarShare(1, 4), closeTo(0.25, 1e-9));
      expect(pollBarShare(1, 10), closeTo(0.1, 1e-9));
    });

    test('no votes is no width, not a division by zero', () {
      expect(pollBarShare(0, 0), 0);
      expect(pollBarShare(0, 5), 0);
    });

    test('a count larger than the total is clamped rather than overflowing',
        () {
      // Reachable when an answer id is voted for that is no longer listed in
      // the poll, so the bar must not draw past the card.
      expect(pollBarShare(9, 3), 1.0);
    });
  });

  group('tallyPollResponses', () {
    // Responses arrive newest first, the order a timeline hands them over.
    test('counts a single vote from one voter', () {
      final tally = tallyPollResponses(<PollResponse>[
        (sender: '@ada:example.org', answers: <String>['a']),
      ]);

      expect(tally.counts, <String, int>{'a': 1});
      expect(tally.voters, 1);
      expect(tally.answersBySender['@ada:example.org'], <String>{'a'});
    });

    test('counts each voter once', () {
      final tally = tallyPollResponses(<PollResponse>[
        (sender: '@ada:example.org', answers: <String>['a']),
        (sender: '@bob:example.org', answers: <String>['b']),
        (sender: '@cleo:example.org', answers: <String>['b']),
      ]);

      expect(tally.counts, <String, int>{'a': 1, 'b': 2});
      expect(tally.voters, 3);
    });

    // The other half of the same bug: MSC3381 supersedes a sender's earlier
    // response with their later one, so someone who changes their mind sends a
    // second response. Adding up the raw events counted them twice.
    test('a re-vote replaces rather than adds', () {
      final tally = tallyPollResponses(<PollResponse>[
        // Newest first: Ada voted b, and used to vote a.
        (sender: '@ada:example.org', answers: <String>['b']),
        (sender: '@bob:example.org', answers: <String>['a']),
        (sender: '@ada:example.org', answers: <String>['a']),
      ]);

      expect(tally.counts, <String, int>{'a': 1, 'b': 1});
      expect(tally.voters, 2);
      expect(
        tally.answersBySender['@ada:example.org'],
        <String>{'b'},
        reason: 'the newer response is the vote, so the older one must not '
            'still show as one of the current user\'s answers',
      );
    });

    test('a voter who revotes three times is still one voter', () {
      final tally = tallyPollResponses(<PollResponse>[
        (sender: '@ada:example.org', answers: <String>['c']),
        (sender: '@ada:example.org', answers: <String>['b']),
        (sender: '@ada:example.org', answers: <String>['a']),
      ]);

      expect(tally.counts, <String, int>{'c': 1});
      expect(tally.voters, 1);
    });

    test('an empty response counts the voter but no answer', () {
      final tally = tallyPollResponses(<PollResponse>[
        (sender: '@ada:example.org', answers: <String>[]),
      ]);

      expect(tally.counts, isEmpty);
      expect(tally.voters, 1);
    });

    test('no responses is an empty tally, not a crash', () {
      final tally = tallyPollResponses(const <PollResponse>[]);

      expect(tally.counts, isEmpty);
      expect(tally.voters, 0);
      expect(tally.answersBySender, isEmpty);
    });

    test('a multi-answer response still counts one voter', () {
      // The UI only ever sends one answer, but a poll started elsewhere can
      // allow several, and a timeline will hand both of those to us.
      final tally = tallyPollResponses(<PollResponse>[
        (sender: '@ada:example.org', answers: <String>['a', 'b']),
        (sender: '@bob:example.org', answers: <String>['a']),
      ]);

      expect(tally.counts, <String, int>{'a': 2, 'b': 1});
      expect(tally.voters, 2);
    });
  });
}
