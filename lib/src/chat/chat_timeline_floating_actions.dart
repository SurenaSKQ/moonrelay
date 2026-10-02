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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Vertical column of floating action buttons anchored above the chat
/// composer.  Hides the entire column when the user is parked at the
/// bottom of the timeline *and* the room has no unread messages.
///
/// Two pills, and both can be on screen at once:
///
///   1. Jump-to-unread: shown when the room has unread messages below the
///      current viewport.  Jumps to the first unread message in time,
///      loading a history window if that point is not in the cache.
///   2. Jump-to-bottom: shown when the user has scrolled up away from the
///      newest messages.  Scrolls to the live head, which is in the same
///      render list as any history windows, so it is the same action
///      whether or not windows are loaded.
///
/// They answer different questions ("where is the unread", "where is the
/// new") and a room with unreads while scrolled up has both. An earlier
/// version of this class documented a priority between them; that was wrong,
/// and so was the code, because it only ever rendered one at a time.
///
/// Each pill animates in and out independently so a single state
/// change does not cause the whole column to pop.
class ChatTimelineFloatingActions extends StatelessWidget {
  const ChatTimelineFloatingActions({
    super.key,
    required this.unreadCount,
    required this.isScrolledUp,
    required this.unreadVisible,
    required this.onJumpToUnread,
    required this.onJumpToBottom,
    required this.onDismissUnread,
    required this.isJumping,
    this.loadingContext = false,
  });

  final int unreadCount;
  final bool isScrolledUp;
  final bool unreadVisible;
  final Future<void> Function() onJumpToUnread;

  /// Scrolls to the newest message.
  ///
  /// Not a "back to latest" mode. That existed because the timeline used to
  /// be *substituted* with a history window, so returning to the live head
  /// meant rebuilding the timeline and discarding the window. With the
  /// windows in the same list as the tail, jumping to the bottom is a scroll
  /// like any other and the two cases collapse into one.
  final VoidCallback onJumpToBottom;

  /// Tapping the close icon on the jump-to-unread pill invokes this.
  /// The pill is dismissed but the unread events themselves remain
  /// the user can still scroll up to see them, and a fresh pill will
  /// re-appear the next time the room has unread state.
  final VoidCallback onDismissUnread;

  /// True while the timeline is paginating to bring the first unread
  /// event into the cache.  The pill switches to a "loading" label so
  /// the user has feedback that the tap was registered.
  final bool isJumping;

  /// True while a jump is fetching a `/context` window for an event
  /// that is not in the local cache.  Occupies the unread pill's slot
  /// so the user gets feedback that the tap registered.
  final bool loadingContext;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final animDuration = motion.duration(const Duration(milliseconds: 180));
    final animCurve = motion.curve();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: animDuration,
          curve: animCurve,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: animDuration,
            switchInCurve: animCurve,
            switchOutCurve: animCurve,
            child: loadingContext
                ? const ContextLoadingPill(key: ValueKey('context-loading'))
                : unreadVisible
                    ? JumpToUnreadPill(
                        key: const ValueKey('jump-to-unread'),
                        count: unreadCount,
                        isLoading: isJumping,
                        onTap: onJumpToUnread,
                        onDismiss: onDismissUnread,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('jump-to-unread-empty'),
                      ),
          ),
        ),
        AnimatedSize(
          duration: animDuration,
          curve: animCurve,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: animDuration,
            switchInCurve: animCurve,
            switchOutCurve: animCurve,
            child: isScrolledUp
                ? ScrollToBottomPill(
                    key: const ValueKey('scroll-to-bottom'),
                    onTap: onJumpToBottom,
                  )
                : const SizedBox(
                    key: ValueKey('scroll-to-bottom-empty'),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The chrome shared by the three floating pills above the composer.
///
/// All three asked for `elevation: 4`, which does not do what it looks
/// like it does: Material renders `kElevationToShadow[4]`, a hardcoded
/// three-layer map of pure black in `material/shadows.dart`, and no
/// `ThemeData` field reaches it. In dark mode the message bubble lifted
/// properly (it takes `shadowLow` directly) while these three pills did
/// not, so they read as pasted onto the surface instead of floating above
/// it. The shadow is now passed explicitly, like the bubble's.
///
/// The corner radius is `radiusFull`, so the pill is a stadium whatever its
/// height. It was a literal 20, which happened to match `radiusXl` but was
/// only coincidentally a pill: at 20px radius a shorter pill would have
/// shown square shoulders.
class FloatingPill extends StatelessWidget {
  const FloatingPill({
    super.key,
    required this.child,
    required this.background,
    required this.foreground,
    this.onTap,
    this.leadingSpace = 0,
  });

  final Widget child;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  /// Extra gap above the pill, so a stacked column of two has breathing
  /// room between them.
  final double leadingSpace;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final radius = BorderRadius.circular(t.radiusFull);

    return Padding(
      padding: EdgeInsets.only(top: leadingSpace),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          boxShadow: t.shadowMedium,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.spaceMd + 2,
                vertical: t.spaceSm,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Transient "fetching the surrounding history" pill, shown while a
/// jump to an event outside the local cache is in flight.  It is not
/// interactive: there is nothing to cancel, and a second tap would
/// only queue a duplicate `/context` request.
class ContextLoadingPill extends StatelessWidget {
  const ContextLoadingPill({super.key});

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FloatingPill(
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: t.iconSizeSmall,
            height: t.iconSizeSmall,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onSecondaryContainer,
            ),
          ),
          SizedBox(width: t.spaceSm),
          Text(
            l10n.loadingEventContext,
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating action button shown when the user is away from the newest
/// messages.  Always "jump to bottom", which animates to the live head
/// within the current render list.
class ScrollToBottomPill extends StatelessWidget {
  const ScrollToBottomPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FloatingPill(
      onTap: onTap,
      leadingSpace: t.spaceSm,
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.arrowDown, size: t.iconSizeSmall, color: scheme.onSecondaryContainer),
          SizedBox(width: t.spaceXs),
          Text(
            l10n.scrollToBottom,
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating "Jump to first unread" pill rendered above the chat composer
/// when the room has unread messages below the current viewport.
class JumpToUnreadPill extends StatelessWidget {
  const JumpToUnreadPill({
    super.key,
    required this.count,
    required this.isLoading,
    required this.onTap,
    required this.onDismiss,
  });

  final int count;

  /// When `true`, the pill swaps its label to a "loading" message and
  /// shows a small progress indicator.  Tap handling is disabled so the
  /// user can't queue up multiple paginate requests.
  final bool isLoading;

  final Future<void> Function() onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final label = isLoading
        ? l10n.jumpToUnreadLoading
        : (count == 1
            ? l10n.jumpToFirstUnread
            : l10n.jumpToFirstUnreadMany(count));

    return FloatingPill(
      onTap: isLoading ? null : () => onTap(),
      background: scheme.primary,
      foreground: scheme.onPrimary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: t.iconSizeSmall,
              height: t.iconSizeSmall,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
              ),
            )
          else
            Icon(
              LucideIcons.arrowUp,
              size: t.iconSizeSmall,
              color: scheme.onPrimary,
            ),
          SizedBox(width: t.spaceXs),
          Text(
            label,
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: t.spaceXs),
          _DismissButton(
            tooltip: l10n.unreadPillDismissTooltip,
            onTap: isLoading ? () {} : onDismiss,
            color: scheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

/// Tiny close icon used as the dismiss affordance on [JumpToUnreadPill].
class _DismissButton extends StatelessWidget {
  const _DismissButton({
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    // [Semantics] instead of [Tooltip]: this button is rendered inside
    // the dashboard's [LayoutBuilder] shell. A Tooltip mounts an
    // internal [OverlayPortal] that activates on mount and would mark
    // a sibling [_RenderLayoutBuilder] as needing layout mid-
    // performLayout, tripping the
    // `_RenderLayoutBuilder was mutated in performLayout` assertion.
    // Semantics provides the same accessibility label without
    // materialising an overlay entry.
    return Semantics(
      label: tooltip,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Padding(
          padding: EdgeInsets.all(t.spaceXs),
          child: Icon(
            LucideIcons.x,
            size: t.iconSizeSmall,
            color: color,
          ),
        ),
      ),
    );
  }
}
