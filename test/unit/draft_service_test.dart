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

// Unit tests for `DraftService`.
//
// Covers:
//   - load returns an empty draft when nothing is stored
//   - saveNow + load round-trips body and reply target
//   - empty drafts are removed (not stored as empty objects)
//   - namespacing prevents cross-account leakage
//   - debounced scheduleSave eventually persists and clear() removes the
//     stored value

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/services/draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DraftService', () {
    late DraftService drafts;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      drafts = DraftService.instanceFor('@user:example.com');
    });

    tearDown(() async {
      drafts.release();
    });

    test('load returns an empty draft when nothing is stored', () async {
      final draft = await drafts.load('!room:example.com');
      expect(draft.isEmpty, isTrue);
      expect(draft.body, isEmpty);
      expect(draft.replyToEventId, isNull);
    });

    test('saveNow + load round-trips body and reply target', () async {
      await drafts.saveNow(
        '!room:example.com',
        'half-typed message',
        replyToEventId: '\$evt1:example.com',
      );

      final loaded = await drafts.load('!room:example.com');
      expect(loaded.body, 'half-typed message');
      expect(loaded.replyToEventId, '\$evt1:example.com');
      expect(loaded.isEmpty, isFalse);
    });

    test('saving an empty body removes the entry', () async {
      await drafts.saveNow('!room:example.com', 'something');
      await drafts.saveNow('!room:example.com', '');

      final loaded = await drafts.load('!room:example.com');
      expect(loaded.isEmpty, isTrue);
    });

    test('different accounts do not see each other\'s drafts', () async {
      final otherDrafts = DraftService.instanceFor('@other:example.com');
      try {
        await drafts.saveNow('!room:example.com', 'user A draft');
        await otherDrafts.saveNow(
          '!room:example.com',
          'user B draft',
        );

        final aLoaded = await drafts.load('!room:example.com');
        final bLoaded = await otherDrafts.load('!room:example.com');

        expect(aLoaded.body, 'user A draft');
        expect(bLoaded.body, 'user B draft');
        expect(aLoaded.body, isNot(bLoaded.body));
      } finally {
        await otherDrafts.clear('!room:example.com');
        otherDrafts.release();
      }
    });

    test('clear removes the persisted draft', () async {
      await drafts.saveNow('!room:example.com', 'something');
      await drafts.clear('!room:example.com');
      final loaded = await drafts.load('!room:example.com');
      expect(loaded.isEmpty, isTrue);
    });

    test('scheduleSave persists after the debounce window', () async {
      drafts.scheduleSave('!room:example.com', 'in-progress');
      // The debounce is 500ms; allow some slack so the test is stable on
      // slow CI machines.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final loaded = await drafts.load('!room:example.com');
      expect(loaded.body, 'in-progress');
    });

    group('retention (draftRetentionDays)', () {
      const room = '!retention:example.com';

      test('a draft within the window is returned', () async {
        await drafts.saveNow(room, 'recent thought');

        final loaded = await drafts.load(
          room,
          maxAge: const Duration(days: 30),
        );
        expect(loaded.body, 'recent thought');
      });

      test('a draft older than the window is treated as absent', () async {
        await drafts.saveNow(room, 'ancient thought');

        // A zero window makes any non-zero age expired, without having to
        // wait real days or hand-write a timestamp.
        final loaded = await drafts.load(room, maxAge: Duration.zero);
        expect(loaded.isEmpty, isTrue,
            reason: 'an expired draft must not be restored into the composer');
      });

      test('an expired draft is also dropped from storage', () async {
        await drafts.saveNow(room, 'ancient thought');

        await drafts.load(room, maxAge: Duration.zero);

        // Loading again with no window must not resurrect it.
        final second = await drafts.load(room);
        expect(second.isEmpty, isTrue);
      });

      test('no window means no expiry', () async {
        await drafts.saveNow(room, 'still here');

        final loaded = await drafts.load(room);
        expect(loaded.body, 'still here');
      });
    });

    group('autosave debounce (draftAutosaveMs)', () {
      test('setDebounce is honoured and defaults to 500ms', () async {
        expect(drafts.debounce, const Duration(milliseconds: 500));

        drafts.setDebounce(const Duration(milliseconds: 20));
        expect(drafts.debounce, const Duration(milliseconds: 20));

        drafts.scheduleSave('!debounce:example.com', 'quick');
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final loaded = await drafts.load('!debounce:example.com');
        expect(loaded.body, 'quick',
            reason: 'a 20ms debounce should have flushed well within 200ms');
      });

      test('a reconfigured service keeps the new window', () async {
        // The service is a ref-counted singleton, so the value pushed by
        // the composer has to survive for later composers.
        drafts.setDebounce(const Duration(milliseconds: 30));
        expect(drafts.debounce, const Duration(milliseconds: 30));
      });
    });
  });
}