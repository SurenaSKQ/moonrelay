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

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Owns the per-timeline hover state for the floating action bar.
///
/// ## Why this is not a [ChangeNotifier]
///
/// An earlier iteration inherited [ChangeNotifier] so the controller
/// could notify its dependents via [InheritedNotifier].  That
/// triggered an assertion during layout: an item calling
/// `registerRect` mid-build caused the controller to notify, which
/// marked the [InheritedNotifier]'s dependents dirty, which
/// Flutter then refused to mark because the framework was already
/// in the middle of a build.  The fix is to keep state internal
/// and only notify *consumers* (the toolbar) via the two
/// [ValueNotifier]s below.  Items register geometry through plain
/// method calls; the controller does not need to fire a build for
/// them.
class HoverOverlayController {
  /// Builds the controller with sane defaults.  Tests can override
  /// the hide debounce via [hideDebounce].
  HoverOverlayController({Duration hideDebounce = const Duration(milliseconds: 80)})
      : _hideDebounce = hideDebounce;

  /// Short grace window between "no item under cursor" and "toolbar
  /// actually hides".  Long enough that a quick 2-row drag
  /// doesn't toggle the toolbar off and back on, short enough that
  /// a deliberate cursor-out-the-window still feels immediate.
  final Duration _hideDebounce;
  Duration get hideDebounce => _hideDebounce;

  /// Single source of truth for "what item is the toolbar
  /// anchored to right now".  Reads as `null` when nothing is
  /// hovered.  The toolbar's [ListenableBuilder] subscribes to this
  /// directly so a state change only rebuilds the toolbar, never
  /// the whole timeline subtree.
  final ValueNotifier<GlobalKey?> hoveredKey =
      ValueNotifier<GlobalKey?>(null);

  /// Whether the toolbar should paint.  Flipped to false by the
  /// debounced hide timer; flipped back to true by any
  /// [enterToolbar] or [hitTest] call.
  final ValueNotifier<bool> toolbarVisible = ValueNotifier<bool>(false);

  Timer? _hideTimer;

  /// Registered items: their [GlobalKey] and the last-known render
  /// rect (global coordinates).  Updated by the per-item
  /// [_HoverGeometryProbe] via [registerRect].
  final Map<GlobalKey, Rect> itemRects = <GlobalKey, Rect>{};

  /// Registered items: their [GlobalKey] and the toolbar data
  /// ([HoverTargetEntry]).  Updated by the per-item [HoverItem]
  /// via [registerEntry].  The toolbar uses this map to look up
  /// the data for the currently-hovered key.
  final Map<GlobalKey, HoverTargetEntry> itemEntries =
      <GlobalKey, HoverTargetEntry>{};

  void registerRect(GlobalKey key, Rect rectInGlobal) {
    final prev = itemRects[key];
    if (prev == rectInGlobal) return;
    itemRects[key] = rectInGlobal;
  }

  void unregisterRect(GlobalKey key) {
    if (itemRects.remove(key) == null) return;
    if (hoveredKey.value == key) {
      _deferClearHovered(key);
    }
  }

  /// Registers [entry] for [key].  The toolbar reads from
  /// [itemEntries] when positioning above a hovered key.
  void registerEntry(GlobalKey key, HoverTargetEntry entry) {
    itemEntries[key] = entry;
  }

  void unregisterEntry(GlobalKey key) {
    if (itemEntries.remove(key) == null) return;
    if (hoveredKey.value == key) {
      _deferClearHovered(key);
    }
  }

  /// Deferred pending flag so we don't pile up multiple callbacks
  /// when many items are deactivated in the same frame.
  GlobalKey? _deferredClearKey;

  /// Defers the [hoveredKey] and [toolbarVisible] ValueNotifier mutations
  /// out of the build phase.  Called by [unregisterRect] and
  /// [unregisterEntry] during element deactivation, which happens while
  /// the ListView is being rebuilt.  The overlay toolbar's
  /// [ValueListenableBuilder] listeners would otherwise call
  /// `markNeedsBuild` during build, throwing an exception.
  void _deferClearHovered(GlobalKey key) {
    // Only schedule once per frame — the last key wins, which is fine
    // since all equal-height items scroll out together.
    if (_deferredClearKey != null) return;
    _deferredClearKey = key;
    // Use post-frame callback to avoid ValueNotifier notification
    // during the ListView's build phase.  Fall back to synchronous
    // clear when no binding is available (unit tests).
    bool scheduled = false;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _deferredClearKey = null;
        // Only clear if the hovered key hasn't changed since we scheduled.
        if (hoveredKey.value == key) {
          hoveredKey.value = null;
          toolbarVisible.value = false;
          _hideTimer?.cancel();
          _hideTimer = null;
        }
      });
      scheduled = true;
    } catch (_) {
      // No binding initialized (unit tests).
    }
    if (!scheduled) {
      _deferredClearKey = null;
      if (hoveredKey.value == key) {
        hoveredKey.value = null;
        toolbarVisible.value = false;
        _hideTimer?.cancel();
        _hideTimer = null;
      }
    }
  }

  /// Hit-test the registered items.  Called by the global
  /// [MouseRegion] on every pointer move.  [pointer] is in the
  /// same coordinate space as the rects registered by
  /// [registerRect] (global).
  void hitTest(Offset pointer) {
    GlobalKey? hit;
    for (final entry in itemRects.entries) {
      if (entry.value.contains(pointer)) {
        hit = entry.key;
        break;
      }
    }
    _setHoveredKey(hit, fromPointer: true);
  }

  /// Called by the toolbar's [MouseRegion] when the cursor enters
  /// its hit-region.  Re-claims the active item even if a sibling
  /// row briefly won the global hit-test -- the wider cursor
  /// holding power lives with the toolbar.
  void enterToolbar(GlobalKey key) {
    if (hoveredKey.value == key && toolbarVisible.value) return;
    _hideTimer?.cancel();
    _hideTimer = null;
    toolbarVisible.value = true;
    hoveredKey.value = key;
  }

  /// Called by the toolbar's [MouseRegion] when the cursor exits
  /// its hit-region.  Schedules a debounced hide.
  void scheduleToolbarHide() {
    if (!toolbarVisible.value) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDebounce, () {
      toolbarVisible.value = false;
      hoveredKey.value = null;
      _hideTimer = null;
    });
  }

  /// Cancels a pending hide.  Called by the global hit-test when
  /// it re-asserts [hoveredKey] within the debounce window.
  void cancelHide() {
    if (_hideTimer == null) return;
    _hideTimer?.cancel();
    _hideTimer = null;
    toolbarVisible.value = true;
  }

  void _setHoveredKey(GlobalKey? next, {bool fromPointer = false}) {
    if (hoveredKey.value == next) {
      if (next != null && _hideTimer != null) cancelHide();
      return;
    }
    if (next != null) {
      if (_hideTimer != null) {
        _hideTimer?.cancel();
        _hideTimer = null;
      }
      // Order matters: [toolbarVisible] must be set BEFORE
      // [hoveredKey] so the synchronous listener on [hoveredKey]
      // (which calls [_syncOverlay]) sees [toolbarVisible] already
      // true.  If the order is reversed the listener clears the
      // overlay entry because the visibility flag is still false.
      toolbarVisible.value = true;
      hoveredKey.value = next;
      return;
    }
    // Miss: clear the active key immediately so the toolbar
    // unanchors from the row it was on, but keep the visibility
    // flag on for [hideDebounce] so a quick cursor bounce into
    // another row doesn't pop the toolbar off.  [cancelHide] or a
    // fresh hit within the window cancels the timer cleanly.
    hoveredKey.value = null;
    if (toolbarVisible.value) {
      scheduleToolbarHide();
    }
  }

  /// Disposes timers and notifiers.  Call when the timeline view
  /// is torn down.
  void dispose() {
    _hideTimer?.cancel();
    _deferredClearKey = null;
    hoveredKey.dispose();
    toolbarVisible.dispose();
    itemRects.clear();
    itemEntries.clear();
  }
}

/// Identifies an item to the hover overlay.
class HoverTargetEntry {
  const HoverTargetEntry({
    required this.key,
    required this.event,
    required this.room,
    required this.timeline,
    required this.onReply,
    required this.onForward,
    required this.onThread,
    required this.onJumpToEvent,
  });

  final GlobalKey key;
  final dynamic event;
  final dynamic room;
  final dynamic timeline;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onThread;
  final void Function(String)? onJumpToEvent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoverTargetEntry && other.key == key;

  @override
  int get hashCode => identityHashCode(key);
}

/// Inherited handle around the nearest [HoverOverlayController].
///
/// ## Why a plain [InheritedWidget], not an [InheritedNotifier]
///
/// The previous implementation was an [InheritedNotifier] that
/// fired `markNeedsBuild` on every dependent whenever the
/// controller notified.  An item calling `registerRect` mid-build
/// (e.g. from a [LayoutBuilder]-driven geometry probe inside a
/// scroll-driven layout pass) tripped an assertion:
///
///   setState() or markNeedsBuild() called during build.
///
/// A plain [InheritedWidget] doesn't subscribe descendants to
/// the controller's state.  Items and the toolbar read the
/// controller through [HoverScope.maybeOf] but they don't
/// rebuild when the controller's state changes -- the toolbar
/// subscribes to the controller's [ValueNotifier]s directly
/// through [ListenableBuilder].
class HoverScope extends InheritedWidget {
  const HoverScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final HoverOverlayController controller;

  /// Returns the controller from the nearest [HoverScope] in the
  /// widget tree, or `null` if none is in scope.
  ///
  /// Does not subscribe the calling widget to controller state
  /// changes -- see the class doc for why.
  static HoverOverlayController? maybeOf(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<HoverScope>();
    return widget?.controller;
  }

  /// Non-subscribing lookup for callers that should not rebuild
  /// when the controller changes (e.g. a [MouseRegion] callback).
  static HoverOverlayController? readOf(BuildContext context) {
    final widget =
        context.getInheritedWidgetOfExactType<HoverScope>();
    return widget?.controller;
  }

  @override
  bool updateShouldNotify(HoverScope oldWidget) =>
      controller != oldWidget.controller;
}
