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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/hover_overlay.dart';

/// Passive per-item widget that wires an item into the
/// [HoverOverlayController] without hosting a [MouseRegion].
///
/// The per-item overhead is essentially zero: the widget walks up
/// to find a [HoverScope] (without subscribing), registers its
/// [GlobalKey] + last-known render rect on every paint via a
/// post-frame callback, and holds a weak-only reference to the
/// data the toolbar needs.  The pointer hit-test runs once per
/// pointer move at the [TimelineView] root, against the
/// registered rects, so the cost of N visible items is O(N) per
/// pointer move -- no per-item hit-test state, no per-item
/// [MouseTracker] entries.
///
/// Reads the controller through [HoverScope.readOf] (not
/// [HoverScope.maybeOf]) so the item does not rebuild when the
/// controller's state changes.  The item is purely a passive
/// data source.
class HoverItem extends StatefulWidget {
  const HoverItem({
    super.key,
    required this.itemKey,
    required this.child,
    required this.event,
    required this.room,
    required this.timeline,
    this.onReply,
    this.onForward,
    this.onThread,
    this.onJumpToEvent,
  });

  final GlobalKey itemKey;
  final Widget child;
  final Event event;
  final Room room;
  final Timeline? timeline;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onThread;
  final void Function(String)? onJumpToEvent;

  @override
  State<HoverItem> createState() => _HoverItemState();
}

class _HoverItemState extends State<HoverItem> {
  /// Cached controller, looked up once per dependency change.
  /// Read via [HoverScope.readOf] so we don't subscribe the
  /// item to controller state changes (which would otherwise
  /// trigger an in-build assertion when the controller
  /// notifies mid-layout).
  HoverOverlayController? _controller;

  /// Cached entry, built lazily on first attach.  The entry is
  /// what the toolbar reads when the global hit-test resolves
  /// to this item's [GlobalKey].
  HoverTargetEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = HoverScope.readOf(context);
    if (identical(next, _controller)) return;
    if (_controller != null && _entry != null) {
      _controller!.unregisterRect(widget.itemKey);
      _controller!.unregisterEntry(widget.itemKey);
    }
    _controller = next;
    if (next != null && widget.onReply != null) {
      _entry = HoverTargetEntry(
        key: widget.itemKey,
        event: widget.event,
        room: widget.room,
        timeline: widget.timeline,
        onReply: widget.onReply,
        onForward: widget.onForward,
        onThread: widget.onThread,
        onJumpToEvent: widget.onJumpToEvent,
      );
      _controller!.registerEntry(widget.itemKey, _entry!);
    } else {
      _entry = null;
    }
  }

  @override
  void didUpdateWidget(covariant HoverItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild the entry when the toolbar-relevant inputs
    // actually changed.  Same hot-path-saving discipline used in
    // the rest of the timeline optimisation.
    final oldKey = oldWidget.itemKey;
    final newKey = widget.itemKey;
    if (oldKey == newKey &&
        oldWidget.event == widget.event &&
        oldWidget.room == widget.room &&
        oldWidget.timeline == widget.timeline &&
        oldWidget.onReply == widget.onReply &&
        oldWidget.onForward == widget.onForward &&
        oldWidget.onThread == widget.onThread &&
        oldWidget.onJumpToEvent == widget.onJumpToEvent) {
      return;
    }
    if (widget.onReply == null) {
      _entry = null;
      _controller?.unregisterEntry(oldKey);
    } else {
      _entry = HoverTargetEntry(
        key: newKey,
        event: widget.event,
        room: widget.room,
        timeline: widget.timeline,
        onReply: widget.onReply,
        onForward: widget.onForward,
        onThread: widget.onThread,
        onJumpToEvent: widget.onJumpToEvent,
      );
      _controller?.registerEntry(newKey, _entry!);
    }
  }

  @override
  void deactivate() {
    _controller?.unregisterRect(widget.itemKey);
    _controller?.unregisterEntry(widget.itemKey);
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.unregisterRect(widget.itemKey);
    _controller?.unregisterEntry(widget.itemKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No reply callback means no actions at all; skip the
    // geometry registration.  The cursor's hit-test still returns
    // null for the unregistered key, so the toolbar never lights
    // up over this item.
    if (widget.onReply == null) return widget.child;
    final controller = _controller;
    // No key is set on the probe itself — the post-frame callback
    // ([_report]) reads [widget.itemKey.currentContext] which
    // resolves to the Element of the outer [RepaintBoundary] that
    // actually bears the [GlobalKey] in the tree (set upstream in
    // [TimelineView]).  Two widgets must never share the same
    // GlobalKey; the outer boundary already holds it.
    return _HoverGeometryProbe(
      itemKey: widget.itemKey,
      controller: controller,
      child: widget.child,
    );
  }
}

/// Schedules one [addPostFrameCallback] per build to push the
/// item's render rect into the controller's registry.
///
/// Lives as a dedicated widget (instead of an inline
/// [WidgetsBinding.instance.addPostFrameCallback] in build) so the
/// subscription is tied to the widget's mount cycle and
/// Frame-callbacks don't accumulate on parent rebuilds.
class _HoverGeometryProbe extends StatefulWidget {
  const _HoverGeometryProbe({
    required this.itemKey,
    required this.controller,
    required this.child,
  });

  final GlobalKey itemKey;
  final HoverOverlayController? controller;
  final Widget child;

  @override
  State<_HoverGeometryProbe> createState() => _HoverGeometryProbeState();
}

class _HoverGeometryProbeState extends State<_HoverGeometryProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_report);
  }

  @override
  void didUpdateWidget(covariant _HoverGeometryProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-push the rect after the next frame so layout changes
    // (scroll, repaint with new constraints) are reflected.
    WidgetsBinding.instance.addPostFrameCallback(_report);
  }

  @override
  void dispose() {
    widget.controller?.unregisterRect(widget.itemKey);
    super.dispose();
  }

  void _report(Duration _) {
    final controller = widget.controller;
    if (controller == null) return;
    if (!mounted) return;

    // Resolve the render box.  In production the [itemKey] is the
    // same GlobalKey as the outer [RepaintBoundary], so
    // [itemKey.currentContext] resolves directly.  In tests where
    // no such boundary exists, fall back to the probe's own render
    // box.
    RenderBox? box;
    final keyCtx = widget.itemKey.currentContext;
    if (keyCtx != null) {
      final ro = keyCtx.findRenderObject();
      if (ro is RenderBox && ro.attached) box = ro;
    }
    if (box == null) {
      final ownBox = context.findRenderObject();
      if (ownBox is RenderBox && ownBox.attached) box = ownBox;
    }
    if (box == null) return;

    final origin = box.localToGlobal(Offset.zero);
    controller.registerRect(widget.itemKey, origin & box.size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
