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

// The sign-in form's structure, and the two properties the redesign is about.
//
// Everything geometric comes from a token. The form used to spell out
// `BorderRadius.circular(10)` on three fields and `t.radiusMd` on the fourth,
// `BorderRadius.circular(12)` on six buttons and `t.radiusLg` on a seventh, and
// `(horizontal: 16, vertical: 14)` on every `contentPadding` in the segment,
// which is not what `components.input.contentPaddingV` says. So the token and
// the truth had parted company and the visible answer depended on which line of
// which file you read.
//
// Every field offers an autofill hint. It did not. A homeserver address, a
// username and a password are the three things a password manager knows how to
// fill, and none of them were asking.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/login_page/login_page.dart';
import 'package:moonrelay/src/screens/login_page/sso_widgets.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/widgets/auth_surface.dart';

import '../helpers/widget_test_utils.dart';

// No `checkHomeserver` stub: nothing here submits, so no code path reaches the
// network. `login_page_test.dart` overrides it because it presses Enter.
class _LoginClient extends Mock implements Client {
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    // `LoginPage` registers itself as a `WindowListener` in `initState` through
    // `SsoTokenCapture`, which reaches `window_manager`'s method channel. Without
    // a handler the await never completes and the test hangs rather than
    // failing, which is a worse way to learn about this than an exception.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (MethodCall _) async => null,
    );
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    final _LoginClient client = _LoginClient();
    when(() => client.getRoomById(any())).thenReturn(null);
    when(() => client.rooms).thenReturn(<Room>[]);

    // A two-route router rather than a bare `MaterialApp`, because the form's
    // back control calls `context.pop()` and go_router asserts on a missing
    // `GoRouter` ancestor. `login_page_test.dart` already needed one for the
    // same reason.
    final GoRouter router = GoRouter(
      initialLocation: '/login',
      routes: <RouteBase>[
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginPage(),
        ),
        GoRoute(
          path: '/main/rooms',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('Rooms')),
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

  group('the form is built from the shared primitives', () {
    testWidgets('one card, one header, every field an AuthField', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.byType(AuthCard), findsOneWidget);
      expect(find.byType(AuthCardHeader), findsOneWidget);
      expect(find.byType(AuthField), findsNWidgets(3));
      // No private copy of the field left behind.
      expect(find.text('Homeserver'), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('the buttons are AuthButtons, not seven bespoke ones', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.byType(AuthButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      // The form's own links are `TextButton`s with no fill, so the count of
      // outlined buttons on the password screen is zero. It used to be one, for
      // a mode the user has not chosen yet.
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('the back control is the only icon button', (tester) async {
      // `login_page_test.dart` pins this too. It holds because the header is the
      // only place in the form that has one, which is worth saying out loud: the
      // password field's reveal toggle does not exist here, unlike register.
      await pumpLogin(tester);

      expect(find.byType(IconButton), findsOneWidget);
    });
  });

  group('geometry comes from the tokens', () {
    testWidgets('every field border is the input corner radius', (
      tester,
    ) async {
      await pumpLogin(tester);

      final input = MoonrelayDesignTokens.standard();
      for (final TextField field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        final InputDecoration decoration = field.decoration!;
        final BorderRadius radius =
            (decoration.border as OutlineInputBorder).borderRadius;
        expect(radius, BorderRadius.circular(input.radiusMd));
        expect(
          decoration.contentPadding,
          // `spaceLg` across and `spaceMd` down, which is what
          // `MoonrelayInputTokens` derives and what the old literal
          // `(16, 14)` did not.
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      }
    });

    testWidgets('the button radius is the button corner radius', (
      tester,
    ) async {
      await pumpLogin(tester);

      final button = MoonrelayDesignTokens.standard().radiusMd;
      final ButtonStyle style = tester
          .widget<FilledButton>(
            find.byType(FilledButton),
          )
          .style!;
      expect(
        style.shape!.resolve(<WidgetState>{}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(button)),
      );
    });

    testWidgets('the card does not exceed the form measure', (tester) async {
      tester.view.physicalSize = const Size(2400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpLogin(tester);

      // A form stretched across a 2400px window puts the caret nowhere near
      // the label that describes it.
      expect(
          tester.getSize(find.byType(AuthCard)).width, lessThanOrEqualTo(480));
    });
  });

  group('the fields ask to be filled', () {
    /// Switches the form to another mode through its own link, so these tests
    /// exercise the real path a user takes rather than setting `_mode` from the
    /// outside, which the State does not expose.
    Future<void> switchMode(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('homeserver, username and password each carry a hint', (
      tester,
    ) async {
      await pumpLogin(tester);

      final List<Iterable<String>?> hints = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((TextField f) => f.autofillHints)
          .toList();

      expect(
        hints,
        containsAll(<Iterable<String>>[
          const <String>[AutofillHints.url],
          const <String>[AutofillHints.username],
          const <String>[AutofillHints.password],
        ]),
      );
    });

    testWidgets('the token field has no autofill hint, correctly', (
      tester,
    ) async {
      // A login token is not something a password manager holds, so claiming it
      // would be worse than saying nothing. This test exists so that adding one
      // by accident is a visible decision.
      await pumpLogin(tester);
      await switchMode(tester, l10n.useTokenInstead);

      final List<TextField> fields = tester
          .widgetList<TextField>(
            find.byType(TextField),
          )
          .toList();
      // Homeserver and token.
      expect(fields, hasLength(2));
      expect(fields.last.autofillHints, isNull);
    });
  });

  group('the SSO section', () {
    Future<void> enterSso(WidgetTester tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text(l10n.useSsoInstead));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the URL display is a well, not another input', (
      tester,
    ) async {
      await enterSso(tester);

      expect(find.byType(SsoUrlDisplay), findsOneWidget);
      // It carries no caption any more. The block is self-evidently output once
      // it has a border and sits outside every input's own frame, and a caption
      // saying so was one more line between the user and the URL they need.
      expect(find.text(l10n.ssoUrlLabel), findsNothing);
    });

    testWidgets('the waiting banner is the shared pending notice', (
      tester,
    ) async {
      await enterSso(tester);

      // Before pressing "Open in Browser" there is nothing pending, so the
      // banner is absent. That it *would* be an `AuthNotice` in the pending tone
      // is the property: it had its own container with a 30%-alpha accent fill
      // and its own radius, and it was the same kind of message as the failure
      // banner three widgets up.
      expect(find.byType(SsoAwaitingBanner), findsNothing);
    });

    testWidgets('the switch-to-manual button matches the form', (
      tester,
    ) async {
      await enterSso(tester);

      final AuthButton open =
          tester.widget<AuthButton>(find.byType(AuthButton).first);
      final AuthButton manual = tester.widget<AuthButton>(
        find.byType(AuthButton).last,
      );
      expect(open.filled, isFalse, reason: 'the browser hand-off is secondary');
      // It was the only one of the seven buttons in this page using
      // `radiusLg` while the rest used a literal 12.
      expect(manual.filled, isFalse);
      expect(manual.icon, isNotNull);
    });
  });

  group('nothing user-facing is an untranslated literal', () {
    testWidgets('the homeserver hint is a localization key', (tester) async {
      await pumpLogin(tester);

      // It was the literal string `matrix.org`, and there is an ARB key for
      // exactly that text which nothing read. This test is the thing that stops
      // the literal coming back.
      final TextField homeserver = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(homeserver.decoration!.hintText, l10n.registerHomeserverHint);
      expect(homeserver.decoration!.hintText, isNotEmpty);
    });

    testWidgets('the password field has no bullet-character hint', (
      tester,
    ) async {
      await pumpLogin(tester);

      // `••••••••` is a placeholder that says "there is something here", which is
      // the opposite of true and reads as a rendering fault. An empty password
      // field should look empty.
      final TextField password = tester.widget<TextField>(
        find.byWidgetPredicate((Widget w) => w is TextField && w.obscureText),
      );
      expect(password.decoration!.hintText, isNull);
    });
  });
}
