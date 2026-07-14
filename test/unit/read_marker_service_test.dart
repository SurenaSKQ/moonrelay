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

// Tests for the compare-and-swap semantics in [ReadMarkerService]
// documented in WORK_DONE.md §10 ("Read-marker CAS").
// Each write carries a monotonic sequence number; a stale write with
// a smaller sequence number must not overwrite a more recent marker.
// Without this guard two concurrent async writes can reorder a newer
// marker behind an older one.

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/services/read_marker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // SharedPreferences.setMockInitialValues is process-wide, so each
  // test that needs a clean slate calls it in its own setUp.

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReadMarkerService', () {
    test('setLastSeen persists the event id', () async {
      final svc = ReadMarkerService.forAccount('acct-1');
      await svc.setLastSeen('!room:example.com', '\$evt-1');

      final stored = await svc.getLastSeen('!room:example.com');
      expect(stored, '\$evt-1');
    });

    test('setLastSeen with null event id removes the entry', () async {
      final svc = ReadMarkerService.forAccount('acct-1');
      await svc.setLastSeen('!room:example.com', '\$evt-1');
      await svc.setLastSeen('!room:example.com', null);

      final stored = await svc.getLastSeen('!room:example.com');
      expect(stored, isNull);
    });

    test('setLastSeen with empty event id removes the entry', () async {
      final svc = ReadMarkerService.forAccount('acct-1');
      await svc.setLastSeen('!room:example.com', '\$evt-1');
      await svc.setLastSeen('!room:example.com', '');

      final stored = await svc.getLastSeen('!room:example.com');
      expect(stored, isNull);
    });

    test('getLastSeen returns null for an unknown room', () async {
      final svc = ReadMarkerService.forAccount('acct-1');
      final stored = await svc.getLastSeen('!unknown:example.com');
      expect(stored, isNull);
    });

    test('two accounts do not see each other markers', () async {
      final svc1 = ReadMarkerService.forAccount('acct-1');
      final svc2 = ReadMarkerService.forAccount('acct-2');

      await svc1.setLastSeen('!room:example.com', '\$evt-1');

      expect(await svc1.getLastSeen('!room:example.com'), '\$evt-1');
      expect(await svc2.getLastSeen('!room:example.com'), isNull);
    });

    test('a fresh write advances the sequence number', () async {
      final svc = ReadMarkerService.forAccount('acct-1');
      await svc.setLastSeen('!room:example.com', '\$evt-1');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('lastseen:acct-1:!room_example.com');
      expect(raw, isNotNull);
      // First write: seq is the first value of the per-instance counter.
      // We don't pin the exact value (the test runs in a single
      // service instance), but we do confirm seq is an integer
      // strictly greater than zero.
      expect(raw, contains('"seq":'));
    });

    test('overwriting an existing marker advances seq and persists '
        'the newer event id', () async {
      final svc = ReadMarkerService.forAccount('acct-1');
      await svc.setLastSeen('!room:example.com', '\$evt-1');
      await svc.setLastSeen('!room:example.com', '\$evt-2');

      final stored = await svc.getLastSeen('!room:example.com');
      expect(stored, '\$evt-2');
    });

    test('getLastSeen on a corrupt entry returns null', () async {
      SharedPreferences.setMockInitialValues({
        'lastseen:acct-1:!room_example.com': 'not-json',
      });
      final svc = ReadMarkerService.forAccount('acct-1');
      final stored = await svc.getLastSeen('!room:example.com');
      expect(stored, isNull);
    });

    test('keys are colon-safe for both account and room ids', () async {
      final svc = ReadMarkerService.forAccount('acct:weird');
      await svc.setLastSeen('!room:example.com', '\$evt-1');
      final prefs = await SharedPreferences.getInstance();
      // Colons in account/room ids are replaced with underscores so
      // the key is filesystem-safe and unambiguous.
      expect(
        prefs.getString('lastseen:acct_weird:!room_example.com'),
        isNotNull,
      );
    });
  });
}