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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/login_page/login_page.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';

void main() {
  group('LoginPage', () {
    late MockClient client;
    late MockLogger logger;
    late MockEncryptionService encryptionService;

    setUp(() {
      client = MockClient();
      logger = MockLogger();
      encryptionService = MockEncryptionService();

      // The sign-in path clears the cached session before contacting the
      // server, and that reaches into EncryptionService. An unstubbed mock
      // would return null for its Future-returning methods and fail the
      // test before the request is even built.
      when(() => encryptionService.onLogout()).thenAnswer((_) async {});
      when(() => client.clearCache()).thenAnswer((_) async {});
      when(() => client.isLogged()).thenReturn(false);
      // Returns the SDK's four-tuple: discovery, versions, flows, auth
      // metadata. Only the flow list matters to the page, and an empty one
      // means it reports "this server does not support that method", which
      // is a fine place to stop for a keyboard test.
      when(() => client.checkHomeserver(any(), checkWellKnown: true)).thenAnswer(
        (_) async => (
          null,
          GetVersionsResponse(versions: ['v1.11']),
          <LoginFlow>[],
          null,
        ),
      );

      // Stub window_manager method channels for test environment
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'addListener':
            case 'removeListener':
            case 'setPreventClose':
            case 'setTitleBarStyle':
            case 'show':
            case 'setMinimumSize':
            case 'setSkipTaskbar':
            case 'waitUntilReadyToShow':
            case 'destroy':
              return null;
            default:
              return null;
          }
        },
      );
    });

    Widget buildApp() {
      final goRouter = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/main/rooms',
            builder: (context, state) => const Scaffold(body: Text('Rooms')),
          ),
        ],
      );

      return MultiProvider(
        providers: [
          Provider<Client>.value(value: client),
          Provider<Logger>.value(value: logger),
          ChangeNotifierProvider<EncryptionService>.value(
            value: encryptionService as EncryptionService,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: goRouter,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    testWidgets('renders login form with all fields', (tester) async {
      await tester.pumpWidget(buildApp());

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Homeserver'), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('has a back button', (tester) async {
      await tester.pumpWidget(buildApp());

      // LoginPage uses LucideIcons.arrowLeft, verify a back navigation icon is present
      final backButtons = find.byType(IconButton);
      // There should be exactly one IconButton (the back button)
      expect(backButtons, findsOneWidget);
    });

    testWidgets('has a homeserver text field with default value',
        (tester) async {
      await tester.pumpWidget(buildApp());

      // The homeserver controller now defaults to "matrix.org". Both the
      // EditableText and hint Text widgets contain this string.
      expect(find.text('matrix.org'), findsWidgets);
    });

    group('keyboard', () {
      /// The field at [n] in the visible order, counted from the top.
      Finder field(int n) => find.byType(TextField).at(n);

      testWidgets('Tab moves through the fields in the order shown',
          (tester) async {
        await tester.pumpWidget(buildApp());

        // Password mode shows homeserver, username, password in that order.
        expect(find.byType(TextField), findsNWidgets(3));

        await tester.tap(field(0));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'username',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'password');

        // Tab from the last field leaves the form rather than wrapping.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          isNot('password'),
        );
      });

      testWidgets('Enter on the first field moves to the next, not submit',
          (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.tap(field(0));
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'username');
      });

      testWidgets('Enter on the last field submits', (tester) async {
        // The page adds the login type to this set before contacting the
        // server, so its contents say the request got as far as being built.
        final types = <String>{};
        when(() => client.supportedLoginTypes).thenReturn(types);

        await tester.pumpWidget(buildApp());
        await tester.tap(field(2));
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump();

        expect(types, contains(AuthenticationTypes.password));
      });

      testWidgets('the visible field count follows the mode', (tester) async {
        await tester.pumpWidget(buildApp());
        expect(find.byType(TextField), findsNWidgets(3));

        await tester.tap(find.text('Use login token instead'));
        await tester.pump();

        // Token mode drops username and password for a single token field.
        expect(find.byType(TextField), findsNWidgets(2));
      });
    });
  });
}
