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
import 'package:moonrelay/src/chat/hover_overlay.dart';
import 'package:moonrelay/src/chat/message_actions.dart';

/// Drives the floating action bar's [Overlay] insertion.
///
/// ## Why this is a true [Overlay], not a sibling [Stack] child
///
/// Previously the toolbar was positioned as a sibling in the
/// timeline [Stack].  That meant:
///
///   * The toolbar was clipped to the chat column's bounds, so a
///     wide toolbar couldn't overhang.
///   * The toolbar was on the same layer as the message rows,
///     so the cursor had to cross a sliver of empty space when
///     travelling between a row's body and the toolbar visual
///     region.  The brief "no MouseRegion" gap produced the
///     flash described by users.
///
/// The new design inserts the toolbar into the route's
/// [Overlay.of].  That puts the toolbar in its own layer above
/// the timeline, lets the toolbar host its own [MouseRegion]
/// that absorbs the cursor while it travels between the message
/// body and the toolbar, and keeps the toolbar independent of
/// the timeline's clip rect.
///
/// The active item is the [HoverOverlayController.hoveredKey]; the
/// toolbar above each item positions itself relative to that
/// item's render rect via [RenderBox.localToGlobal].
class HoverOverlay extends StatefulWidget {
  const HoverOverlay({super.key});

  @override
  State<HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<HoverOverlay> {
  /// Latest overlay entry.  Re-inserted when the active key
  /// changes so the toolbar's position follows the active item.
  OverlayEntry? _entry;

  /// Last known item-key we pinned the overlay to.  Lets us
  /// detect when we need to swap the entry.
  GlobalKey? _pinnedKey;

  /// Subscriptions to the controller's notifiers so we know when
  /// the active item or visibility flag changed.
  late VoidCallback _hoveredKeySub;
  late VoidCallback _visibleSub;

  HoverOverlayController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use [readOf] (non-listening) so [HoverOverlay] does not
    // subscribe its dependents to controller state.  Instead
    // it adds its own [ValueNotifier] listeners below, which
    // mark only this widget dirty.
    final next = HoverScope.readOf(context);
    if (identical(next, _controller)) return;
    _unsub();
    _controller = next;
    if (next != null) {
      _hoveredKeySub = () {
        if (mounted) _syncOverlay();
      };
      _visibleSub = () {
        if (mounted) _syncOverlay();
      };
      next.hoveredKey.addListener(_hoveredKeySub);
      next.toolbarVisible.addListener(_visibleSub);
    }
    _syncOverlay();
  }

  @override
  void deactivate() {
    _removeEntry();
    _unsub();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeEntry();
    _unsub();
    super.dispose();
  }

  void _unsub() {
    final c = _controller;
    if (c == null) return;
    try {
      c.hoveredKey.removeListener(_hoveredKeySub);
      c.toolbarVisible.removeListener(_visibleSub);
    } catch (_) {
      // Controller may have been disposed before the listeners
      // were uninstalled (rare, but possible during tear-down).
    }
  }

  void _syncOverlay() {
    final controller = _controller;
    if (controller == null) {
      _removeEntry();
      return;
    }
    final key = controller.hoveredKey.value;
    final visible = controller.toolbarVisible.value;
    if (key == null || !visible) {
      _removeEntry();
      _pinnedKey = null;
      return;
    }
    if (identical(key, _pinnedKey) && _entry != null) return;
    _pinnedKey = key;
    _removeEntry();
    final entry = OverlayEntry(
      builder: (overlayContext) => _ToolbarOverlay(
        itemKey: key,
        controller: controller,
      ),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: false).insert(entry);
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Renders a single toolbar for the currently hovered item.
/// Mounted inside the [Overlay] managed by [HoverOverlay].
///
/// Receives the controller directly (instead of looking it up via
/// [HoverScope]) because the overlay entry lives in a sibling branch
/// of the widget tree that cannot reach the [HoverScope] inherited
/// from the timeline.
class _ToolbarOverlay extends StatefulWidget {
  const _ToolbarOverlay({required this.itemKey, required this.controller});

  final GlobalKey itemKey;
  final HoverOverlayController controller;

  @override
  State<_ToolbarOverlay> createState() => _ToolbarOverlayState();
}

class _ToolbarOverlayState extends State<_ToolbarOverlay> {
  static const double _toolbarWidth = 280.0;
  static const double _haloYPad = 4.0;

  /// Render rect of the active item in global coordinates.  Read in
  /// [didChangeDependencies] via a post-frame callback so the
  /// toolbar follows the item as the timeline scrolls.
  Rect? _itemRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_capture);
  }

  @override
  void didUpdateWidget(covariant _ToolbarOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemKey != widget.itemKey) {
      WidgetsBinding.instance.addPostFrameCallback(_capture);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(_capture);
  }

  void _capture(Duration _) {
    if (!mounted) return;
    // Keep polling every frame so the toolbar position tracks the
    // item during scroll.  This runs only while the overlay entry
    // is active (toolbar visible), and the guard below prevents
    // pointless setState calls when the rect is stable.
    WidgetsBinding.instance.addPostFrameCallback(_capture);

    final ctx = widget.itemKey.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached) {
      // Active item has scrolled out -- let the controller hide us.
      widget.controller.scheduleToolbarHide();
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    final next = origin & box.size;
    if (next == _itemRect) return;
    setState(() => _itemRect = next);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final rect = _itemRect;
    if (rect == null) {
      return const SizedBox.shrink();
    }

    final entry = controller.itemEntries[widget.itemKey];

    return _PositionedToolbar(
      itemRect: rect,
      itemKey: widget.itemKey,
      entry: entry,
      controller: controller,
      toolbarWidth: _toolbarWidth,
      haloYPad: _haloYPad,
    );
  }
}

/// Positions the toolbar above the active item, hosts the wide
/// hit-region [MouseRegion], and renders [MessageActions].  Pulled
/// out of [_ToolbarOverlay] so it can rebuild in isolation when
/// the active key / rect changes (the entry's `MessageActions`
/// is the only part that depends on the entry data).
class _PositionedToolbar extends StatelessWidget {
  const _PositionedToolbar({
    required this.itemRect,
    required this.itemKey,
    required this.entry,
    required this.controller,
    required this.toolbarWidth,
    required this.haloYPad,
  });

  final Rect itemRect;
  final GlobalKey itemKey;
  final HoverTargetEntry? entry;
  final HoverOverlayController controller;
  final double toolbarWidth;
  final double haloYPad;

  @override
  Widget build(BuildContext context) {
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (overlayBox is! RenderBox) return const SizedBox.shrink();
    final originInOverlay = overlayBox.globalToLocal(itemRect.topLeft);
    final overlaySize = overlayBox.size;

    final double clampedLeft =
        (originInOverlay.dx + itemRect.width - toolbarWidth).clamp(
      8.0,
      overlaySize.width - toolbarWidth - 8.0,
    );
    final double clampedTop = (originInOverlay.dy + haloYPad).clamp(
      8.0,
      overlaySize.height - 8.0,
    );

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: _ToolbarHitRegion(
        itemKey: itemKey,
        controller: controller,
        child: _ToolbarChrome(controller: controller),
      ),
    );
  }
}

/// Hosts the wide [MouseRegion] that absorbs the cursor while it
/// travels between the message body and the toolbar visual
/// region.  Wide hit-test prevents the flash by giving the
/// cursor a continuous [onEnter] path.
class _ToolbarHitRegion extends StatelessWidget {
  const _ToolbarHitRegion({
    required this.itemKey,
    required this.controller,
    required this.child,
  });

  final GlobalKey itemKey;
  final HoverOverlayController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onEnter: (_) => controller.enterToolbar(itemKey),
      onExit: (_) => controller.scheduleToolbarHide(),
      child: child,
    );
  }
}

/// Paints the toolbar's chrome + the active item's
/// [MessageActions].  Listens to the controller so it rebuilds
/// only when the active key changes (not on every pointer move).
class _ToolbarChrome extends StatelessWidget {
  const _ToolbarChrome({
    required this.controller,
  });

  final HoverOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<GlobalKey?>(
      valueListenable: controller.hoveredKey,
      builder: (context, key, _) {
        final live = key == null ? null : controller.itemEntries[key];
        return ValueListenableBuilder<bool>(
          valueListenable: controller.toolbarVisible,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            Widget body;
            if (live != null) {
              body = MessageActions(
                event: live.event,
                room: live.room,
                timeline: live.timeline,
                onReply: live.onReply ?? () {},
                onForward: live.onForward,
                onThread: live.onThread,
              );
            } else {
              body = const SizedBox.shrink();
            }
            return Container(
              width: 280,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 0.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000), // black 0.10
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Color(0x0A000000), // black 0.04
                    blurRadius: 24,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              child: body,
            );
          },
        );
      },
    );
  }
}
