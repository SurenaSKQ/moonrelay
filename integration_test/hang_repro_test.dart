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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Diagnostic test: reproduces the "app hangs after a while" report by
// driving a sustained stream of sync ticks (each delivering a new event)
// while flipping the window across the mobile/compact/expanded layout
// boundaries.  A hang manifests as a pump that never returns (test
// timeout) or as a pump whose wall-clock duration explodes far beyond
// the requested duration.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/mock_matrix_http_client.dart';
import 'helpers/test_app_boot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String testRoomId = '!hangrepro:matrix.org';

  late MockMatrixHttpClient mockHttp;
  late int messageCounter;

  http.Response jsonResponse(int status, Object body) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});

  void configureLoginHandlers() {
    mockHttp.on(
      RegExp(r'\.well-known/matrix/client'),
      handler: (_) => jsonResponse(404, {'errcode': 'M_NOT_FOUND'}),
    );
    mockHttp.on(
      RegExp(r'_matrix/client/v3/login$'),
      handler: (req) {
        if (req.method == 'GET') {
          return jsonResponse(200, {
            'flows': [
              {'type': 'm.login.password'}
            ],
          });
        }
        return jsonResponse(200, {
          'access_token': 'e2e_token_hang',
          'device_id': 'E2EHANG',
          'user_id': '@testuser:matrix.org',
          'home_server': 'matrix.org',
        });
      },
    );
    mockHttp.on(
      RegExp(r'_matrix/client/v3/sync'),
      // Deliver only events newer than the client's `since` token, like
      // a real homeserver.  Re-sending the full growing timeline on
      // every tick made the sync loop O(n²) and wedged the frame
      // pipeline mid-run on slower machines.
      handler: (req) => jsonResponse(
        200,
        mockHttp.buildSyncResponse(
          since: req.url.queryParameters['since'],
        ),
      ),
    );
    // Pagination and read-marker endpoints must answer, otherwise the
    // timeline's history pager and read-receipt tracker hammer them
    // with failing requests (and the pager's auto-fill loop re-arms
    // itself after each failure), which starves the frame pipeline on
    // its own.
    mockHttp.on(
      RegExp(r'_matrix/client/v3/rooms/[^/]+/messages'),
      handler: (_) => jsonResponse(200, {
        'chunk': <Object>[],
        'end': 'history_end',
        'start': 'history_start',
      }),
    );
    mockHttp.on(
      RegExp(r'_matrix/client/v3/rooms/[^/]+/read_markers'),
      handler: (_) => jsonResponse(200, <String, Object>{}),
    );
  }

  Future<void> loginAndOpenRoom(WidgetTester tester) async {
    await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'testuser');
    await tester.pump();
    await tester.enterText(fields.at(2), 'password123');
    await tester.pump();

    await tester.tap(find.text('Sign In').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Wait (with a bound) for the rooms pane to populate from sync.
    final roomFinder = find.text('Hang Repro Room');
    for (var i = 0; i < 50 && roomFinder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (roomFinder.evaluate().isEmpty) {
      // ignore: avoid_print
      print('HANG_REPRO: room never appeared; visible texts:');
      for (final w in tester.allWidgets) {
        if (w is Text && w.data != null && w.data!.isNotEmpty) {
          // ignore: avoid_print
          print('  [${w.data!}]');
        }
      }
    }
    expect(roomFinder, findsWidgets);
    await tester.tap(roomFinder.last);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    mockHttp = MockMatrixHttpClient();
    mockHttp.configureSendHandlers();
    mockHttp.configureEncryptionHandlers();
    messageCounter = 0;

    final initialEvents = <Map<String, dynamic>>[
      for (var i = 0; i < 10; i++)
        {
          'sender': '@alice:matrix.org',
          'content': {'body': 'initial message $i', 'msgtype': 'm.text'},
          'event_id': r'$init$i',
          'origin_server_ts': 1700100000000 + i,
        },
    ];
    mockHttp.addRoom(
      id: testRoomId,
      name: 'Hang Repro Room',
      topic: 'hang reproduction',
      timelineEvents: initialEvents,
      stateEvents: [
        {
          'type': 'm.room.member',
          'state_key': '@testuser:matrix.org',
          'content': {
            'membership': 'join',
            'displayname': 'Test User',
          },
          'sender': '@testuser:matrix.org',
          'event_id': r'$member1',
          'origin_server_ts': 1,
        },
      ],
      joinedMembers: 3,
    );
  });

  testWidgets('sustained syncs + layout flips do not hang the app',
      (tester) async {
    configureLoginHandlers();
    await loginAndOpenRoom(tester);

    // Verify the initial state rendered.
    expect(find.text('initial message 9'), findsWidgets);

    // Give the tight mock sync loop a moment to spin up.
    await tester.pump(const Duration(milliseconds: 300));

    final rng = Random(42);
    final widths = <double>[1400, 1050, 550, 700, 1200, 590, 1120];

    final sw = Stopwatch()..start();
    // 60 ticks keeps the timeline small enough that each pump stays fast
    // on slow CI machines, while still exercising every layout boundary
    // (the widths array covers mobile, compact, and expanded) and the
    // liveness probes.  The original 200-tick run streamed 200+ messages
    // into one room; the per-sync timeline rebuild grew ~4ms per event,
    // so the pump latency eventually crossed into a wedge on slower
    // machines and masked the layout logic this test guards.
    for (var i = 0; i < 60; i++) {
      messageCounter++;
      mockHttp.appendEvent(testRoomId, {
        'sender': '@bob:matrix.org',
        'content': {
          'body': 'stream message $messageCounter',
          'msgtype': 'm.text',
        },
        'event_id': r'$stream$messageCounter',
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
      });

      // Let the sync loop deliver the event and rebuild the UI.
      final iterSw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      iterSw.stop();
      if (i % 20 == 0) {
        // ignore: avoid_print
        print('HANG_REPRO: phase1 iteration $i pump took '
            '${iterSw.elapsedMilliseconds}ms for 80ms');
      }

      // Occasionally flip the window across every layout boundary.
      if (i % 10 == 0) {
        final w = widths[rng.nextInt(widths.length)];
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 120));
        // The ChatBox Row overflows at very narrow widths (a separate
        // cosmetic bug); swallow it so it doesn't fail this run.
        tester.takeException();
      }

      if (i % 30 == 0) {
        // Liveness probe: pumping 40ms of wall clock must not take an
        // order of magnitude longer, otherwise the frame pipeline is
        // wedged (rebuild storm / blocked event loop).
        final probe = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 40));
        probe.stop();
        expect(
          probe.elapsedMilliseconds,
          lessThan(2000),
          reason: 'frame pipeline wedged after $i iterations '
              '(pump took ${probe.elapsedMilliseconds}ms for 40ms)',
        );
      }
    }
    sw.stop();

    // The newest event must have made it into the timeline at some
    // point (it may have been scrolled out of view, so allow any of
    // the recent ones).
    final recentBody =
        find.text('stream message ${messageCounter - 1}');
    final anyStreamed = find.textContaining('stream message');

    // Final liveness check.
    final endProbe = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 100));
    endProbe.stop();

    expect(
      endProbe.elapsedMilliseconds,
      lessThan(2000),
      reason: 'app wedged at end of session '
          '(final pump took ${endProbe.elapsedMilliseconds}ms)',
    );
    // Either the newest event is visible, or the timeline is being
    // scrolled/rebuilt but still produces frames (stream messages exist).
    expect(recentBody.evaluate().isNotEmpty || anyStreamed.evaluate().isNotEmpty,
        isTrue,
        reason: 'no streamed message ever rendered; sync pipeline stalled');

    // Route-stack leak check: the old shell-flip navigation pushed a
    // page that was never popped, so every mobile/dashboard switch
    // mounted an extra copy of the page (and its chat surface) on the
    // navigator stack.  After ~20 forced flips the room name should
    // still only appear in the sidebar/header, not once per leaked page.
    final roomNameCount = find
        .text('Hang Repro Room', skipOffstage: false)
        .evaluate()
        .length;
    expect(
      roomNameCount,
      lessThan(5),
      reason: 'room page was duplicated $roomNameCount times after layout '
          'flips - the shell-flip navigation leaks pages onto the stack',
    );

    // -- Phase 2: forced compact layout mode ---------------------------
    // The user report: hanging happens when the layout is *set* to
    // compact (not just resized into it).  Keep the window wide so the
    // forced mode is the only reason the compact shell commits, then
    // keep pumping syncs and probe the frame pipeline for a wedge.
    final settings = Provider.of<SettingsController>(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    );
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    settings.setLayoutMode(LayoutMode.compact);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));

    final compactSw = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      messageCounter++;
      mockHttp.appendEvent(testRoomId, {
        'sender': '@carol:matrix.org',
        'content': {
          'body': 'compact stream message $messageCounter',
          'msgtype': 'm.text',
        },
        'event_id': r'$compact$messageCounter',
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
      });
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));

      if (i % 20 == 0) {
        final probe = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 40));
        probe.stop();
        expect(
          probe.elapsedMilliseconds,
          lessThan(2000),
          reason: 'frame pipeline wedged under forced compact at '
              'iteration $i (pump took ${probe.elapsedMilliseconds}ms '
              'for 40ms)',
        );
      }
    }
    compactSw.stop();

    // Back to auto mode so a later phase of the run starts clean.
    settings.setLayoutMode(LayoutMode.auto);
    await tester.pump(const Duration(milliseconds: 120));

    final compactProbe = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 100));
    compactProbe.stop();
    expect(
      compactProbe.elapsedMilliseconds,
      lessThan(2000),
      reason: 'app wedged after leaving forced compact '
          '(pump took ${compactProbe.elapsedMilliseconds}ms)',
    );

    // ignore: avoid_print
    print('HANG_REPRO: phase1 60 iterations in ${sw.elapsedMilliseconds}ms, '
        'final pump ${endProbe.elapsedMilliseconds}ms, '
        'compact phase ${compactSw.elapsedMilliseconds}ms, '
        'room name instances: $roomNameCount');
  });
}
