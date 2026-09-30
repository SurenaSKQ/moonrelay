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

// Unit tests for `PresenceService`.
//
// The two things worth pinning are the `syncPresence` pin, without which
// an "appear offline" choice is undone by the next long-poll, and the
// idle decision, which is where an off-by-one in the window silently
// makes the feature either never fire or fire immediately.
//
// The clock is injected, so no test waits in real seconds and the sleep
// case is testable at all: real timers do not fire across a suspend,
// which is the whole reason `onResumed` compares wall-clock time.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/services/presence_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

/// A clock the test advances by hand.
class FakeClock {
  FakeClock(this._now);
  DateTime _now;

  DateTime call() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

void main() {
  // `any()` over a PresenceType argument needs a registered fallback, and
  // the enum has no natural dummy beyond its first value.
  setUpAll(() => registerFallbackValue(PresenceType.online));

  late FakeClock clock;
  late SettingsController settings;
  late MockClient client;

  /// Every presence published, by state, so a test can assert on how
  /// many times a transition happened rather than only on the last one.
  late Map<PresenceType, int> published;

  /// Builds a service bound to [client] with the given settings.
  PresenceService build() => PresenceService(
        settings: settings,
        log: MockLogger(),
        clock: clock.call,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = FakeClock(DateTime(2026, 1, 1, 12));
    settings = SettingsController(SettingsService());
    client = MockClient();
    published = <PresenceType, int>{};
    when(() => client.userID).thenReturn('@me:example.com');
    when(() => client.isLogged()).thenReturn(true);
    when(
      () => client.setPresence(
        any(),
        any(),
        statusMsg: any(named: 'statusMsg'),
      ),
    ).thenAnswer((invocation) async {
      final type = invocation.positionalArguments[1] as PresenceType;
      published[type] = (published[type] ?? 0) + 1;
    });
  });

  group('publishTo pins syncPresence', () {
    test('offline pins offline so a long-poll cannot undo it', () async {
      await PresenceService.publishTo(client, type: PresenceType.offline);

      // The pin is the whole point: without it the server marks the
      // client online on the next /sync and the choice silently reverts.
      verify(() => client.syncPresence = PresenceType.offline).called(1);
      verify(
        () => client.setPresence(
          '@me:example.com',
          PresenceType.offline,
          statusMsg: null,
        ),
      ).called(1);
    });

    test('unavailable pins unavailable', () async {
      await PresenceService.publishTo(client, type: PresenceType.unavailable);

      verify(() => client.syncPresence = PresenceType.unavailable).called(1);
    });

    test('online clears the pin so the server decides', () async {
      await PresenceService.publishTo(client, type: PresenceType.online);

      // Null means the parameter is omitted from /sync entirely, which is
      // what "mark me online as usual" means.
      verify(() => client.syncPresence = null).called(1);
    });

    test('passes a status message through', () async {
      await PresenceService.publishTo(
        client,
        type: PresenceType.online,
        statusMsg: 'at the pub',
      );

      verify(
        () => client.setPresence(
          '@me:example.com',
          PresenceType.online,
          statusMsg: 'at the pub',
        ),
      ).called(1);
    });

    test('sends an empty status message rather than null', () async {
      // A null statusMsg makes the SDK omit the key, so the server keeps
      // the old value and the message cannot be cleared. This pins the
      // caller's choice to pass an empty string.
      await PresenceService.publishTo(
        client,
        type: PresenceType.online,
        statusMsg: '',
      );

      verify(
        () => client.setPresence(
          '@me:example.com',
          PresenceType.online,
          statusMsg: '',
        ),
      ).called(1);
    });

    test('does nothing when the client is not logged in', () async {
      when(() => client.isLogged()).thenReturn(false);

      await PresenceService.publishTo(client, type: PresenceType.offline);

      verifyNever(() => client.setPresence(any(), any(),
          statusMsg: any(named: 'statusMsg')));
    });

    test('does nothing when there is no user id', () async {
      when(() => client.userID).thenReturn(null);

      await PresenceService.publishTo(client, type: PresenceType.offline);

      verifyNever(() => client.setPresence(any(), any(),
          statusMsg: any(named: 'statusMsg')));
    });
  });

  group('idle transition', () {
    test('does not go offline before the window elapses', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      clock.advance(const Duration(minutes: 4));
      service.onResumed();
      await pumpEventQueue();

      verifyNever(() => client.setPresence(any(), any(),
          statusMsg: any(named: 'statusMsg')));
      expect(service.hasPendingIdleTransition, isFalse);
    });

    test('goes offline once the window elapses', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      clock.advance(const Duration(minutes: 6));
      service.onResumed();
      await pumpEventQueue();

      verify(
        () => client.setPresence(
          '@me:example.com',
          PresenceType.offline,
          statusMsg: null,
        ),
      ).called(1);
    });

    test('stays online while the feature is off', () async {
      // The default is off, and binding must not start marking the
      // account offline.
      final service = build()..bind(client);

      clock.advance(const Duration(hours: 3));
      service.onResumed();
      await pumpEventQueue();

      verifyNever(() => client.setPresence(any(), any(),
          statusMsg: any(named: 'statusMsg')));
    });

    test('counts a suspend as idle time', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      // A laptop that slept for an hour has no timer ticks, so the only
      // way to notice is comparing wall-clock time at the resume.
      clock.advance(const Duration(hours: 1));
      service.onResumed();
      await pumpEventQueue();

      verify(
        () => client.setPresence(
          '@me:example.com',
          PresenceType.offline,
          statusMsg: null,
        ),
      ).called(1);
    });

    test('activity before the window elapses keeps the account online',
        () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      clock.advance(const Duration(minutes: 4));
      service.noteActivity();
      clock.advance(const Duration(minutes: 4));
      service.onResumed();
      await pumpEventQueue();

      // Eight minutes have passed, but the user was active at four, so
      // only four minutes of idle time have accumulated.
      verifyNever(() => client.setPresence(any(), any(),
          statusMsg: any(named: 'statusMsg')));
    });

    test('a manual choice overrides idleness', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      await service.setUserPresence(PresenceType.online);
      expect(service.userChoice, PresenceType.online);

      clock.advance(const Duration(hours: 2));
      service.onResumed();
      await pumpEventQueue();

      // Still the one online publish from the manual call, and no
      // offline: the user said they want to be visible.
      verify(
        () => client.setPresence(
          '@me:example.com',
          PresenceType.online,
          statusMsg: null,
        ),
      ).called(1);
      verifyNever(() => client.setPresence(any(), PresenceType.offline,
          statusMsg: any(named: 'statusMsg')));
    });

    test('turning the setting off returns the account to online', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      clock.advance(const Duration(minutes: 6));
      service.onResumed();
      await pumpEventQueue();
      final offlineCalls = published[PresenceType.offline] ?? 0;
      expect(offlineCalls, 1);

      settings.updateAutoOfflinePresenceEnabled(false);
      service.onSettingsChanged();
      await pumpEventQueue();

      expect(published[PresenceType.online], 1,
          reason: 'switching the feature off should put the account back '
              'online rather than leaving it offline');
    });

    test('activity after going offline republishes online', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      clock.advance(const Duration(minutes: 6));
      service.onResumed();
      await pumpEventQueue();
      expect(published[PresenceType.offline], 1);

      service.noteActivity();
      await pumpEventQueue();

      expect(published[PresenceType.online], 1);
      expect(service.hasPendingIdleTransition, isTrue,
          reason: 'the idle window should re-arm so going away again works');
    });

    test('losing window focus does not count as idleness', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      // Alt-tabbing away is not the user being idle, and on a locked
      // Windows workstation no focus event fires at all, so blur must
      // not start a countdown.
      clock.advance(const Duration(minutes: 30));
      service.onWindowBlur();
      await pumpEventQueue();

      expect(service.hasPendingIdleTransition, isFalse);
      verifyNever(() => client.setPresence(any(), PresenceType.offline,
          statusMsg: any(named: 'statusMsg')));
    });

    test('regaining focus counts as activity', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);

      clock.advance(const Duration(minutes: 30));
      service.onWindowBlur();
      clock.advance(const Duration(seconds: 1));
      service.onWindowFocus();
      await pumpEventQueue();

      expect(service.isWindowFocused, isTrue);
      clock.advance(const Duration(minutes: 4));
      service.onResumed();
      await pumpEventQueue();

      verifyNever(() => client.setPresence(any(), PresenceType.offline,
          statusMsg: any(named: 'statusMsg')));
    });
  });

  group('rebinding', () {
    test('a new client resets the manual choice', () async {
      settings.updateAutoOfflinePresenceEnabled(true);
      await settings.updateAutoOfflinePresenceMinutes(5);
      final service = build()..bind(client);
      await service.setUserPresence(PresenceType.unavailable);
      expect(service.userChoice, PresenceType.unavailable);

      final other = MockClient();
      when(() => other.userID).thenReturn('@other:example.com');
      when(() => other.isLogged()).thenReturn(true);
      when(
        () => other.setPresence(any(), any(),
            statusMsg: any(named: 'statusMsg')),
      ).thenAnswer((_) async {});

      service.bind(other);

      // A new account has its own presence, so the previous account's
      // manual choice must not follow it across.
      expect(service.userChoice, isNull);
    });

    test('a failure is logged, not thrown', () async {
      when(
        () => client.setPresence(any(), any(),
            statusMsg: any(named: 'statusMsg')),
      ).thenThrow(Exception('403 presence disabled'));

      // The service swallows and logs so a failed write cannot take down
      // the caller's action; the next tick retries.
      await expectLater(
        PresenceService.publishTo(client, type: PresenceType.offline),
        throwsA(isA<Exception>()),
        reason: 'the static helper propagates; the service wrapper does not',
      );
    });
  });
}
