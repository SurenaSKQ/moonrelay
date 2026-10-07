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

import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

// The measure

/// The hub's content column: one measure, one margin, one scroll.
///
/// Nothing in the hub had a width limit. Every one of its seventeen pages
/// wrapped its own `SingleChildScrollView` with a `spaceXl` all round and ran
/// to the full width of the content pane, which on the two-pane shell is the
/// whole window minus 260. Every page therefore had to invent its own internal
/// geometry to cope with that, and the inventions are where the drift came
/// from: five separate 160px slider wells, a 200px one somewhere else, and
/// thirteen hand-written 22/13/24 heading blocks.
///
/// [MoonrelayInfoPage] already states the answer for the room and space pages
/// that came before the hub, and this reuses its constant rather than declaring
/// a second one. A second number would be the same drift in a smaller hat: two
/// measures, one of them eventually wrong, on two sets of pages that are
/// supposed to look like one app.
///
/// Centred for the same reason it is centred there. The hub is reached from a
/// room, and the eye is already in the middle of the window.
///
/// The gap between sections is applied here rather than by each page. Six of
/// the settings pages spelled it `spaceLg`, seven spelled it a bare `16`, one
/// spelled it `24`, and one forgot it entirely, which is why the vertical
/// rhythm down a settings page could be measured with a ruler and come out
/// different on every screen.
class HubPageBody extends StatelessWidget {
  const HubPageBody({
    super.key,
    required this.children,
    this.controller,
    this.maxWidth = MoonrelayInfoPage.maxContentWidth,
  });

  /// The page's sections, in order. Gaps are inserted between them.
  final List<Widget> children;

  /// Passed to the scroll view so a page can restore or drive its position.
  final ScrollController? controller;

  /// Overridable only by tests and by the one page that is genuinely wide.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return HubMeasure(
      maxWidth: maxWidth,
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          t.spaceLg,
          t.spaceMd,
          t.spaceLg,
          // A full screen of bottom padding is wasted space above a taskbar,
          // and this is the same figure the info pages use.
          t.spaceXxl * 2,
        ),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: t.spaceXl),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Centres a page's content at [HubPageBody]'s measure without taking over its
/// scrolling.
///
/// For the one section that brings its own scroll view, which today is the
/// encryption overview: it is shared with `/main/encryption`, so it owns its
/// `ListView` and would throw if it were nested in another one. What it still
/// needed was the measure, which is why it is the one page in the hub that was
/// left running to the full pane width while every page under it was measured.
class HubMeasure extends StatelessWidget {
  const HubMeasure({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final double width = maxWidth ?? MoonrelayInfoPage.maxContentWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}
