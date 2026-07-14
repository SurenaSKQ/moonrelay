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

/// Vertical column of floating action buttons anchored above the chat
/// composer.  Hides the entire column when the user is parked at the
/// bottom of the timeline *and* the room has no unread messages.
///
/// Two pills are supported:
///   1. Jump-to-unread  shown when the room has unread messages
///      below the current viewport.  Takes visual priority when both
///      pills are visible.
///   2. Scroll-to-bottom  shown when the user has scrolled up away
///      from the newest messages.  Lets them jump back without
///      dragging all the way down.
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
    required this.onScrollToBottom,
    required this.onDismissUnread,
    required this.isJumping,
  });

  final int unreadCount;
  final bool isScrolledUp;
  final bool unreadVisible;
  final Future<void> Function() onJumpToUnread;
  final VoidCallback onScrollToBottom;

  /// Tapping the close icon on the jump-to-unread pill invokes this.
  /// The pill is dismissed but the unread events themselves remain
  /// the user can still scroll up to see them, and a fresh pill will
  /// re-appear the next time the room has unread state.
  final VoidCallback onDismissUnread;

  /// True while the timeline is paginating to bring the first unread
  /// event into the cache.  The pill switches to a "loading" label so
  /// the user has feedback that the tap was registered.
  final bool isJumping;

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
            child: unreadVisible
                ? JumpToUnreadPill(
                    key: const ValueKey('jump-to-unread'),
                    count: unreadCount,
                    isLoading: isJumping,
                    onTap: onJumpToUnread,
                    onDismiss: onDismissUnread,
                  )
                : const SizedBox.shrink(key: ValueKey('jump-to-unread-empty')),
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
                    onTap: onScrollToBottom,
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

/// "Scroll to bottom" floating action button.  Shown when the user
/// has scrolled away from the bottom of the timeline.  Tapping
/// animates the scroll back to the newest message.
class ScrollToBottomPill extends StatelessWidget {
  const ScrollToBottomPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.secondaryContainer,
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.arrowDown,
                  size: 14,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
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
          ),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final label = isLoading
        ? l10n.jumpToUnreadLoading
        : (count == 1
            ? l10n.jumpToFirstUnread
            : l10n.jumpToFirstUnreadMany(count));

    return Material(
      color: scheme.primary,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: isLoading
                  ? null
                  : () {
                      // ignore: discarded_futures
                      onTap();
                    },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
                        ),
                      )
                    else
                      Icon(
                        LucideIcons.arrowUp,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _DismissButton(
              tooltip: l10n.unreadPillDismissTooltip,
              onTap: isLoading ? () {} : onDismiss,
              color: scheme.onPrimary,
            ),
          ],
        ),
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
          padding: const EdgeInsets.all(4),
          child: Icon(
            LucideIcons.x,
            size: 12,
            color: color,
          ),
        ),
      ),
    );
  }
}
