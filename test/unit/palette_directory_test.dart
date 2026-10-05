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

// The public room directory's delay, and the boundary it sits behind.
//
// The delay is the feature. A directory request fired behind the first
// keystroke is a request to a stranger's homeserver every time somebody types a
// command, and it lands above rooms and settings in a ranking it does not belong
// in. So it waits for the typing to stop, and it gets its own section at the
// end.
//
// The timing tests pump a real `PaletteController` against a mock client and
// count the requests. A test that only asserted "the directory appears
// eventually" would pass just as happily with a delay of zero, which is the
// specific regression this file exists to catch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_controller.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_result.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_sources.dart';

import '../helpers/mocks.dart';

PublishedRoomsChunk chunk({
  String roomId = '!pub:matrix.org',
  String? roomType,
  String? name,
  String? alias,
  String? topic,
  int members = 4,
}) =>
    PublishedRoomsChunk(
      roomId: roomId,
      guestCanJoin: true,
      worldReadable: true,
      numJoinedMembers: members,
      roomType: roomType,
      name: name,
      canonicalAlias: alias,
      topic: topic,
    );

void main() {
  late AppLocalizations l10n;

  setUp(() async {
    // `AppLocalizations` cannot be constructed outside its generated
    // subclasses, and both the controller and the source converters need one,
    // so the strings come from the real delegate rather than a hand-rolled fake
    // that could drift from the ARB.
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('the delay is longer than the query debounce', () {
    test('so the directory cannot fire with the fast sources', () {
      // If these were equal the delay would be decorative.
      expect(kPaletteDirectoryDelay,
          greaterThan(const Duration(milliseconds: 140)));
    });

    test('and long enough to mean "the user stopped typing"', () {
      // Below roughly a third of a second it fires mid-word, which is the
      // situation it exists to avoid.
      expect(
        kPaletteDirectoryDelay,
        greaterThanOrEqualTo(const Duration(milliseconds: 300)),
      );
    });

    test('and still short enough that a user waiting does not give up', () {
      expect(kPaletteDirectoryDelay, lessThan(const Duration(seconds: 1)));
    });
  });

  group('a directory chunk becomes a row', () {
    testWidgets('a space is a chunk whose room_type is m.space',
        (tester) async {
      final List<PaletteResult> spaces = paletteDirectoryResults(
        <PublishedRoomsChunk>[chunk(roomId: '!s', roomType: 'm.space')],
        l10n,
      );
      expect(spaces.single.source, PaletteSource.space);
    });

    testWidgets('a missing room_type is a room, never a space', (tester) async {
      final List<PaletteResult> rooms = paletteDirectoryResults(
        <PublishedRoomsChunk>[chunk(roomId: '!r')],
        l10n,
      );
      expect(rooms.single.source, PaletteSource.room);
    });

    testWidgets('the title falls back name, alias, then room id',
        (tester) async {
      expect(
        paletteDirectoryResults(
          <PublishedRoomsChunk>[
            chunk(roomId: '!a', name: 'Named', alias: '#a:matrix.org'),
          ],
          l10n,
        ).single.title,
        'Named',
      );
      expect(
        paletteDirectoryResults(
          <PublishedRoomsChunk>[chunk(roomId: '!b', alias: '#b:matrix.org')],
          l10n,
        ).single.title,
        '#b:matrix.org',
      );
      expect(
        paletteDirectoryResults(
          <PublishedRoomsChunk>[chunk(roomId: '!c:matrix.org')],
          l10n,
        ).single.title,
        '!c:matrix.org',
      );
    });

    testWidgets('the alias and topic are searchable but not shown',
        (tester) async {
      final PaletteResult result = paletteDirectoryResults(
        <PublishedRoomsChunk>[
          chunk(
            roomId: '!d:matrix.org',
            name: 'Rust',
            alias: '#rust:matrix.org',
            topic: 'Systems programming',
          ),
        ],
        l10n,
      ).single;
      // A public room's topic is the field it uses to describe itself, so it is
      // frequently the only thing in the response that matches a subject.
      expect(result.keywords, contains('#rust:matrix.org'));
      expect(result.keywords, contains('Systems programming'));
      expect(result.subtitle, isNot(contains('Systems programming')));
    });

    testWidgets('an empty room id is dropped, not shown as a dead row',
        (tester) async {
      expect(
        paletteDirectoryResults(
          <PublishedRoomsChunk>[chunk(roomId: '')],
          l10n,
        ),
        isEmpty,
      );
    });

    testWidgets('directory rows sort by match quality, then by title',
        (tester) async {
      // Not against commands. A public room and a settings page are not
      // competitors, and interleaving them produces an order nobody can learn.
      final List<PaletteResult> rows = <PaletteResult>[
        for (final PaletteResult r in paletteDirectoryResults(
          <PublishedRoomsChunk>[
            chunk(roomId: '!a:matrix.org', name: 'Aaa general room'),
            chunk(roomId: '!b:matrix.org', name: 'General'),
          ],
          l10n,
        ))
          r.withScores(score: scoreResult(r, 'general')!, recency: 0),
      ];
      sortPaletteResults(rows);
      // "General" is an exact match; "Aaa general room" only has the phrase
      // inside it, which is a weaker tier no matter that it is shorter.
      expect(rows.first.title, 'General');
    });
  });

  group('the directory does not fire for a command', () {
    testWidgets('one settled query asks exactly once', (tester) async {
      final MockClient client = MockClient();
      final List<String> asked = <String>[];
      _stub(client, asked, <PublishedRoomsChunk>[chunk(name: 'General')]);
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      controller.onInputChanged('gen', l10n);

      // Well before the directory delay, the fast sources have gone and the
      // directory has not. This is the assertion that a zero delay would fail.
      await tester.pump(const Duration(milliseconds: 200));
      expect(asked, isEmpty);

      // Past the delay, once.
      await tester.pump(kPaletteDirectoryDelay);
      await tester.pump();
      expect(asked, <String>['gen']);
    });

    testWidgets('typing again before the delay cancels the first request',
        (tester) async {
      final MockClient client = MockClient();
      final List<String> asked = <String>[];
      _stub(client, asked, <PublishedRoomsChunk>[]);
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      // "gen" then "general" is one question asked twice. Firing the directory
      // twice would be two round trips to a stranger's homeserver for nothing.
      controller.onInputChanged('gen', l10n);
      await tester.pump(const Duration(milliseconds: 200));
      controller.onInputChanged('general', l10n);

      await tester.pump(kPaletteDirectoryDelay);
      await tester.pump();
      expect(asked, <String>['general']);
    });

    testWidgets('clearing the query never asks the directory', (tester) async {
      final MockClient client = MockClient();
      final List<String> asked = <String>[];
      _stub(client, asked, <PublishedRoomsChunk>[]);
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      controller.onInputChanged('gen', l10n);
      await tester.pump(const Duration(milliseconds: 200));
      controller.onInputChanged('', l10n);
      await tester.pump(kPaletteDirectoryDelay);
      await tester.pump();

      // Someone glancing at a command and clearing the box should not have
      // reached the homeserver's public directory at all.
      expect(asked, isEmpty);
      expect(controller.directoryAsked, isFalse);
    });

    testWidgets('a stale directory answer cannot land on a newer query',
        (tester) async {
      final MockClient client = MockClient();
      final List<Completer<QueryPublicRoomsResponse>> pending =
          <Completer<QueryPublicRoomsResponse>>[];
      when(() => client.queryPublicRooms(
            filter: any(named: 'filter'),
            limit: any(named: 'limit'),
          )).thenAnswer((Invocation invocation) {
        final Completer<QueryPublicRoomsResponse> completer =
            Completer<QueryPublicRoomsResponse>();
        pending.add(completer);
        return completer.future;
      });
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      controller.onInputChanged('old', l10n);
      await tester.pump(kPaletteDirectoryDelay);
      expect(pending, hasLength(1));

      controller.onInputChanged('new', l10n);
      await tester.pump(kPaletteDirectoryDelay);
      expect(pending, hasLength(2));

      // The first request answers last, which is the whole failure mode.
      pending[1]
          .complete(_response(<PublishedRoomsChunk>[chunk(name: 'Newest')]));
      await tester.pump();
      pending[0]
          .complete(_response(<PublishedRoomsChunk>[chunk(name: 'Stale')]));
      await tester.pump();

      final titles =
          controller.results.map((PaletteResult r) => r.title).toSet();
      expect(titles, contains('Newest'));
      expect(titles, isNot(contains('Stale')));
    });
  });

  group('the section boundary', () {
    testWidgets('is -1 before anything has come back', (tester) async {
      final MockClient client = MockClient();
      _stub(client, <String>[], <PublishedRoomsChunk>[]);
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      controller.onInputChanged('gen', l10n);
      await tester.pump(const Duration(milliseconds: 200));

      // A header at index 0 with nothing above it is a section containing
      // nothing, which is worse than no section.
      expect(controller.directoryStart, -1);

      // Let the directory timer finish so the test does not end with 250ms of
      // pending timer, which the binding reports as a leak.
      await tester.pump(kPaletteDirectoryDelay);
      await tester.pump();
    });

    testWidgets('is where the public rooms begin once they arrive',
        (tester) async {
      final MockClient client = MockClient();
      _stub(client, <String>[], <PublishedRoomsChunk>[
        chunk(roomId: '!pub1:matrix.org', name: 'General one'),
        chunk(roomId: '!pub2:matrix.org', name: 'General two'),
      ]);
      // A joined room with the same name, so there is a ranked row above the
      // boundary as well as public rooms below it. Without one the boundary
      // would be at 0 and the test would pass for the wrong reason.
      final MockRoom joined = _room('!joined:matrix.org', 'General mine');
      when(() => client.rooms).thenReturn(<Room>[joined]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      controller.onInputChanged('general', l10n);
      await tester.pump(kPaletteDirectoryDelay);
      await tester.pump();

      final int boundary = controller.directoryStart;
      expect(boundary, greaterThan(0));
      expect(
        controller.results.skip(boundary).every((PaletteResult r) =>
            r.source == PaletteSource.room || r.source == PaletteSource.space),
        isTrue,
        reason: 'only public rooms belong after the boundary',
      );
      expect(controller.results.take(boundary), isNotEmpty);
      // The joined room is the user's own and belongs above the boundary even
      // though the public one may match the query better.
      expect(
        controller.results.take(boundary).map((PaletteResult r) => r.title),
        contains('General mine'),
      );
    });

    testWidgets('and the keyboard cursor can cross it', (tester) async {
      final MockClient client = MockClient();
      _stub(client, <String>[], <PublishedRoomsChunk>[
        chunk(roomId: '!pub:matrix.org', name: 'General public'),
      ]);
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.userID).thenReturn('@me:matrix.org');

      final PaletteController controller = _controller(client);
      // Disposed inside the body rather than in ddTearDown, because the
      // directory timer is still pending at this point on purpose and the
      // binding's invariant check runs before tearDowns. Leaving 450ms of
      // pending timer would fail every one of these tests for the wrong reason.
      addTearDown(controller.dispose);

      controller.onInputChanged('general', l10n);
      await tester.pump(kPaletteDirectoryDelay);
      await tester.pump();

      // One shared list is the whole point of a unified surface: a section the
      // arrow keys cannot enter is a section the user has to reach by mouse.
      final int boundary = controller.directoryStart;
      controller.selectEdge(last: true);
      expect(controller.selectedIndex, controller.results.length - 1);
      expect(controller.selectedIndex, greaterThan(boundary - 1));
    });
  });
}

/// Answers directory requests immediately and records the query.
void _stub(
  MockClient client,
  List<String> asked,
  List<PublishedRoomsChunk> chunks,
) {
  when(() => client.queryPublicRooms(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
      )).thenAnswer((Invocation invocation) async {
    asked.add(
      (invocation.namedArguments[#filter] as PublicRoomQueryFilter?)
              ?.genericSearchTerm ??
          '',
    );
    return _response(chunks);
  });
}

QueryPublicRoomsResponse _response(List<PublishedRoomsChunk> chunks) =>
    QueryPublicRoomsResponse(chunk: chunks);

PaletteController _controller(MockClient client) => PaletteController(
      client: client,
      log: MockLogger(),
      sources: const PaletteSources(),
      debounce: const Duration(milliseconds: 140),
    );

/// A joined room, stubbed just enough for the source converter.
///
/// `MockRoom extends Mock implements Room`, so `getLocalizedDisplayname` is
/// intercepted and returns null unless it is stubbed directly. The real
/// implementation is never reached, so stubbing `name` alone fails with
/// `type 'Null' is not a subtype of type 'String'` raised from inside the SDK,
/// which is a confusing way to find out which stub was missing.
MockRoom _room(String roomId, String name) {
  final MockRoom room = MockRoom();
  when(() => room.id).thenReturn(roomId);
  when(() => room.name).thenReturn(name);
  when(() => room.getLocalizedDisplayname()).thenReturn(name);
  when(() => room.canonicalAlias).thenReturn('');
  when(() => room.topic).thenReturn('');
  when(() => room.isSpace).thenReturn(false);
  return room;
}
