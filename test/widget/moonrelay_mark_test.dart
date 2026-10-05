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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/moonrelay_mark.dart';

/// The mark is the app's logo, so what is worth checking is that the asset is
/// actually declared and that the colour argument is actually plumbed through.
///
/// A brand asset missing from `pubspec.yaml`'s `assets:` list does not fail a
/// build. It throws at runtime on the splash screen, which is the one screen
/// nobody tests and everybody sees.
void main() {
  Future<void> mount(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    Color? color,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MoonrelayMark(size: 48, color: color)),
      ),
    );
  }

  testWidgets('the mark renders from its asset', (tester) async {
    await mount(tester);

    expect(find.byType(MoonrelayMark), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    // The real failure mode: a missing asset throws here rather than painting.
    expect(tester.takeException(), isNull);
  });

  testWidgets('it resolves the path the splash screen asks for',
      (tester) async {
    // Guards the one bit of this that is a string and could drift. The splash
    // screen draws the mark on every launch and the path lives in this
    // widget's own constant, so a rename that touched only one of them would
    // leave a runtime failure on the one screen with no other way in.
    expect(MoonrelayMark.assetPath, 'assets/brand/moonrelay-mark.svg');
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the ramp colour reaches the stroke',
        (tester) async {
      await mount(tester, brightness: brightness);

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      // A mark with a hardcoded hex needs two files, and the second one
      // drifts. This one strokes with `currentColor` and is painted with a
      // srcIn blend, so the ramp's `onSurface` decides.
      expect(picture.colorFilter, isNotNull);
    });
  }

  testWidgets('an explicit colour actually reaches the stroke', (tester) async {
    // Not "the filter equals some value", which only proves the test agrees
    // with itself. This proves the colour argument is plumbed into the filter
    // rather than dropped: a `MoonrelayMark(color:)` that ignored its argument
    // would still render, and would be a silent no-op at every call site that
    // tries to tint it.
    Future<ColorFilter?> filterFor(Color? color) async {
      await mount(tester, color: color);
      return tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter;
    }

    final fromRamp = await filterFor(null);
    final tinted = await filterFor(const Color(0xFF7C5DFA));
    final other = await filterFor(const Color(0xFF23A559));

    expect(fromRamp, isNotNull);
    expect(tinted, isNot(fromRamp));
    expect(other, isNot(tinted));
    expect(tester.takeException(), isNull);
  });

  testWidgets('it actually paints strokes', (tester) async {
    // The check that matters for a brand asset, and the one nothing else here
    // substitutes for. `flutter_svg` resolving `currentColor` is not a
    // documented guarantee of the package, and a path whose geometry missed
    // the viewBox would happily render as nothing. Both failures look
    // identical from outside: a blank box. Counting opaque pixels catches
    // both.
    //
    // 634 pixels is the expected order of magnitude for three paths totalling
    // about 180 units of length at a 2.5 stroke inside a 64px box, so the
    // floor is set well below that to allow for anti-aliasing differences
    // between platforms while still failing on an empty render.
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const Center(child: MoonrelayMark(size: 64)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(boundary.toImage))!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final bytes = data.buffer.asUint8List();

    var opaque = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] > 0) opaque++;
    }

    expect(opaque, greaterThan(400), reason: 'the mark rendered nothing');
    expect(
      opaque,
      lessThan(bytes.length ~/ 4 ~/ 4),
      reason: 'the mark filled its box, which a line drawing should not',
    );
  });
}
