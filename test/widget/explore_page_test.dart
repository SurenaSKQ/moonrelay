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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/explore/explore_page.dart';
import 'package:moonrelay/src/screens/room_directory_search.dart';
import 'package:moonrelay/src/widgets/create_room_form/create_room_form.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// The explore page replaced three routes, and the two things worth protecting
/// are that the legacy paths still land somewhere sensible and that the room
/// and space filters actually separate.
///
/// The filter is the interesting one. Rooms and spaces come from the same
/// endpoint and are told apart by `room_type`, so "search for a space" is the
/// same request with a filter over the response. That is easy to write in a
/// way that compiles, does nothing, and looks correct.
void main() {
  late MockClient client;
  late MockLogger logger;

  setUp(() {
    client = MockClient();
    logger = MockLogger();

    when(() => client.userID).thenReturn('@me:matrix.org');
    when(() => client.rooms).thenReturn(<Room>[]);
    when(() => client.getRoomById(any())).thenReturn(null);
  });

  group('the room and space filters actually separate', () {
    PublishedRoomsChunk chunk(String roomId,
            {String? roomType, String? name}) =>
        PublishedRoomsChunk(
          roomId: roomId,
          guestCanJoin: true,
          worldReadable: false,
          numJoinedMembers: 3,
          roomType: roomType,
          name: name,
        );

    test('a space is a room whose room_type is m.space', () {
      expect(isSpaceChunk(chunk('!a', roomType: 'm.space')), isTrue);
      expect(isSpaceChunk(chunk('!b')), isFalse);
      expect(isSpaceChunk(chunk('!c', roomType: 'm.room')), isFalse);
    });

    test('a missing room_type is a room, never a space', () {
      // The failure this guards is quiet and total: guessing space from a null
      // would put every ordinary room in the spaces tab, and the tab would
      // show the user an app that could not find rooms.
      expect(isSpaceChunk(chunk('!a', roomType: null)), isFalse);
    });

    test('the rooms filter keeps rooms and drops spaces', () {
      final entries = <PublishedRoomsChunk>[
        chunk('!room'),
        chunk('!space', roomType: 'm.space'),
      ];
      expect(
        entries.where(DirectoryKindFilter.rooms.accepts).map((e) => e.roomId),
        <String>['!room'],
      );
    });

    test('the spaces filter keeps spaces and drops rooms', () {
      final entries = <PublishedRoomsChunk>[
        chunk('!room'),
        chunk('!space', roomType: 'm.space'),
      ];
      expect(
        entries.where(DirectoryKindFilter.spaces.accepts).map((e) => e.roomId),
        <String>['!space'],
      );
    });

    test('the everything filter keeps both, in order', () {
      final entries = <PublishedRoomsChunk>[
        chunk('!room'),
        chunk('!space', roomType: 'm.space'),
      ];
      expect(DirectoryKindFilter.all.accepts(entries.first), isTrue);
      expect(DirectoryKindFilter.all.accepts(entries.last), isTrue);
    });

    test('a filter cannot mutate the chunk it is given', () {
      // `accepts` is a tear-off used by `Iterable.where`, so it is called on
      // every element. It must not be allowed to hold state.
      final entry = chunk('!a');
      final filter = DirectoryKindFilter.rooms;
      expect(filter.accepts(entry), isTrue);
      expect(filter.accepts(entry), isTrue);
    });
  });

  group('the legacy paths still land somewhere', () {
    test('both create paths mean the create form', () {
      // `/main/newroom` and `/main/newspace` were one page behind a flag and
      // both of them meant "the create form". The space toggle inside the form
      // is the user's choice to make, not something a URL should decide.
      expect(ExploreMode.fromPath('/main/newroom'), ExploreMode.create);
      expect(ExploreMode.fromPath('/main/newspace'), ExploreMode.create);
    });

    test('everything else means the directory', () {
      expect(ExploreMode.fromPath('/main/addroom'), ExploreMode.find);
      expect(ExploreMode.fromPath('/main/explore'), ExploreMode.find);
      expect(ExploreMode.fromPath(null), ExploreMode.find);
    });
  });

  group('the page builds', () {
    Future<void> mount(WidgetTester tester,
        {ExploreMode mode = ExploreMode.find}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Logger>.value(value: logger),
            Provider<Client>.value(value: client),
          ],
          child: MaterialApp(
            theme: testMoonrelayTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExplorePage(initialMode: mode),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the find half shows the three filters', (tester) async {
      await mount(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ExplorePage)),
      )!;

      expect(find.text(l10n.exploreRooms), findsOneWidget);
      expect(find.text(l10n.exploreSpacesTab), findsOneWidget);
      expect(find.text(l10n.explorePeople), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the create half shows the create form', (tester) async {
      await mount(tester, mode: ExploreMode.create);
      // The form's own toggle is what chooses room versus space, which is why
      // this is one destination and not two.
      expect(find.byType(CreateRoomWidget), findsOneWidget);
      expect(find.byType(RoomDirectorySearch), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('joining by id is behind a control, not a tab', (tester) async {
      await mount(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ExplorePage)),
      )!;

      // The directory has its own search field; this is about the *second*
      // one, the id field, which is behind a control rather than beside the
      // search. It is the escape hatch for a room whose name you already know,
      // so it belongs after the search rather than competing with it.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.widgetWithText(TextField, l10n.roomIdOrAlias),
        findsNothing,
      );
      expect(find.text(l10n.exploreJoinById), findsOneWidget);
    });

    testWidgets('the page has a measure like the other pages', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester);

      final segmented =
          tester.getSize(find.byType(SegmentedButton<ExploreMode>));
      expect(
        segmented.width,
        lessThanOrEqualTo(MoonrelayInfoPage.maxContentWidth + 8),
        reason: 'was ${segmented.width} wide on an 1800px window',
      );
    });
  });
}
