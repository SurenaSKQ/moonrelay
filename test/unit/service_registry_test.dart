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

// Tests for the ordered shutdown registry documented in
// WORK_DONE.md §10 ("Ordered shutdown"). Services are torn down in
// reverse registration order so dependents are disposed before
// their dependencies. Failures from one service must not block later
// ones.

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/service_registry.dart';

import '../helpers/mocks.dart';

void main() {
  group('ServiceRegistry', () {
    test('disposes services in reverse registration order', () async {
      final order = <String>[];
      final registry = ServiceRegistry();
      registry.register('A', disposer: () => order.add('A'));
      registry.register('B', disposer: () => order.add('B'));
      registry.register('C', disposer: () => order.add('C'));

      await registry.shutdownAll(MockLogger());

      expect(order, ['C', 'B', 'A']);
    });

    test('continues shutdown even when one disposer throws', () async {
      final order = <String>[];
      final registry = ServiceRegistry();
      registry.register('A', disposer: () => order.add('A'));
      registry.register(
        'B',
        disposer: () {
          order.add('B');
          throw StateError('B failed');
        },
      );
      registry.register('C', disposer: () => order.add('C'));

      // Must not throw and must still run A after B fails.
      await registry.shutdownAll(MockLogger());

      // C runs first (LIFO), then B (which throws), then A.
      expect(order, ['C', 'B', 'A']);
    });

    test('clears entries after shutdown so a second call is a no-op',
        () async {
      final order = <String>[];
      final registry = ServiceRegistry();
      registry.register('A', disposer: () => order.add('A'));

      await registry.shutdownAll(MockLogger());
      expect(order, ['A']);

      // Second shutdown: nothing was registered since the first
      // call, so the order list is unchanged.
      await registry.shutdownAll(MockLogger());
      expect(order, ['A']);
    });

    test('accepts async disposers and awaits them in order', () async {
      final order = <String>[];
      final registry = ServiceRegistry();
      registry.register(
        'slow',
        disposer: () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          order.add('slow');
        },
      );
      registry.register(
        'fast',
        disposer: () {
          order.add('fast');
          return null;
        },
      );

      final sw = Stopwatch()..start();
      await registry.shutdownAll(MockLogger());
      sw.stop();

      // fast runs first (LIFO), then slow. The total should be at
      // least the slow disposer duration because we awaited it.
      expect(order, ['fast', 'slow']);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(5));
    });

    test('sync disposer returning void is awaited too', () async {
      final order = <String>[];
      final registry = ServiceRegistry();
      registry.register(
        'sync',
        disposer: () {
          order.add('sync');
        },
      );

      await registry.shutdownAll(MockLogger());
      expect(order, ['sync']);
    });

    test('empty registry shutdown is a no-op', () async {
      final registry = ServiceRegistry();
      // Must not throw.
      await registry.shutdownAll(MockLogger());
    });

    test('the service instance is stored only for log attribution '
        '(no behavioural dependency)', () async {
      final order = <String>[];
      final registry = ServiceRegistry();
      // The "service" object is just a token; the registry does
      // not invoke it. The disposer closure is what runs.
      final tokenA = Object();
      registry.register(
        tokenA,
        disposer: () => order.add('a'),
      );
      await registry.shutdownAll(MockLogger());
      expect(order, ['a']);
    });
  });
}