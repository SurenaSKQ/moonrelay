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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/chat/thread_list_sidebar.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_members_view.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/common/status_card.dart';
import 'package:moonrelay/src/widgets/sidebar_members_list.dart';
import 'package:moonrelay/src/widgets/sidebar_pinned_messages.dart';
import 'package:moonrelay/src/widgets/compact_sidebar.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';
import 'package:moonrelay/src/widgets/navigation_pane.dart';

import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/space_rooms_tree.dart';
import 'package:moonrelay/src/widgets/spaces_pane.dart';
import 'package:moonrelay/src/widgets/status_bar.dart';
import 'package:moonrelay/src/widgets/encryption/incoming_verification_listener.dart';
import 'package:moonrelay/src/widgets/encryption/post_login_setup_checker.dart';

/// Controller widget for the multi-pane dashboard layout.
///
/// Owns transient resize state via [ValueNotifier]s (so drag updates don't
/// trigger full-tree rebuilds) and delegates the shell-decision logic to
/// [LayoutShellController] so a shell swap only re-renders the shell
/// widget, not the entire tree.
/// The actual UI is delegated to the stateless [_DashboardView] so that
/// the right sidebar receives room changes as direct props with no
/// indirection.
class DashboardLayout extends StatefulWidget {
  /// The main content widget (typically the route's child).
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  // Live drag state; exposed as ValueNotifiers so the layout shell can
  // observe them with [ListenableBuilder] without rebuilding the entire tree
  // on every drag delta.
  final ValueNotifier<double?> _leftWidth = ValueNotifier(null);
  final ValueNotifier<double?> _rightWidth = ValueNotifier(null);

  /// Owns the compact / wide / mobile shell decision. The actual
  /// shell widget rebuilds via `ListenableBuilder` against this
  /// controller, so a shell flip only invalidates the shell subtree
  /// (NavigationPane / RoomsPane / right sidebar) rather than the
  /// whole dashboard tree.
  final LayoutShellController _shell = LayoutShellController();

  @override
  void dispose() {
    _shell.dispose();
    _leftWidth.dispose();
    _rightWidth.dispose();
    super.dispose();
  }

  void _onLeftResize(double delta) {
    final settings = context.read<SettingsController>();
    final current = _leftWidth.value ?? settings.leftSidebarWidth;
    _leftWidth.value = current + delta;
  }

  void _onLeftResizeEnd() {
    final w = _leftWidth.value;
    if (w != null) {
      context.read<SettingsController>().setLeftSidebarWidth(w);
      _leftWidth.value = null;
    }
  }

  void _onRightResize(double delta) {
    final settings = context.read<SettingsController>();
    final current = _rightWidth.value ?? settings.rightSidebarWidth;
    _rightWidth.value = current - delta;
  }

  void _onRightResizeEnd() {
    final w = _rightWidth.value;
    if (w != null) {
      context.read<SettingsController>().setRightSidebarWidth(w);
      _rightWidth.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ── Shell decision with hysteresis ──────────────────────────────
        //
        // The shell decision reads the *outer* viewport width (via
        // [MediaQuery.sizeOf]) instead of the inner [LayoutBuilder]
        // constraints.  The inner constraints shrink and grow when the
        // sidebars mount or unmount  the previous implementation used
        // them as the breakpoint signal and ended up in a feedback
        // loop where toggling the right sidebar could nudge the
        // available width across the 1100 px threshold and flip the
        // shell back to compact on its own.  Anchoring to the window
        // width makes the shell decision independent of which
        // sidebars are currently mounted.
        //
        // Importantly, this builder is pure: it reads precomputed
        // state, calls a controller [update] that *may* schedule a
        // timer / fire [notifyListeners] only asynchronously, and
        // never mutates fields on this state.  Earlier revisions
        // assigned `_layoutSize` and ran `_shell.update()` synchronously
        // here, which under bursty resizes spawned
        // `_RenderLayoutBuilder was mutated in performLayout` because
        // a deferred [notifyListeners] could re-enter the tree mid-
        // layout.  Keeping the body pure eliminates that race.
        final width = MediaQuery.sizeOf(context).width;
        final layoutSize = LayoutBreakpoints.sizeForWidth(width);

        final layoutMode = context.select<SettingsController, LayoutMode>(
          (s) => s.layoutMode,
        );

        // Delegate the hysteresis/settle decision to the
        // [LayoutShellController]. The controller exposes its
        // committed size via a [ValueListenable] (the controller
        // itself is a [ChangeNotifier]) so the shell subtree
        // re-renders only when the size actually flips, not on every
        // resize tick.  Note: [_shell.update] starts / cancels timers
        // and may call [notifyListeners] but only from the Timer's
        // callback (i.e. asynchronously), never synchronously from
        // here.
        final committedSize = _shell.update(
          rawWidth: width,
          layoutMode: layoutMode,
        );
        // The dashboard always renders a compact-or-wider shell
        // here; the dedicated mobile shell is mounted at a higher
        // level by the router when needed.
        final shouldUseCompact = committedSize == LayoutSize.compact;

        return _DashboardView(
          size: layoutSize,
          width: width,
          shouldUseCompact: shouldUseCompact,
          leftWidthNotifier: _leftWidth,
          rightWidthNotifier: _rightWidth,
          onLeftResize: _onLeftResize,
          onLeftResizeEnd: _onLeftResizeEnd,
          onRightResize: _onRightResize,
          onRightResizeEnd: _onRightResizeEnd,
          child: widget.child,
        );
      },
    );
  }
}

// ─── Stateless view ───────────────────────────────────────────────────────────

/// Pure presentation widget for the dashboard layout.
///
/// Receives everything it needs as constructor props so it rebuilds
/// deterministically whenever the controller rebuilds. Drag state is observed
/// via [ListenableBuilder] scoped to the sidebar width so unrelated changes
/// don't propagate.
class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.child,
    required this.size,
    required this.width,
    required this.shouldUseCompact,
    required this.leftWidthNotifier,
    required this.rightWidthNotifier,
    required this.onLeftResize,
    required this.onLeftResizeEnd,
    required this.onRightResize,
    required this.onRightResizeEnd,
  });

  final Widget child;
  final LayoutSize size;

  /// Live viewport width. Passed in from the parent so [_DashboardView]
  /// does not need to call [MediaQuery.sizeOf] (which would subscribe it
  /// to every media-query change and rebuild on each resize tick).
  final double width;

  /// Pre-resolved compact-vs-wide decision. The controller applies
  /// hysteresis around the 1280 px boundary so this flag only flips when
  /// the resize has settled.
  final bool shouldUseCompact;
  final ValueNotifier<double?> leftWidthNotifier;
  final ValueNotifier<double?> rightWidthNotifier;
  final void Function(double) onLeftResize;
  final VoidCallback onLeftResizeEnd;
  final void Function(double) onRightResize;
  final VoidCallback onRightResizeEnd;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);

    // The compact shell is selected by the controller with hysteresis so
    // we never tear down / mount the right sidebar mid-resize. Width is
    // also passed in from the controller so we don't need to read it
    // from MediaQuery again.
    if (shouldUseCompact) {
      return _CompactDashboard(width: width, child: child);
    }

    // ── Wide shells  full multi-pane layout ───────────────────────
    // The compact shell handles everything 600-1279 wide.  Above
    // 1280px the full multi-pane layout (right sidebar visible) is
    // shown; otherwise we fall back to the compact shell again so
    // there is no "medium" gap where the sidebar disappears.
    //
    // The right sidebar's mount state is anchored to [shouldUseCompact]
    // (passed in from the controller) rather than recomputed against
    // [MediaQuery.sizeOf]. The controller applies hysteresis around the
    // 1280 px boundary so we never tear down the right sidebar mid-drag.
    final showLeft = settings.leftSidebarVisible;
    final showRight = settings.rightSidebarVisible && !shouldUseCompact;

    // In RTL mode the sidebar order must be reversed so that the
    // "left" sidebar appears on the right side of the window.
    final paneChildren = <Widget>[
      if (showLeft && !shouldUseCompact)
        _LeftPaneHost(
          widthNotifier: leftWidthNotifier,
          onResize: onLeftResize,
          onResizeEnd: onLeftResizeEnd,
          theme: theme,
        ),
      Expanded(
        child: GlobalShortcutListener(
          child: PostLoginSetupChecker(
            child: IncomingVerificationListener(
              child: child,
            ),
          ),
        ),
      ),
      if (showRight) ...[
        _ResizeHandle(
          onDrag: onRightResize,
          onDragEnd: onRightResizeEnd,
        ),
        _RightPaneHost(
          widthNotifier: rightWidthNotifier,
          theme: theme,
        ),
      ],
    ];

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutScope(
      size: size,
      availableWidth: width,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: isRtl ? paneChildren.reversed.toList() : paneChildren,
            ),
          ),
          if (settings.showStatusBar) const ApplicationStatusBar(),
        ],
      ),
    );
  }
}

// ─── Compact layout shell ────────────────────────────────────────────────────

/// Layout used when the window is too narrow to keep both side panes pinned,
/// or when the user has explicitly opted into compact mode.
///
/// Replaces the old "navigation rail + main content" layout, which left
/// the user staring at a spaces/rooms picker with no room list.  The new
/// [CompactSidebar] combines the navigation rail, the left pane, and a
/// segmented filter so the user can pick a destination and immediately
/// see something useful.
class _CompactDashboard extends StatelessWidget {
  const _CompactDashboard({
    required this.child,
    required this.width,
  });

  final Widget child;

  /// Viewport width passed in from the controller so [_CompactDashboard]
  /// does not have to call [MediaQuery.sizeOf] (which would subscribe the
  /// sidebar to every media-query change and rebuild on every resize tick).
  final double width;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    // Clamp the sidebar width exactly once per build and reuse the result
    // for both the [SizedBox] wrapper and the [CompactSidebar]'s explicit
    // width. Previously the clamp was duplicated in two places which made
    // the layout very slightly inconsistent during animated width changes.
    final sidebarWidth =
        settings.leftSidebarWidth.clamp(220.0, 360.0).toDouble();

    // In RTL mode the sidebar order must be reversed.
    final compactChildren = <Widget>[
      if (settings.leftSidebarVisible)
        SizedBox(
          width: sidebarWidth,
          child: CompactSidebar(width: sidebarWidth),
        ),
      Expanded(
        child: GlobalShortcutListener(
          child: PostLoginSetupChecker(
            child: IncomingVerificationListener(
              child: child,
            ),
          ),
        ),
      ),
    ];

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutScope(
      size: LayoutSize.compact,
      availableWidth: width,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  isRtl ? compactChildren.reversed.toList() : compactChildren,
            ),
          ),
          if (settings.showStatusBar) const ApplicationStatusBar(),
        ],
      ),
    );
  }
}

// ─── Left / right pane hosts ─────────────────────────────────────────────────

/// Hosts the left side pane (navigation rail + room list) when the layout has
/// room for a pinned sidebar.
///
/// The drag width is observed via [ListenableBuilder] so resize updates don't
/// rebuild the entire dashboard tree.
class _LeftPaneHost extends StatelessWidget {
  const _LeftPaneHost({
    required this.widthNotifier,
    required this.onResize,
    required this.onResizeEnd,
    required this.theme,
  });

  final ValueNotifier<double?> widthNotifier;
  final void Function(double) onResize;
  final VoidCallback onResizeEnd;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NavigationPane(),
        _ResizeHandle(
          onDrag: onResize,
          onDragEnd: onResizeEnd,
        ),
        ListenableBuilder(
          listenable: widthNotifier,
          builder: (context, _) {
            return _SidebarPane(
              width: widthNotifier.value ?? settings.leftSidebarWidth,
              minWidth: LayoutBreakpoints.minSidebarWidth,
              title: settings.leftPaneChoice.label,
              body: buildLeftPaneContent(context, settings.leftPaneChoice),
              bottomBar: null,
              theme: theme,
            );
          },
        ),
      ],
    );
  }
}

/// Hosts the right side pane (room info, members, threads, pinned).
class _RightPaneHost extends StatelessWidget {
  const _RightPaneHost({
    required this.widthNotifier,
    required this.theme,
  });

  final ValueNotifier<double?> widthNotifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ListenableBuilder(
      listenable: widthNotifier,
      builder: (context, _) {
        return _SidebarPane(
          width: widthNotifier.value ?? settings.rightSidebarWidth,
          minWidth: LayoutBreakpoints.minSidebarWidth,
          title: '',
          body: const _RightSidebarContent(),
          bottomBar: null,
          theme: theme,
        );
      },
    );
  }
}

// ─── Left pane content factory ───────────────────────────────────────────────

/// Builds the body of the left pane based on the user's [LeftPaneChoice] and
/// the current [NavigationState]. Pulled out so that [_CompactDashboard] and
/// [_LeftPaneHost] can share the same content widget.
Widget buildLeftPaneContent(BuildContext context, LeftPaneChoice choice) {
  switch (choice) {
    case LeftPaneChoice.rooms:
      return Consumer<NavigationState>(
        builder: (context, nav, _) {
          final Client? client;
          try {
            client = Provider.of<Client>(context, listen: false);
          } catch (_) {
            // Client may be absent during logout transition; show
            // nothing until the route changes away from the dashboard.
            return const SizedBox.shrink();
          }
          if (nav.isSpace) {
            final Room? space = client.getRoomById(nav.selectedId);
            if (space != null) {
              return SpaceRoomsPane(space: space, client: client);
            }
          }

          return RoomsPane(roomFilter: (Room room) {
            if (nav.isAll) return !room.isSpace;
            if (nav.isHome) return room.isDirectChat;
            return true;
          });
        },
      );
    case LeftPaneChoice.spaces:
      return const SpacesPane();
    case LeftPaneChoice.friends:
      // DMs only  the same list shown on the Home navigation destination.
      return RoomsPane(roomFilter: (Room room) => room.isDirectChat);
    case LeftPaneChoice.none:
      return const SizedBox.shrink();
  }
}

// ─── Right sidebar: content with view switcher ──────────────────────────────

/// Manages the right sidebar content with a built-in dropdown to switch
/// between room-info and members views.
///
/// Listens to [CurrentRoom] directly so that room changes rebuild only the
/// right sidebar body, not the surrounding dashboard shell.
class _RightSidebarContent extends StatelessWidget {
  const _RightSidebarContent();

  @override
  Widget build(BuildContext context) {
    final room = context.watch<CurrentRoom>().room;
    if (room == null) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.arrowRightFromLine,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.selectCategory,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return _RightSidebarWithSwitcher(key: ValueKey(room.id), room: room);
  }
}

/// The right sidebar body with a segmented/dropdown switcher at the top.
class _RightSidebarWithSwitcher extends StatelessWidget {
  const _RightSidebarWithSwitcher({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final choice = settings.rightPaneChoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── View switcher header ──────────────────────────────────
        _RightSidebarHeader(
          currentChoice: choice,
          onChanged: (c) => settings.setRightPaneChoice(c),
        ),
        const Divider(height: 1),
        // ── Content ───────────────────────────────────────────────
        Expanded(
          child: switch (choice) {
            RightPaneChoice.none => const SizedBox.shrink(),
            RightPaneChoice.roomInfo => _SidebarRoomInfo(room: room),
            RightPaneChoice.members =>
              SidebarMembersList(key: ValueKey(room.id), room: room),
            RightPaneChoice.threads =>
              SidebarThreadList(key: ValueKey(room.id), room: room),
            RightPaneChoice.pinned =>
              SidebarPinnedMessages(key: ValueKey(room.id), room: room),
          },
        ),
      ],
    );
  }
}

/// A compact header bar with a dropdown to switch between room-info and
/// members views.
class _RightSidebarHeader extends StatelessWidget {
  const _RightSidebarHeader({
    required this.currentChoice,
    required this.onChanged,
  });

  final RightPaneChoice currentChoice;
  final void Function(RightPaneChoice) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Selected view icon
          Icon(
            switch (currentChoice) {
              RightPaneChoice.roomInfo => LucideIcons.info,
              RightPaneChoice.members => LucideIcons.users,
              RightPaneChoice.threads => LucideIcons.messageSquare,
              RightPaneChoice.pinned => Icons.push_pin_outlined,
              RightPaneChoice.none => LucideIcons.panelRight,
            },
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          // Dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RightPaneChoice>(
                value: currentChoice,
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
                items: [
                  DropdownMenuItem(
                    value: RightPaneChoice.roomInfo,
                    child: Text('Room Info'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.members,
                    child: Text('Members'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.threads,
                    child: Text('Threads'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.pinned,
                    child: Text('Pinned'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.none,
                    child: Text('None'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Room Info sidebar content ───────────────────────────────────────────────

/// Shows a concise room-information panel in the right sidebar.
///
/// All derived strings (display name, topic, room type, canonical alias,
/// encryption flag, member count) are recomputed only when the room's
/// state actually changes  not on every parent rebuild. Previously every
/// parent build called `room.getLocalizedDisplayname()`,
/// `room.summary.mJoinedMemberCount`, `room.joinRules`, etc., which do
/// non-trivial SDK work; during a window resize the entire sidebar rebuilt
/// dozens of times per second. The cached fields also let the parent's
/// rebuild (e.g. from a `CurrentRoom` notification) skip the expensive
/// recompute when nothing relevant has changed.
class _SidebarRoomInfo extends StatefulWidget {
  const _SidebarRoomInfo({required this.room});

  final Room room;

  @override
  State<_SidebarRoomInfo> createState() => _SidebarRoomInfoState();
}

class _SidebarRoomInfoState extends State<_SidebarRoomInfo> {
  // ── Cached derived state ─────────────────────────────────────────
  // Each field is paired with a `_last*` value so the state-event
  // listener can do a no-op setState when nothing visible actually
  // changed (the room can emit many state events per minute; we only
  // need to rebuild when one of the user-facing fields actually moves).
  String _displayName = '';
  String _topic = '';
  int _memberCount = 0;
  String _roomType = '';
  String _canonicalAlias = '';
  bool _encrypted = false;

  @override
  void initState() {
    super.initState();
    // Listen to the shared room-state bus instead of subscribing
    // directly to the client's onRoomState stream. The bus is one
    // O(N) stream filter per state event regardless of how many
    // subscribers there are; the previous per-widget subscription
    // cost O(subscribers) per state event.
    _bindRoomStateBus();
  }

  /// Subscribes to the room-state bus and re-binds when the room id
  /// changes. The bus is provided by the app shell so we don't have
  /// to instantiate a new one per sidebar.
  void _bindRoomStateBus() {
    // No-op; didChangeDependencies wires the listener.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshFromRoom(force: true);
  }

  @override
  void didUpdateWidget(_SidebarRoomInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      // Room changed (right sidebar re-mounted): the bus tick is
      // already keyed by room id, so listeners automatically pick
      // up the new room.
      _refreshFromRoom(force: true);
    }
  }

  @override
  void dispose() {
    // The bus outlives this widget; we don't cancel the subscription
    // here. The bus drops per-room state when the room is left.
    super.dispose();
  }

  /// Refreshes the cached fields from the underlying room. Only
  /// called when the room-state bus ticks; cheap when nothing
  /// actually changed. Returns `true` when at least one field
  /// differs from the previous value (a rebuild is needed).
  bool _refreshFromRoom({required bool force}) {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;
    final nextDisplayName = room.getLocalizedDisplayname();
    final nextTopic = room.topic;
    final nextMemberCount = (room.summary.mJoinedMemberCount ?? 0) +
        (room.summary.mInvitedMemberCount ?? 0);
    final nextRoomType = room.isDirectChat
        ? l10n.directMessage
        : room.isSpace
            ? l10n.spaceType
            : room.joinRules == JoinRules.public
                ? l10n.publicRoom
                : room.joinRules == JoinRules.knock ||
                        room.joinRules == JoinRules.knockRestricted
                    ? l10n.roomTypeKnock
                    : room.joinRules == JoinRules.restricted
                        ? l10n.roomTypeRestricted
                        : l10n.roomTypeInviteOnly;
    final nextAlias = room.canonicalAlias;
    final nextEncrypted = room.encrypted;

    if (!force &&
        nextDisplayName == _displayName &&
        nextTopic == _topic &&
        nextMemberCount == _memberCount &&
        nextRoomType == _roomType &&
        nextAlias == _canonicalAlias &&
        nextEncrypted == _encrypted) {
      return false;
    }

    _displayName = nextDisplayName;
    _topic = nextTopic;
    _memberCount = nextMemberCount;
    _roomType = nextRoomType;
    _canonicalAlias = nextAlias;
    _encrypted = nextEncrypted;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the room-state bus so this widget only rebuilds
    // when this specific room emits a state event. Subscribers for
    // other rooms do not affect us.
    final bus = context.read<RoomStateBus>();
    return ValueListenableBuilder<int>(
      valueListenable: bus.tickFor(widget.room.id),
      builder: (context, _, __) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Adapt padding and avatar radius to the pane width. Narrow panes get a
    // tighter layout so the header doesn't dominate the view.
    //
    // Read the width from [LayoutScope] (already provided by the dashboard
    // controller) rather than [MediaQuery.sizeOf]. The latter subscribes to
    // *every* MediaQuery change across the app and rebuilds on unrelated
    // changes like keyboard show/hide; LayoutScope only fires on actual
    // layout-pass width changes scoped to this subtree.
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = LayoutScope.of(context).availableWidth;
    final compactPane = width < 240;
    final outerPadding = compactPane ? 12.0 : 16.0;
    final avatarRadius = compactPane ? 28.0 : 36.0;
    final nameFontSize = compactPane ? 16.0 : 18.0;
    final topicText = _topic.isNotEmpty ? _topic : l10n.noTopicSet;

    return SingleChildScrollView(
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room avatar + name
          Center(
            child: Column(
              children: [
                AvatarFromUriOrFallbackImage(
                  client: widget.room.client,
                  avatarUri: widget.room.avatar,
                  radius: avatarRadius,
                ),
                const SizedBox(height: 12),
                Text(
                  _displayName,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(height: outerPadding),

          // Topic
          _InfoRow(
            icon: LucideIcons.alignLeft,
            label: topicText,
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // Room type
          _InfoRow(
            icon: LucideIcons.hash,
            label: _roomType,
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // Room ID
          _InfoRow(
            icon: LucideIcons.tag,
            label: widget.room.id,
            scheme: scheme,
            mono: true,
          ),
          const SizedBox(height: 8),

          // Member count
          _InfoRow(
            icon: LucideIcons.users,
            label: l10n.membersCount(_memberCount),
            scheme: scheme,
          ),
          if (_canonicalAlias.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: LucideIcons.atSign,
              label: _canonicalAlias,
              scheme: scheme,
              mono: true,
            ),
          ],

          const SizedBox(height: 24),

          // Encryption status
          StatusCard(
            icon: _encrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            label: _encrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            color: _encrypted ? scheme.primary : scheme.error,
            scheme: scheme,
          ),

          const SizedBox(height: 24),

          // ── Pinned messages section ─────────────────────────────────
          _PinnedSection(room: widget.room),
        ],
      ),
    );
  }
}

/// A single key-value row in the room-info sidebar.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.scheme,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontFamily: mono ? 'JetBrainsMono' : null,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Members list sidebar content (standalone, no Scaffold/AppBar) ───────────

/// A standalone members-list widget designed for the right sidebar.
///
/// Duplicates the progressive-loading logic from [FullRoomMembersList] but
/// without any Scaffold or AppBar  just a search bar and a scrollable list
/// of members.  This avoids the destructive back-button that would otherwise
/// appear when using [FullRoomMembersList] directly inside a sidebar.
class _SidebarMembersList extends StatefulWidget {
  const _SidebarMembersList({required this.room});

  final Room room;

  @override
  State<_SidebarMembersList> createState() => _SidebarMembersListState();
}

class _SidebarMembersListState extends State<_SidebarMembersList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  /// Debounce window for the search box. Typing at 8 keys/sec otherwise
  /// caused 8 full-list rebuilds per second, each calling `calcDisplayname`
  /// for every member. Coalescing here keeps the cost at one rebuild per
  /// quiet keystroke instead.
  static const Duration _searchDebounce = Duration(milliseconds: 120);
  Timer? _searchDebounceTimer;

  static const int _batchSize = 50;
  static const int _fetchBatchSize = 10;

  List<User> _allMembers = [];
  int _displayedCount = 0;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  Object? _loadError;

  /// Per-user display name cache. `calcDisplayname` does string-building
  /// work on every call (display name fallbacks + mxc resolution), and the
  /// members list rebuilds on every search keystroke, scroll batch, or
  /// sync tick  so recomputing the same name on every item render was
  /// the dominant cost of the member pane. We invalidate the cache when
  /// the underlying member set changes (room switch, fresh fetch).
  final Map<String, String> _displayNameCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchLocalThenRemote();
  }

  @override
  void didUpdateWidget(_SidebarMembersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      // Room changed  reset everything and build from scratch.
      _searchController.clear();
      _searchQuery = '';
      _searchDebounceTimer?.cancel();
      _displayedCount = 0;
      _allMembers = [];
      _displayNameCache.clear();
      _isLoading = true;
      _isFetchingMore = false;
      _loadError = null;
      _fetchLocalThenRemote();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Coalesce rapid keystrokes so the filtered list (which calls
    // `calcDisplayname` for every member) only rebuilds once the user
    // pauses. Without this, each keystroke re-renders every visible tile.
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (_displayedCount >= _allMembers.length) return;
    if (!_scrollController.hasClients) return;
    // Trigger pre-fetch when within ~3 rows of the end so the user never sees
    // the bottom of the list. The threshold scales with the row height to
    // remain responsive at any pane size.
    final viewport = _scrollController.position.viewportDimension;
    final threshold = (viewport * 0.5).clamp(120.0, 400.0);
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - threshold) {
      return;
    }
    _loadNextBatch();
  }

  void _loadNextBatch() {
    if (_displayedCount >= _allMembers.length) return;
    setState(() {
      _displayedCount =
          (_displayedCount + _batchSize).clamp(0, _allMembers.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_displayedCount >= _allMembers.length) return;
      if (_searchQuery.isNotEmpty) return;
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <=
              _scrollController.position.viewportDimension + 32) {
        _loadNextBatch();
      }
    });
  }

  Future<void> _fetchLocalThenRemote() async {
    final roomId = widget.room.id;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _displayedCount = 0;
      _allMembers = [];
      // The member set is being rebuilt  discard any cached display names
      // so we don't leak stale entries from the previous room.
      _displayNameCache.clear();
    });

    final localParticipants = widget.room.getParticipants().toList()
      ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

    _allMembers = List.from(localParticipants);
    if (mounted && widget.room.id == roomId) {
      setState(() {
        _isLoading = false;
        _displayedCount = _allMembers.isNotEmpty
            ? _batchSize.clamp(0, _allMembers.length)
            : 0;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.room.id != roomId) return;
      if (_displayedCount < _allMembers.length) _loadNextBatch();
    });

    try {
      _isFetchingMore = true;
      final joinedMembers =
          await widget.room.client.getJoinedMembersByRoom(widget.room.id);
      if (!mounted ||
          widget.room.id != roomId ||
          joinedMembers == null ||
          joinedMembers.isEmpty) {
        return;
      }

      // Build the seen-IDs set lazily so we don't allocate it twice. The
      // previous implementation rebuilt it on every batch.
      var seen = _allMembers.isEmpty
          ? const <String>{}
          : _allMembers.map((u) => u.id).toSet();
      final missingMxids = seen.isEmpty
          ? joinedMembers.keys.toList()
          : joinedMembers.keys.where((id) => !seen.contains(id)).toList();
      if (missingMxids.isEmpty) {
        if (mounted && widget.room.id == roomId) {
          setState(() => _isFetchingMore = false);
        }
        return;
      }

      // Make a mutable copy of the seen set now that we know we'll insert.
      seen = seen.isEmpty ? <String>{} : Set<String>.from(seen);

      for (int i = 0; i < missingMxids.length; i += _fetchBatchSize) {
        final batch = missingMxids.sublist(
          i,
          (i + _fetchBatchSize).clamp(0, missingMxids.length),
        );
        final results = await Future.wait(
          batch.map((mxid) => _fetchUser(mxid, joinedMembers)),
        );
        if (!mounted || widget.room.id != roomId) return;

        final newUsers = <User>[];
        for (final user in results.whereType<User>()) {
          if (seen.add(user.id)) newUsers.add(user);
        }

        if (newUsers.isEmpty) continue;
        // Insertion sort: the list is already roughly sorted by power level,
        // so binary-search insertion keeps the operation near O(N log N)
        // instead of O(N^2) for a full re-sort.
        for (final user in newUsers) {
          _insertSortedByPowerLevel(_allMembers, user);
        }

        if (mounted && widget.room.id == roomId) {
          setState(() {
            _displayedCount = (_displayedCount + newUsers.length)
                .clamp(0, _allMembers.length);
          });
        }
      }
    } catch (_) {
      // Silently swallow – local data is already shown.
    }
    if (mounted && widget.room.id == roomId) {
      setState(() => _isFetchingMore = false);
    }
  }

  /// Inserts [user] into [list] preserving the descending-power-level order.
  /// Uses a binary search to find the insertion index in O(log N).
  static void _insertSortedByPowerLevel(List<User> list, User user) {
    var lo = 0;
    var hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].powerLevel.level > user.powerLevel.level) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    list.insert(lo, user);
  }

  Future<User?> _fetchUser(
    String mxid,
    Map<String, RoomMember> joinedMembers,
  ) async {
    try {
      return await widget.room.requestUser(mxid);
    } catch (_) {
      final info = joinedMembers[mxid];
      if (info == null) return null;
      return User(
        mxid,
        room: widget.room,
        displayName: info.displayName,
        avatarUrl: info.avatarUrl?.toString(),
      );
    }
  }

  /// Returns the display name for [user], caching the result so the same
  /// member doesn't trigger the matrix SDK's fallback chain on every
  /// build. The cache is keyed by `user.id` and invalidated alongside
  /// `_allMembers` in [_fetchLocalThenRemote] / [didUpdateWidget].
  String _displayNameFor(User user) {
    final cached = _displayNameCache[user.id];
    if (cached != null) return cached;
    final fresh = user.calcDisplayname();
    _displayNameCache[user.id] = fresh;
    return fresh;
  }

  List<User> get _visibleMembers {
    if (_searchQuery.isNotEmpty) {
      return _allMembers.where((m) {
        // Reuse the cached display name when possible  the previous
        // implementation called `calcDisplayname()` for *every* member on
        // every keystroke, which made typing into the search box the most
        // expensive operation in the sidebar.
        final dn = _displayNameFor(m).toLowerCase();
        final uid = m.id.toLowerCase();
        return dn.contains(_searchQuery) || uid.contains(_searchQuery);
      }).toList();
    }
    return _allMembers.take(_displayedCount).toList();
  }

  bool get _hasMore =>
      _searchQuery.isEmpty && _displayedCount < _allMembers.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchMembers,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: _isLoading
              ? _buildLoading(scheme)
              : _loadError != null && _allMembers.isEmpty
                  ? _buildError(scheme)
                  : _buildList(scheme),
        ),
      ],
    );
  }

  Widget _buildLoading(ColorScheme scheme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.loading,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );

  Widget _buildError(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertCircle, size: 40, color: scheme.error),
          const SizedBox(height: 12),
          Text(l10n.couldNotLoadMessages,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _fetchLocalThenRemote,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme scheme) {
    final members = _visibleMembers;
    final l10n = AppLocalizations.of(context)!;

    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.users,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? l10n.noMembersMatchSearch
                  : l10n.noMembersFound,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final showIndicator = _isFetchingMore || _hasMore;
    final itemCount = members.length + (showIndicator ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _fetchLocalThenRemote,
      child: Scrollbar(
        controller: _scrollController,
        // Keep the bar hidden until the user actually scrolls so it doesn't
        // steal width from a narrow pane.
        thumbVisibility: false,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= members.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
              );
            }

            final member = members[index];
            final displayName = _displayNameFor(member);
            final permissionLabel = member.powerLevel.level >= 100
                ? l10n.adminBadge
                : member.powerLevel.level >= 50
                    ? l10n.moderatorBadge
                    : null;

            return _SidebarMemberTile(
              member: member,
              displayName: displayName,
              permissionLabel: permissionLabel,
              scheme: scheme,
            );
          },
        ),
      ),
    );
  }
}

/// A compact member tile for sidebar use (same as _FullMemberTile but without
/// the full-page context menu navigation since the sidebar context differs).
class _SidebarMemberTile extends StatelessWidget {
  const _SidebarMemberTile({
    required this.member,
    required this.displayName,
    this.permissionLabel,
    required this.scheme,
  });

  final User member;
  final String displayName;
  final String? permissionLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final membershipLabel = switch (member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: AvatarFromUriOrFallbackImage(
                client: member.room.client,
                avatarUri: member.avatarUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (permissionLabel != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            permissionLabel!,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (membershipLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  membershipLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 160,
        offset.dy,
        offset.dx + 320,
        offset.dy + 60,
      ),
      items: [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(AppLocalizations.of(context)!.viewProfile),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'message',
          child: ListTile(
            leading: const Icon(Icons.chat_rounded),
            title: Text(AppLocalizations.of(context)!.sendMessage),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((v) {
      if (v == null || !context.mounted) return;
      switch (v) {
        case 'profile':
          showProfileOverlay(
            context,
            userId: member.id,
            room: member.room,
          );
        case 'message':
          final log = context.read<Logger>();
          final l10n = AppLocalizations.of(context)!;
          withRetry(
            () => member.startDirectChat(),
            maxRetries: 1,
            timeout: kDefaultTimeout,
            log: log,
            label: 'startDirectChat',
          ).then((result) {
            if (!context.mounted) return;
            switch (result) {
              case RetrySuccess(:final value):
                GoRouter.of(context).go('/main/rooms/$value');
              case RetryFailed(:final error):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error is TimeoutException
                          ? l10n.couldNotStartChatTimeout
                          : l10n.couldNotStartChat('$error'),
                    ),
                  ),
                );
            }
          });
      }
    });
  }
}

// ─── Internal dashboard-layout widgets ───────────────────────────────────────

/// A draggable resize handle between panes.
class _ResizeHandle extends StatelessWidget {
  final void Function(double delta) onDrag;
  final VoidCallback? onDragEnd;

  const _ResizeHandle({
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Wider hit target (8px) so the handle is easier to grab on small panes,
    // with a subtle always-visible track.
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: Container(
          width: 8,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// A sidebar pane with a header, scrollable body, and optional bottom bar.
class _SidebarPane extends StatelessWidget {
  final double width;
  final double minWidth;
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final ThemeData theme;

  const _SidebarPane({
    required this.width,
    required this.minWidth,
    required this.title,
    required this.body,
    this.bottomBar,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.clamp(minWidth, double.infinity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simple header bar  collapse toggle lives in AppFrame now.
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
          if (bottomBar != null) ...[
            const Divider(height: 1),
            bottomBar!,
          ],
        ],
      ),
    );
  }
}

// ─── Pinned messages section (embedded in room info) ─────────────────────────

/// A compact pinned-messages section rendered inside the room-info sidebar.
///
/// Shows a header with pin count and a list of pinned message previews.
/// Tapping a preview filters the timeline to show only pinned messages.
class _PinnedSection extends StatefulWidget {
  const _PinnedSection({required this.room});

  final Room room;

  @override
  State<_PinnedSection> createState() => _PinnedSectionState();
}

class _PinnedSectionState extends State<_PinnedSection> {
  Map<String, Event> _pinnedEvents = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedEvents();
  }

  @override
  void didUpdateWidget(_PinnedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _loadPinnedEvents();
    }
  }

  Future<void> _loadPinnedEvents() async {
    final r = widget.room;
    final state = r.getState('m.room.pinned_events');
    final pinnedList = state?.content['pinned'];
    final pinnedIds =
        pinnedList is List ? pinnedList.cast<String>() : <String>[];

    // Try to look up events from the timeline first (no network needed), then
    // fall back to the shared cache, then to the server via the cache itself.
    final Map<String, Event> result = {};
    final missingFromTimeline = <String>[];
    try {
      final timeline = await r.getTimeline();
      for (final id in pinnedIds) {
        final event = timeline.events.where((e) => e.eventId == id).firstOrNull;
        if (event != null) {
          result[id] = event;
        } else {
          missingFromTimeline.add(id);
        }
      }
    } catch (_) {
      // Timeline not available  fall through to the cache/server for all.
      missingFromTimeline
        ..clear()
        ..addAll(pinnedIds);
    }

    if (missingFromTimeline.isNotEmpty) {
      final fetched = await Future.wait(missingFromTimeline
          .map((id) => PinnedEventsCache.instance.getEvent(r, id)));
      for (var i = 0; i < missingFromTimeline.length; i++) {
        final ev = fetched[i];
        if (ev != null) result[missingFromTimeline[i]] = ev;
      }
    }

    if (!mounted) return;
    setState(() {
      _pinnedEvents = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final currentRoom = context.watch<CurrentRoom>();

    final state = widget.room.getState('m.room.pinned_events');
    final pinnedList = state?.content['pinned'];
    final pinnedIds =
        pinnedList is List ? pinnedList.cast<String>() : <String>[];
    final count = pinnedIds.length;

    // Show fewer previews when the pane is narrow so they don't dominate.
    //
    // Read the width from [LayoutScope] (already provided by the dashboard
    // controller) rather than [MediaQuery.sizeOf]. The latter subscribes to
    // *every* MediaQuery change across the app and rebuilds on unrelated
    // changes like keyboard show/hide; LayoutScope only fires on actual
    // layout-pass width changes scoped to this subtree.
    final paneWidth = LayoutScope.of(context).availableWidth;
    final previewCount = paneWidth < 240 ? 1 : (paneWidth < 320 ? 2 : 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ─────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (count > 0) {
              final settings = context.read<SettingsController>();
              settings.setRightPaneChoice(RightPaneChoice.pinned);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 16,
                  color: currentRoom.pinnedFilterActive
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pinnedMessages,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (count == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noPinnedMessages,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          )
        else if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          )
        else
          ...pinnedIds.take(previewCount).map((eventId) {
            return _PinnedPreview(
              room: widget.room,
              eventId: eventId,
              event: _pinnedEvents[eventId],
              scheme: scheme,
              l10n: l10n,
            );
          }),
        if (count > previewCount) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              final settings = context.read<SettingsController>();
              settings.setRightPaneChoice(RightPaneChoice.pinned);
            },
            child: Text(
              l10n.pinnedMessagesCount(count),
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
          ),
        ],
      ],
    );
  }
}

/// A one-line preview of a pinned event used inside the room-info sidebar.
class _PinnedPreview extends StatelessWidget {
  const _PinnedPreview({
    required this.room,
    required this.eventId,
    this.event,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final String eventId;
  final Event? event;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final senderName =
        event?.senderFromMemoryOrFallback.calcDisplayname() ?? '…';
    final body = event?.body.isNotEmpty == true
        ? event!.body.replaceAll('\n', ' ')
        : '…';

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        context.read<CurrentRoom>().togglePinnedFilter();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.push_pin_outlined,
              size: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pinned messages sidebar (full pane) ─────────────────────────────────────

/// Full sidebar pane that lists all pinned messages for the room.
class _SidebarPinnedMessages extends StatefulWidget {
  const _SidebarPinnedMessages({required this.room});

  final Room room;

  @override
  State<_SidebarPinnedMessages> createState() => _SidebarPinnedMessagesState();
}

class _SidebarPinnedMessagesState extends State<_SidebarPinnedMessages> {
  Map<String, Event> _pinnedEvents = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedEvents();
  }

  @override
  void didUpdateWidget(_SidebarPinnedMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _loadPinnedEvents();
    }
  }

  Future<void> _loadPinnedEvents() async {
    final r = widget.room;
    final state = r.getState('m.room.pinned_events');
    final pinnedList = state?.content['pinned'];
    final pinnedIds =
        pinnedList is List ? pinnedList.cast<String>() : <String>[];

    final Map<String, Event> result = {};
    if (pinnedIds.isNotEmpty) {
      // Fetch all pinned events in parallel via the shared cache. Concurrent
      // calls for the same event dedupe automatically.
      final fetched = await Future.wait(
        pinnedIds.map((id) => PinnedEventsCache.instance.getEvent(r, id)),
      );
      for (var i = 0; i < pinnedIds.length; i++) {
        final ev = fetched[i];
        if (ev != null) result[pinnedIds[i]] = ev;
      }
    }

    if (!mounted) return;
    setState(() {
      _pinnedEvents = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final currentRoom = context.watch<CurrentRoom>();

    final state = widget.room.getState('m.room.pinned_events');
    final pinnedList = state?.content['pinned'];
    final pinnedIds =
        pinnedList is List ? pinnedList.cast<String>() : <String>[];

    if (pinnedIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noPinnedMessages,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    return Column(
      children: [
        // ── Filter toggle bar ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: FilledButton.tonalIcon(
            onPressed: () => currentRoom.togglePinnedFilter(),
            icon: Icon(
              currentRoom.pinnedFilterActive
                  ? Icons.push_pin_outlined
                  : Icons.visibility_outlined,
              size: 16,
            ),
            label: Text(
              currentRoom.pinnedFilterActive
                  ? l10n.showAllMessages
                  : l10n.showPinnedOnly,
              style: const TextStyle(fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: currentRoom.pinnedFilterActive
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              foregroundColor: currentRoom.pinnedFilterActive
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: pinnedIds.length,
            itemBuilder: (context, index) {
              final eventId = pinnedIds[index];
              return _SidebarPinnedTile(
                room: widget.room,
                eventId: eventId,
                event: _pinnedEvents[eventId],
                scheme: scheme,
                l10n: l10n,
                currentRoom: currentRoom,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single pinned message tile in the full pinned sidebar.
class _SidebarPinnedTile extends StatelessWidget {
  const _SidebarPinnedTile({
    required this.room,
    required this.eventId,
    this.event,
    required this.scheme,
    required this.l10n,
    required this.currentRoom,
  });

  final Room room;
  final String eventId;
  final Event? event;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final CurrentRoom currentRoom;

  @override
  Widget build(BuildContext context) {
    final senderName =
        event?.senderFromMemoryOrFallback.calcDisplayname() ?? 'Unknown';
    final body = event?.body.isNotEmpty == true ? event!.body : '(no content)';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: currentRoom.pinnedFilterActive &&
              currentRoom.pinnedEventIds.contains(eventId)
          ? scheme.primaryContainer.withValues(alpha: 0.3)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => currentRoom.togglePinnedFilter(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
