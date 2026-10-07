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

// Pin tests for the Motion helper that centralises the "are animations
// on?" decision.  Keeping this logic out of every individual widget
// means new surfaces just consult [Motion.of] without re-implementing
// the conditional each time.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsController controller;
  late SettingsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = SettingsService();
    controller = SettingsController(service);
    await service.updateEnableAnimations(true);
    await controller.loadSettings();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: ChangeNotifierProvider<SettingsController>.value(
        value: controller,
        child: Builder(
          builder: (context) => child,
        ),
      ),
    );
  }

  testWidgets(
    'duration returns the requested duration when animations are on',
    (tester) async {
      late Motion seen;
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) {
            seen = Motion.of(context);
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(seen.enableAnimations, isTrue);
      expect(
        seen.duration(const Duration(milliseconds: 220)),
        const Duration(milliseconds: 220),
      );
    },
  );

  testWidgets(
    'duration returns Duration.zero when animations are off',
    (tester) async {
      await controller.updateEnableAnimations(false);
      late Motion seen;
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) {
            seen = Motion.of(context);
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(seen.enableAnimations, isFalse);
      expect(
        seen.duration(const Duration(milliseconds: 220)),
        Duration.zero,
      );
    },
  );
}
