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

// The single-pane shell has to publish a [LayoutScope], like the dashboard
// does, because a descendant that measures itself falls back to
// `_RootLayoutScope` without one. That fallback reports
// `availableWidth: double.infinity` and a hard-coded
// `LayoutSize.expanded`, which is not a neutral default: it is the *widest*
// possible answer handed to the narrowest shell.
//
// The consequence was concrete. `InRoomSearchPanel` picks its width from
// `LayoutScope.of(context).size`, so its compact branch could never fire in
// this shell, and it rendered at a fixed 320px beside a ~180px timeline.
// `SidebarRoomInfo` picks its pinned-preview column count from
// `availableWidth`, and read the fallback as "3 columns".
//
// These tests mount `MobileLayout` directly and assert what a descendant
// actually observes, rather than asserting on the scope's presence, which
// would pass for a scope reporting the wrong thing.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/encryption.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/layouts/mobile_layout.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// Reports what the enclosing scope says, rendered as text so the
/// assertions can read it back.
class _ScopeProbe extends StatelessWidget {
  const _ScopeProbe();

  @override
  Widget build(BuildContext context) {
    final LayoutScope scope = LayoutScope.of(context);
    return Text(
      '${scope.size.name}|${scope.availableWidth}',
      textDirection: TextDirection.ltr,
    );
  }
}

Widget _localized(Widget home) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// The shell wraps its child in `PostLoginSetupChecker` and
/// `IncomingVerificationListener`, which read `EncryptionService`, and in
/// `GlobalShortcutListener`, which reads nothing but does need focus. The
/// shared wrapper supplies the rest; the verification stream has to be
/// stubbed because an unstubbed mock returns null where a `Stream` is
/// expected, which is the same seam the router suite has to patch.
Widget _wrap(Widget child) {
  final encryption = MockEncryptionService();
  when(() => encryption.onKeyVerificationRequest)
      .thenAnswer((_) => const Stream<KeyVerification>.empty());
  return wrapWithProviders(
    encryptionService: encryption,
    child: _localized(child),
  );
}

Future<void> pumpMobileShell(
  WidgetTester tester, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(const MobileLayout(child: _ScopeProbe())));
  await tester.pumpAndSettle();
}

void main() {
  group('MobileLayout publishes a LayoutScope', () {
    testWidgets('a descendant sees the real width, not infinity',
        (tester) async {
      await pumpMobileShell(tester, width: 420);
      expect(find.text('compact|420.0'), findsOneWidget);
    });

    testWidgets('a wide window reports a wide size, not a hard-coded one',
        (tester) async {
      // Forcing the focus shell is the interesting case: the width can be
      // anything, so the reported size has to come from the width rather
      // than from the shell being "the small one".
      await pumpMobileShell(tester, width: 1400);
      expect(find.text('wide|1400.0'), findsOneWidget);
    });

    testWidgets('the root fallback is the only source of infinity',
        (tester) async {
      // Without this shell, a descendant reads the fallback. This is the
      // behaviour the shell exists to avoid, pinned so a regression here is
      // legible rather than mysterious.
      await tester.pumpWidget(
        _wrap(const Scaffold(body: _ScopeProbe())),
      );
      await tester.pumpAndSettle();
      expect(find.text('expanded|${double.infinity}'), findsOneWidget);
    });
  });
}