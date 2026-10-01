// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/room_list_filter.dart';

import '../helpers/widget_test_utils.dart';

Widget _wrap(Widget child, {NavigationState? nav}) {
  return wrapWithProviders(
    navigationState: nav,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 300, child: child),
        ),
      ),
    ),
  );
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RoomListFilter', () {
    // The reason this is a control and not two rows. "Home" and "All" were
    // navigation words for what is a filter, so people clicked the one that
    // sounded like a destination and got a narrower list than they expected.
    testWidgets('is labelled by what the list contains, not by where it goes',
        (tester) async {
      await tester.pumpWidget(_wrap(const RoomListFilter()));
      await tester.pump();

      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('All rooms'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('All'), findsNothing);
    });

    testWidgets('exposes both segments as a filter to a screen reader',
        (tester) async {
      await tester.pumpWidget(_wrap(const RoomListFilter()));
      await tester.pump();

      // A screen reader user cannot see the track, so the name has to say
      // what the control does rather than label the two halves.
      expect(
        find.bySemanticsLabel('Filter rooms'),
        findsOneWidget,
      );
    });

    testWidgets('the whole slot is clickable, not just the words in it',
        (tester) async {
      // The bug this pins. A `Row` defaults to `CrossAxisAlignment.center`,
      // so it handed its children loose height constraints and each
      // segment sized to its content, about 18px inside a 28px slot. The
      // slot looked tappable and the top and bottom of it were dead space.
      //
      // Asserted against the label's own box rather than a hard-coded
      // number, so this keeps holding if the type scale moves.
      await tester.pumpWidget(_wrap(const RoomListFilter()));
      await tester.pump();

      final track = tester.getRect(find.byType(RoomListFilter));
      final label = tester.getRect(find.text('Friends'));
      Rect targetFor(String text) => tester.getRect(
            find.ancestor(of: find.text(text), matching: find.byType(InkWell)),
          );
      final tapTarget = targetFor('Friends');

      // Every pixel of the segment's height is the target, not the label's.
      expect(tapTarget.height, greaterThan(label.height * 1.5));
      // The target's top and bottom are the slot's, so there is no dead
      // band above or below the label.
      expect(tapTarget.top, lessThan(label.top));
      expect(tapTarget.bottom, greaterThan(label.bottom));

      // Together the two segments fill the track, inset only by the track's
      // own 3px padding and the control's 10px page margin. This also
      // catches the width half of the original bug, where the layout
      // subtracted the inset a second time and left a dead strip down the
      // far edge.
      const trackInset = 10 * 2 + 3 * 2;
      expect(tapTarget.width + targetFor('All rooms').width,
          closeTo(track.width - trackInset, 1.0));
      // And the two are equal, so the divider between them is centred.
      expect(tapTarget.width, closeTo(targetFor('All rooms').width, 1.0));
    });

    testWidgets('a tap at the very top of the slot still selects it',
        (tester) async {
      // The behavioural half of the same claim. The dead band used to eat
      // taps silently rather than visibly missing, which is worse than a
      // target that is honestly small.
      //
      // Anchored to the pill rather than the label, because the pill is
      // `AnimatedPositioned` with `top: 0, bottom: 0` and so fills the slot
      // exactly. A couple of pixels above the *label* is still inside the
      // old 18px target, so that version of this test passed against the
      // bug it was written for.
      final nav = NavigationState();
      await tester.pumpWidget(_wrap(const RoomListFilter(), nav: nav));
      await tester.pump();

      final pill = tester.getRect(find.byKey(const ValueKey('filter-pill')));
      // The pill is on the *selected* segment, and "All rooms" is selected
      // by default, so its x is the second half. Take y from the pill,
      // which fills the slot's height, and x from the first segment.
      final friends = tester.getRect(
        find.ancestor(of: find.text('Friends'), matching: find.byType(InkWell)),
      );

      await tester.tapAt(Offset(friends.center.dx, pill.top + 1.5));
      await tester.pump();

      expect(nav.isHome, isTrue);
    });

    testWidgets('tapping a segment selects it', (tester) async {
      final nav = NavigationState();
      await tester.pumpWidget(_wrap(const RoomListFilter(), nav: nav));
      await tester.pump();

      // The default is every room.
      expect(nav.isAll, isTrue);
      expect(nav.isHome, isFalse);

      await tester.tap(find.text('Friends'));
      await tester.pump();
      expect(nav.isHome, isTrue);

      await tester.tap(find.text('All rooms'));
      await tester.pump();
      expect(nav.isAll, isTrue);
    });

    testWidgets('the two segments are the same width', (tester) async {
      // The labels are different lengths, and an uneven split with an
      // ellipsised "All rooms" would be the obvious failure.
      await tester.pumpWidget(_wrap(const RoomListFilter()));
      await tester.pump();

      final friends = tester.getSize(find.text('Friends'));
      final all = tester.getSize(find.text('All rooms'));
      expect(all.height, closeTo(friends.height, 0.01));
    });

    testWidgets('the lit half moves rather than the two buttons lighting up',
        (tester) async {
      // Two lit buttons read as tabs. One pill that moves between two homes
      // reads as a single control changing state, which is the part of the
      // filter idiom that carries the meaning.
      final nav = NavigationState();
      await tester.pumpWidget(_wrap(const RoomListFilter(), nav: nav));
      await tester.pump();

      double pillLeft() => tester
          .getTopLeft(find.byKey(const ValueKey('filter-pill')))
          .dx;

      final onAllRooms = pillLeft();

      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();

      final onFriends = pillLeft();
      // It moved, and it moved right, because Friends is the first segment.
      expect(onFriends, isNot(onAllRooms));
      expect(onFriends, lessThan(onAllRooms));
    });
  });
}
