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

// The register form, and the two things that made it a different form from the
// sign-in form next to it.
//
// Same material, different elevation. Register was a Material `Card` with
// `elevation: 2`, which renders from `kElevationToShadow`, a hardcoded black map
// no theme field reaches. So on the dark ramp the register form had no elevation
// at all while the sign-in form, a decorated `Container` with `t.shadowHigh`,
// had a real shadow. Two steps of one journey, two different materials.
//
// The consent row was a list tile. `CheckboxListTile` brings a 48px minimum
// height and its own padding, so the row asking the user to accept the
// homeserver's terms was a 56px band with a small box in it, and it did not
// match the gap rhythm of the four fields above it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/register_page_inclient.dart';
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_utils.dart';

class _RegisterClient extends Mock implements Client {
  @override
  String get userID => '@me:example.org';

  @override
  String get accessToken => 'token';

  @override
  String get deviceID => 'DEVICE';

  @override
  bool get encryptionEnabled => false;

  @override
  CachedStreamController<({String roomId, StrippedStateEvent state})>
      get onRoomState => CachedStreamController(null);

  @override
  CachedStreamController<SyncStatusUpdate> get onSyncStatus =>
      CachedStreamController<SyncStatusUpdate>(null);
}

void main() {
  late AppLocalizations l10n;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (MethodCall _) async => null,
    );
  });

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpRegister(WidgetTester tester) async {
    final _RegisterClient client = _RegisterClient();
    when(() => client.getRoomById(any())).thenReturn(null);
    when(() => client.rooms).thenReturn(<Room>[]);

    // A router, because the back control calls `context.pop()` and the footer
    // link calls `context.push()`.
    final GoRouter router = GoRouter(
      initialLocation: '/welcome/register',
      routes: <RouteBase>[
        GoRoute(
          path: '/welcome/register',
          builder: (BuildContext context, GoRouterState state) =>
              const RegisterInClientPage(),
        ),
        GoRoute(
          path: '/welcome/login',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('Sign In')),
        ),
      ],
    );

    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  group('the same material as the sign-in form', () {
    testWidgets('one card, the shared header, four shared fields', (
      tester,
    ) async {
      await pumpRegister(tester);

      expect(find.byType(AuthCard), findsOneWidget);
      expect(find.byType(AuthCardHeader), findsOneWidget);
      expect(find.byType(AuthField), findsNWidgets(4));
      expect(find.byType(AuthButton), findsOneWidget);
      // One FilledButton, one OutlinedButton, as on every other auth screen.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('the heading is the shared one, not a 20pt bold literal', (
      tester,
    ) async {
      await pumpRegister(tester);

      // Register used `fontSize: 20, FontWeight.bold` where sign-in used
      // `titleLarge`. Same journey, two headings.
      final Text heading = tester.widget<Text>(
        find.descendant(
          of: find.byType(AuthCardHeader),
          matching: find.text(l10n.registerTitle),
        ),
      );
      final TextStyle style = heading.style!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontSize, 18);
    });

    testWidgets('the error banner is the shared notice', (tester) async {
      await pumpRegister(tester);

      // It used `radiusSm` where the sign-in form's used `radiusMd`, for the
      // same message, on adjacent screens.
      expect(find.byType(AuthNotice), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), 'a');
      await tester.tap(find.byType(AuthButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AuthNotice), findsOneWidget);
    });
  });

  group('the fields ask to be filled', () {
    testWidgets('three of the four carry autofill hints', (tester) async {
      await pumpRegister(tester);

      final List<Iterable<String>?> hints = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((TextField f) => f.autofillHints)
          .toList();

      expect(hints[0], const <String>[AutofillHints.url]);
      expect(hints[1], const <String>[AutofillHints.newUsername]);
      expect(hints[2], const <String>[AutofillHints.newPassword]);
    });

    testWidgets('the confirmation field deliberately has none', (tester) async {
      // A password manager filling the confirmation field would defeat the one
      // thing the confirmation field is for, so it must not ask to be filled.
      await pumpRegister(tester);

      final List<TextField> fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[3].autofillHints, isNull);
    });
  });

  group('the password reveal', () {
    testWidgets('toggles, and says what it does', (tester) async {
      await pumpRegister(tester);

      final List<TextField> fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[2].obscureText, isTrue);
      expect(find.byTooltip(l10n.showPassword, skipOffstage: false),
          findsNWidgets(2));

      // `skipOffstage: false` because the second field sits below the fold of a
      // 780px test surface, and a finder that skips it would only ever find one.
      await tester
          .tap(find.byTooltip(l10n.showPassword, skipOffstage: false).first);
      await tester.pump();

      final List<TextField> after =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(after[2].obscureText, isFalse);
      // One revealed and one not, so one of each tooltip. Asserting `hide: 2`
      // here would pass if the two fields shared a single toggle, which is the
      // mistake the next test guards against.
      expect(find.byTooltip(l10n.hidePassword, skipOffstage: false),
          findsOneWidget);
      expect(find.byTooltip(l10n.showPassword, skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('the two fields reveal independently', (tester) async {
      // They used to share nothing and so behaved independently by accident,
      // which is the right behaviour. This test says it is intended rather than
      // incidental, because two password fields with one toggle is a real bug
      // someone will eventually "fix".
      await pumpRegister(tester);

      // skipOffstage: false because the second field sits below the fold of a
      // 780px test surface, and a finder that skips it would only ever find one.
      await tester
          .tap(find.byTooltip(l10n.showPassword, skipOffstage: false).first);
      await tester.pump();

      final List<TextField> fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[2].obscureText, isFalse);
      expect(fields[3].obscureText, isTrue);
    });
  });

  group('the consent row', () {
    testWidgets('is not a list tile', (tester) async {
      await pumpRegister(tester);

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('and blocks the submit until it is ticked', (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.byType(TextField).at(1), 'someone');
      await tester.enterText(find.byType(TextField).at(2), 'correct-horse');
      await tester.enterText(find.byType(TextField).at(3), 'correct-horse');
      await tester.tap(find.byType(AuthButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The consent requirement, still enforced.
      expect(find.text(l10n.mustAgreeToTerms), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Now the only remaining complaint is the one the form has no control
      // over, which is the server's answer rather than the form's.
      expect(find.text(l10n.mustAgreeToTerms), findsNothing);
    });
  });

  group('geometry', () {
    testWidgets('no overflow at a narrow width', (tester) async {
      tester.view.physicalSize = const Size(380, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpRegister(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card stops at the form measure', (tester) async {
      tester.view.physicalSize = const Size(2000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpRegister(tester);
      expect(
        tester.getSize(find.byType(AuthCard)).width,
        lessThanOrEqualTo(480),
      );
    });
  });
}
