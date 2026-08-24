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

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/responsive.dart';

void main() {
  group('LayoutBreakpoints.sizeForWidth', () {
    test('returns compact below 600', () {
      expect(LayoutBreakpoints.sizeForWidth(0), LayoutSize.compact);
      expect(LayoutBreakpoints.sizeForWidth(320), LayoutSize.compact);
      expect(LayoutBreakpoints.sizeForWidth(599), LayoutSize.compact);
    });

    test('returns medium between 600 and 900', () {
      expect(LayoutBreakpoints.sizeForWidth(600), LayoutSize.medium);
      expect(LayoutBreakpoints.sizeForWidth(768), LayoutSize.medium);
      expect(LayoutBreakpoints.sizeForWidth(899), LayoutSize.medium);
    });

    test('returns compact between 900 and 1100 (unified sidebar shell)', () {
      // The dashboard treats the entire 900-1100 range as a compact
      // shell so the unified sidebar stays visible.  sizeForWidth still
      // returns LayoutSize.compact here for consumers that follow the
      // shell-selection helpers (shouldUseCompact / shouldUseMobile).
      expect(LayoutBreakpoints.sizeForWidth(900), LayoutSize.compact);
      expect(LayoutBreakpoints.sizeForWidth(1024), LayoutSize.compact);
      expect(LayoutBreakpoints.sizeForWidth(1099), LayoutSize.compact);
    });

    test('returns wide at or above 1100', () {
      expect(LayoutBreakpoints.sizeForWidth(1100), LayoutSize.wide);
      expect(LayoutBreakpoints.sizeForWidth(1920), LayoutSize.wide);
    });
  });

  group('LayoutBreakpoints.shouldUseCompact', () {
    test('true in the dashboard compact window (600-1100)', () {
      expect(LayoutBreakpoints.shouldUseCompact(600), isTrue);
      expect(LayoutBreakpoints.shouldUseCompact(900), isTrue);
      expect(LayoutBreakpoints.shouldUseCompact(1099), isTrue);
    });

    test('false above expandedMax', () {
      expect(LayoutBreakpoints.shouldUseCompact(1100), isFalse);
      expect(LayoutBreakpoints.shouldUseCompact(1600), isFalse);
    });

    test('false below mobileMax (mobile takes over)', () {
      expect(LayoutBreakpoints.shouldUseCompact(599), isFalse);
      expect(LayoutBreakpoints.shouldUseCompact(0), isFalse);
    });
  });

  group('LayoutBreakpoints.shouldUseMobile', () {
    test('true below mobileMax', () {
      expect(LayoutBreakpoints.shouldUseMobile(0), isTrue);
      expect(LayoutBreakpoints.shouldUseMobile(320), isTrue);
      expect(LayoutBreakpoints.shouldUseMobile(599), isTrue);
    });

    test('false at or above mobileMax', () {
      expect(LayoutBreakpoints.shouldUseMobile(600), isFalse);
      expect(LayoutBreakpoints.shouldUseMobile(900), isFalse);
    });
  });

  group('LayoutSizeX', () {
    test('hasTwoSidebars only true for expanded/wide', () {
      expect(LayoutSize.compact.hasTwoSidebars, isFalse);
      expect(LayoutSize.medium.hasTwoSidebars, isFalse);
      expect(LayoutSize.expanded.hasTwoSidebars, isTrue);
      expect(LayoutSize.wide.hasTwoSidebars, isTrue);
    });

    test('hasOneSidebar true for medium+', () {
      expect(LayoutSize.compact.hasOneSidebar, isFalse);
      expect(LayoutSize.medium.hasOneSidebar, isTrue);
      expect(LayoutSize.expanded.hasOneSidebar, isTrue);
      expect(LayoutSize.wide.hasOneSidebar, isTrue);
    });

    test('isCompact true only for compact', () {
      expect(LayoutSize.compact.isCompact, isTrue);
      expect(LayoutSize.medium.isCompact, isFalse);
      expect(LayoutSize.expanded.isCompact, isFalse);
      expect(LayoutSize.wide.isCompact, isFalse);
    });
  });

  group('LayoutBreakpoints.clampSidebarWidth', () {
    test('returns requested width when it fits in the viewport', () {
      // viewport=800, sidebar=400, main=300, other=0 -> 400 fits.
      final result = LayoutBreakpoints.clampSidebarWidth(
        requestedWidth: 400,
        viewportWidth: 800,
        mainMinWidth: 300,
        otherPanesWidth: 0,
      );
      expect(result, 400);
    });

    test('clamps down when the requested width exceeds available', () {
      // viewport=500, sidebar=800, main=300, other=0
      // available = (500-300-0).clamp(200,600) = 200
      // clamped = 800.clamp(200, 200) = 200
      final result = LayoutBreakpoints.clampSidebarWidth(
        requestedWidth: 800,
        viewportWidth: 500,
        mainMinWidth: 300,
        otherPanesWidth: 0,
      );
      expect(result, 200);
    });

    test('respects min sidebar width', () {
      final result = LayoutBreakpoints.clampSidebarWidth(
        requestedWidth: 100,
        viewportWidth: 1000,
        mainMinWidth: 0,
        otherPanesWidth: 0,
      );
      expect(result, LayoutBreakpoints.minSidebarWidth);
    });

    test('never larger than max sidebar width', () {
      final result = LayoutBreakpoints.clampSidebarWidth(
        requestedWidth: 9999,
        viewportWidth: 9999,
        mainMinWidth: 100,
        otherPanesWidth: 0,
      );
      expect(result, lessThanOrEqualTo(LayoutBreakpoints.maxSidebarWidth));
    });

    test('accounts for other panes when computing available space', () {
      // viewport=700, sidebar=300, main=200, other=200 -> 300 fits.
      final result = LayoutBreakpoints.clampSidebarWidth(
        requestedWidth: 300,
        viewportWidth: 700,
        mainMinWidth: 200,
        otherPanesWidth: 200,
      );
      expect(result, 300);
    });
  });

  group('BoxConstraintsLayoutSize', () {
    test('derives LayoutSize from constraints.maxWidth', () {
      const cs = BoxConstraints(maxWidth: 800);
      expect(cs.layoutSize, LayoutSize.medium);
      const wide = BoxConstraints(maxWidth: 1500);
      expect(wide.layoutSize, LayoutSize.wide);
    });
  });
}