// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The room-list filter, as a segmented control.
///
/// This was two `NavRow`s labelled "Home" and "All", which was wrong twice.
/// The labels were navigation words for what is a filter, and it was drawn
/// as two rows in a list of destinations, so it read as "here are two
/// places" rather than "here is one list and these are two views of it".
/// People clicked the one that sounded like a destination and were
/// surprised by a narrower list.
///
/// Three things now say what it is:
///
///  * An inset track with a pill that *slides* between segments. That is
///    the filter idiom, and the movement is the part that carries it: two
///    lit buttons would read as tabs, one pill moving between two homes
///    reads as one control changing state.
///  * The segments are labelled by what the list contains, not by where it
///    takes you: "Friends" and "All rooms". "Home" in particular was
///    actively misleading, because Home showed direct messages and nothing
///    else, which is not what anyone means by home.
///  * The rooms section header underneath echoes whichever word is lit, so
///    the control and its result are visibly the same thing.
///
/// It sits above the Spaces section rather than directly above the Rooms
/// header it filters. Putting it next to its result would show the
/// relationship better and read worse, because a control that changes what
/// is below a different section looks like it belongs to that section.
class RoomListFilter extends StatelessWidget {
  const RoomListFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationState>();
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    final segments = <_Segment>[
      _Segment(
        label: l10n.friends,
        icon: LucideIcons.userRound,
        selected: nav.isHome,
        onTap: nav.selectHome,
      ),
      _Segment(
        label: l10n.allRooms,
        icon: LucideIcons.messagesSquare,
        selected: nav.isAll,
        onTap: nav.selectAll,
      ),
    ];

    final selectedIndex = segments.indexWhere((s) => s.selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Semantics(
        // Announced as a filter rather than as two buttons, because that
        // is what it is and a screen reader user cannot see the track.
        container: true,
        label: l10n.filterRooms,
        child: Container(
          // 36, so each half of the track is a 30px target once the 3px
          // inset is taken off. Not the Material 48px minimum, which does
          // not fit: this pane is already the tightest thing in the app and
          // two extra pixels of height is a row of rooms somewhere else.
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            // Inset, not a card. A raised track with a raised pill inside it
            // is two elevations fighting, and the track must read as a
            // hollow the pill moves in.
            color: scheme.surfaceContainerHighest
                .withValues(alpha: t.opacitySubtle),
            borderRadius: BorderRadius.circular(t.radiusFull),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Half of what is left, and nothing more. This subtracted the
              // 3px inset a second time, which left a 6px dead strip down
              // the right of the track: the segments were 6px short of
              // filling it, so the far edge of the second one was not
              // clickable either.
              final segmentWidth = constraints.maxWidth / 2;
              return Stack(
                children: [
                  if (selectedIndex >= 0)
                    AnimatedPositioned(
                      key: const ValueKey('filter-pill'),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      left: segmentWidth * selectedIndex,
                      top: 0,
                      bottom: 0,
                      width: segmentWidth,
                      child: _Pill(
                        scheme: scheme,
                        radius: BorderRadius.circular(t.radiusFull),
                      ),
                    ),
                  Row(
                    // `stretch`, or the segments size to their text and the
                    // top and bottom of every slot are dead space. A `Row`
                    // defaults to `CrossAxisAlignment.center`, which hands
                    // its children loose height constraints, so each
                    // `SizedBox` was taking the InkWell's content height:
                    // about 18px inside a 28px slot. The slot looked
                    // tappable and the top and bottom of it silently were
                    // not.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final segment in segments)
                        SizedBox(
                          width: segmentWidth,
                          child: _SegmentButton(segment: segment),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Segment {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

/// The lit half of the track.
///
/// Carries its own elevation and a hairline rather than relying on the
/// fill contrast alone, so the selected segment is still identifiable in a
/// theme where the accent sits close to the surface.
class _Pill extends StatelessWidget {
  const _Pill({required this.scheme, required this.radius});

  final ColorScheme scheme;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: t.opacitySubtle),
        ),
        boxShadow: t.shadowLow,
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.segment});

  final _Segment segment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final foreground = segment.selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: segment.selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: segment.onTap,
          borderRadius: BorderRadius.circular(t.radiusFull),
          // Fills the slot rather than wrapping the label, so the whole
          // half of the track is the target and not just the words in it.
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(segment.icon, size: 14, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: segment.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
