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

import 'package:flutter_test/flutter_test.dart';

import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LayoutShell update(controller, double width, [LayoutMode mode = LayoutMode.auto]) =>
      controller.update(rawWidth: width, layoutMode: mode);

  group('first evaluation', () {
    test('commits the width-appropriate shell immediately', () {
      final controller = LayoutShellController();
      expect(update(controller, 500), LayoutShell.mobile);
      expect(update(controller, 800), LayoutShell.compact);
      expect(update(controller, 1400), LayoutShell.expanded);
    });

    test('treats 600 as the boundary between mobile and compact', () {
      expect(update(LayoutShellController(), 599), LayoutShell.mobile);
      expect(update(LayoutShellController(), 600), LayoutShell.compact);
    });
  });

  group('1100 px boundary', () {
    test('expanded stays put inside the dead band before going compact', () {
      final controller = LayoutShellController();
      update(controller, 1400);
      expect(controller.shell, LayoutShell.expanded);

      // 1050 is within the dead band (needs to fall below 1040).
      expect(update(controller, 1050), LayoutShell.expanded);
      expect(update(controller, 1030), LayoutShell.compact);
    });

    test('compact stays put inside the dead band before going expanded', () {
      final controller = LayoutShellController();
      update(controller, 800);
      expect(controller.shell, LayoutShell.compact);

      // 1150 is within the dead band (needs to reach 1160).
      expect(update(controller, 1150), LayoutShell.compact);
      expect(update(controller, 1170), LayoutShell.expanded);
    });

    test('oscillating around the boundary never flaps the shell', () {
      final controller = LayoutShellController();
      update(controller, 1400); // expanded

      // Bounce back and forth inside the dead band.
      for (final width in [1090.0, 1110.0, 1080.0, 1120.0, 1050.0, 1140.0]) {
        expect(update(controller, width), LayoutShell.expanded,
            reason: 'width $width must not flip an expanded shell');
      }
      // Commit compact, then bounce again: the shell stays compact.
      update(controller, 1000);
      expect(controller.shell, LayoutShell.compact);
      for (final width in [1090.0, 1110.0, 1080.0, 1120.0]) {
        expect(update(controller, width), LayoutShell.compact,
            reason: 'width $width must not flip a compact shell');
      }
    });
  });

  group('600 px boundary', () {
    test('compact stays put inside the dead band before going mobile', () {
      final controller = LayoutShellController();
      update(controller, 800);
      expect(controller.shell, LayoutShell.compact);

      // 550 is within the dead band (needs to fall below 540).
      expect(update(controller, 550), LayoutShell.compact);
      expect(update(controller, 530), LayoutShell.mobile);
    });

    test('mobile stays put inside the dead band before going compact', () {
      final controller = LayoutShellController();
      update(controller, 400);
      expect(controller.shell, LayoutShell.mobile);

      // 650 is within the dead band (needs to reach 660).
      expect(update(controller, 650), LayoutShell.mobile);
      expect(update(controller, 670), LayoutShell.compact);
    });
  });

  group('user-forced layout mode', () {
    test('forced compact overrides a wide window and sticks', () {
      final controller = LayoutShellController();
      update(controller, 1400);
      expect(update(controller, 1400, LayoutMode.compact), LayoutShell.compact);

      // Resizing stays compact; only a mode change back to auto frees it.
      expect(update(controller, 1600, LayoutMode.compact), LayoutShell.compact);
      expect(update(controller, 500, LayoutMode.compact), LayoutShell.compact);
    });

    test('forced mobile overrides width and sticks', () {
      final controller = LayoutShellController();
      update(controller, 1400);
      expect(update(controller, 1400, LayoutMode.mobile), LayoutShell.mobile);
      expect(update(controller, 1200, LayoutMode.mobile), LayoutShell.mobile);
    });

    test('returning to auto re-resolves from the current shell', () {
      final controller = LayoutShellController();
      update(controller, 1400);
      update(controller, 1400, LayoutMode.compact);
      expect(controller.shell, LayoutShell.compact);

      // Width still calls for expanded, so auto returns there immediately.
      expect(update(controller, 1400, LayoutMode.auto), LayoutShell.expanded);
    });
  });

  group('idempotency', () {
    test('repeated updates with the same width are stable', () {
      final controller = LayoutShellController();
      update(controller, 800);
      update(controller, 800);
      update(controller, 800);
      expect(controller.shell, LayoutShell.compact);
      expect(update(controller, 800), LayoutShell.compact);
    });
  });
}
