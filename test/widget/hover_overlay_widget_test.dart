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
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/hover_item.dart';
import 'package:moonrelay/src/chat/hover_overlay.dart';

import '../helpers/mocks.dart';

/// Pin tests for the hoverbar geometry probe.
///
/// ## What broke before
///
/// An earlier iteration inherited [ChangeNotifier] on
/// [HoverOverlayController] and used an [InheritedNotifier] for
/// [HoverScope].  An item calling `registerRect` mid-build caused
/// the controller to notify, which marked the [InheritedNotifier]'s
/// dependents dirty, which Flutter then refused to mark because
/// the framework was already in the middle of a build:
///
///     setState() or markNeedsBuild() called during build.
///
/// The fix is to keep state internal and only notify *consumers*
/// (the toolbar) via the two [ValueNotifier]s on the controller.
/// Items register geometry through plain method calls; the
/// controller does not need to fire a build for them.
///
/// These tests pin down the contract: [HoverOverlayController] is
/// no longer a [ChangeNotifier], [HoverScope] is a plain
/// [InheritedWidget], and [HoverItem] can mount and call
/// `registerRect` / `registerEntry` / `unregisterRect` /
/// `unregisterEntry` without tripping the framework assertion.
void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(MockTimeline());
  });

  test('HoverOverlayController is not a ChangeNotifier', () {
    // The previous design had the controller extend ChangeNotifier
    // and feed into an [InheritedNotifier], which then tripped an
    // in-build markNeedsBuild when items registered mid-build.
    // Pin the contract: the controller must be a plain object so
    // that mutating it can't mark dependents dirty.
    final controller = HoverOverlayController();
    // [ChangeNotifier] is the type that exposes [notifyListeners]
    // as a public method (well, inherited; not relevant here).
    // Verify the controller doesn't extend it.
    expect(
      controller is ChangeNotifier,
      isFalse,
      reason:
          'controller must not extend ChangeNotifier; '
          'mutations must not fan out to InheritedNotifier dependents',
    );
    controller.dispose();
  });

  testWidgets(
    'HoverItem mounts and registers inside a HoverScope without '
    'throwing an in-build markNeedsBuild assertion',
    (tester) async {
      // Empty-event timeline that only registers an item.  We
      // stub the bare minimum so [HoverItem] / [HoverGeometryProbe]
      // can complete their mount path.
      final timeline = MockTimeline();
      final room = MockRoom();
      final event = MockEvent();
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => event.eventId).thenReturn('mock-1');
      when(() => event.body).thenReturn('');
      when(() => event.type).thenReturn('m.room.message');
      when(() => event.messageType).thenReturn('m.text');
      when(() => event.senderId).thenReturn('@user:example.org');
      when(() => event.status).thenReturn(EventStatus.synced);
      when(() => event.redacted).thenReturn(false);
      when(() => event.originServerTs).thenReturn(DateTime(2026));
      when(() => event.content).thenReturn(<String, dynamic>{});
      when(() => event.relationshipEventId).thenReturn(null);
      when(() => event.inReplyToEventId()).thenReturn(null);
      when(() => event.aggregatedEvents(any(), any()))
          .thenReturn(<Event>{});
      when(() => event.receipts).thenReturn(<Receipt>[]);

      final controller = HoverOverlayController();
      addTearDown(controller.dispose);
      final entryKey = GlobalKey();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HoverScope(
            controller: controller,
            child: HoverItem(
              itemKey: entryKey,
              event: event as dynamic,
              room: room as dynamic,
              timeline: timeline as dynamic,
              onReply: () {},
              child: const SizedBox(width: 100, height: 30),
            ),
          ),
        ),
      );

      // Pump enough frames to drive the post-frame geometry probe
      // callback.  If the in-build assertion regresses, this is
      // where it would fire.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // No exception should have been thrown during the mount.
      expect(tester.takeException(), isNull);

      // The geometry probe populated the controller's registry.
      expect(controller.itemRects.containsKey(entryKey), isTrue);
      expect(controller.itemEntries.containsKey(entryKey), isTrue);

      // A subsequent hit-test resolves to the item key.
      controller.hitTest(const Offset(50, 15));
      expect(controller.hoveredKey.value, same(entryKey));

      // Tearing down the item unregisters everything cleanly.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );
      await tester.pump();
      expect(controller.itemRects.containsKey(entryKey), isFalse);
      expect(controller.itemEntries.containsKey(entryKey), isFalse);
    },
  );

  testWidgets(
    'HoverScope descendants are not subscribed to controller state',
    (tester) async {
      // Sanity check the contract: a plain [InheritedWidget] read
      // via [dependOnInheritedWidgetOfExactType] does not subscribe
      // the calling widget to the controller.  The controller's
      // [ValueNotifier]s only fan out to their direct listeners
      // (the toolbar).
      final controller = HoverOverlayController();
      addTearDown(controller.dispose);
      var buildCount = 0;
      HoverOverlayController? seen;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HoverScope(
            controller: controller,
            child: Builder(
              builder: (context) {
                buildCount++;
                seen = HoverScope.maybeOf(context);
                return const SizedBox(width: 1, height: 1);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(seen, isNotNull);
      final initialBuilds = buildCount;
      expect(initialBuilds, greaterThanOrEqualTo(1));

      // Mutate the controller several times through every public
      // method.  None of these should rebuild the Builder.
      controller.hitTest(const Offset(50, 15));
      controller.scheduleToolbarHide();
      controller.cancelHide();
      controller.enterToolbar(GlobalKey());
      await tester.pump();

      expect(buildCount, initialBuilds,
          reason:
              'HoverScope must be a plain InheritedWidget; mutations '
              'on the controller must not trigger rebuilds of '
              'descendants that did not subscribe to its notifiers');
    },
  );
}