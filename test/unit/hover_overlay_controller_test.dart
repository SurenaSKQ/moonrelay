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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/hover_overlay.dart';

void main() {
  group('HoverOverlayController (geometry-driven)', () {
    test('registerRect then hitTest inside the rect sets hoveredKey', () {
      final controller = HoverOverlayController();
      final key = GlobalKey();
      final rect = const Rect.fromLTWH(0, 0, 100, 30);
      controller.registerRect(key, rect);
      controller.hitTest(const Offset(50, 15));
      expect(controller.hoveredKey.value, same(key));
      expect(controller.toolbarVisible.value, isTrue);
    });

    test('hitTest outside any rect schedules a debounced hide', () async {
      final controller = HoverOverlayController(
        hideDebounce: const Duration(milliseconds: 20),
      );
      final key = GlobalKey();
      controller.registerRect(key, const Rect.fromLTWH(0, 0, 100, 30));
      controller.hitTest(const Offset(50, 15));
      expect(controller.hoveredKey.value, same(key));
      expect(controller.toolbarVisible.value, isTrue);

      // Cursor moves outside the rect -- the controller schedules a
      // debounced hide rather than clearing immediately, so a 2-row
      // drag doesn't toggle the toolbar off and back on.
      controller.hitTest(const Offset(500, 500));
      expect(controller.toolbarVisible.value, isTrue,
          reason: 'toolbar stays visible during debounce window');
      expect(controller.hoveredKey.value, isNull,
          reason: 'hovered key is cleared on miss');

      // After the debounce fires the toolbar hides.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(controller.toolbarVisible.value, isFalse);
    });

    test('re-entering within the debounce window keeps the toolbar up',
        () async {
      final controller = HoverOverlayController(
        hideDebounce: const Duration(milliseconds: 30),
      );
      final key = GlobalKey();
      final rect = const Rect.fromLTWH(0, 0, 100, 30);
      controller.registerRect(key, rect);

      controller.hitTest(const Offset(50, 15));
      expect(controller.hoveredKey.value, same(key));

      controller.hitTest(const Offset(500, 500));
      expect(controller.toolbarVisible.value, isTrue,
          reason: 'toolbar stays visible during debounce window');
      expect(controller.hoveredKey.value, isNull);

      // The cursor comes back to a different item's rect before the
      // debounce fires -- the controller must cancel the hide and
      // anchor to the new item.
      final key2 = GlobalKey();
      controller.registerRect(key2, const Rect.fromLTWH(0, 50, 100, 30));
      controller.hitTest(const Offset(50, 65));
      expect(controller.hoveredKey.value, same(key2));
      expect(controller.toolbarVisible.value, isTrue);

      // Wait for the debounce to expire to confirm the timer was
      // properly cancelled.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.toolbarVisible.value, isTrue,
          reason: 'cancelled debounce should not flip toolbarVisible');
    });

    test('unregisterRect clears the active key when the item goes away',
        () {
      final controller = HoverOverlayController();
      final key = GlobalKey();
      controller.registerRect(key, const Rect.fromLTWH(0, 0, 100, 30));
      controller.hitTest(const Offset(50, 15));
      expect(controller.hoveredKey.value, same(key));

      controller.unregisterRect(key);
      expect(controller.hoveredKey.value, isNull);
    });

    test('enterToolbar re-claims the active item even if hit-test lost it',
        () {
      final controller = HoverOverlayController();
      final key = GlobalKey();
      controller.registerRect(key, const Rect.fromLTWH(0, 0, 100, 30));
      controller.hitTest(const Offset(50, 15));
      expect(controller.hoveredKey.value, same(key));

      // The cursor briefly leaves the row (e.g. travels through
      // empty space).  The global hit-test clears hoveredKey but
      // schedules a hide.  The toolbar's own MouseRegion then
      // re-asserts via enterToolbar, which cancels the hide and
      // pins hoveredKey back to the toolbar's item.
      controller.hitTest(const Offset(500, 500));
      controller.enterToolbar(key);
      expect(controller.hoveredKey.value, same(key));
      expect(controller.toolbarVisible.value, isTrue);
    });

    test('scheduleToolbarHide fires after the debounce window', () async {
      final controller = HoverOverlayController(
        hideDebounce: const Duration(milliseconds: 20),
      );
      final key = GlobalKey();
      controller.registerRect(key, const Rect.fromLTWH(0, 0, 100, 30));
      controller.hitTest(const Offset(50, 15));
      expect(controller.toolbarVisible.value, isTrue);

      controller.scheduleToolbarHide();
      expect(controller.toolbarVisible.value, isTrue,
          reason: 'hide is debounced');

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(controller.toolbarVisible.value, isFalse);
      expect(controller.hoveredKey.value, isNull);
    });

    test('cancelHide undoes a scheduled hide', () async {
      final controller = HoverOverlayController(
        hideDebounce: const Duration(milliseconds: 20),
      );
      final key = GlobalKey();
      controller.registerRect(key, const Rect.fromLTWH(0, 0, 100, 30));
      controller.hitTest(const Offset(50, 15));

      controller.scheduleToolbarHide();
      controller.cancelHide();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(controller.toolbarVisible.value, isTrue);
    });
  });

  group('HoverTargetEntry equality', () {
    test('entries with the same key compare equal', () {
      final key = GlobalKey();
      final a = HoverTargetEntry(
        key: key,
        event: null,
        room: null,
        timeline: null,
        onReply: () {},
        onForward: null,
        onThread: null,
        onJumpToEvent: null,
      );
      final b = HoverTargetEntry(
        key: key,
        event: null,
        room: null,
        timeline: null,
        onReply: () {},
        onForward: null,
        onThread: null,
        onJumpToEvent: null,
      );
      expect(a, equals(b));
    });

    test('entries with different keys do not compare equal', () {
      final a = HoverTargetEntry(
        key: GlobalKey(),
        event: null,
        room: null,
        timeline: null,
        onReply: null,
        onForward: null,
        onThread: null,
        onJumpToEvent: null,
      );
      final b = HoverTargetEntry(
        key: GlobalKey(),
        event: null,
        room: null,
        timeline: null,
        onReply: null,
        onForward: null,
        onThread: null,
        onJumpToEvent: null,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
