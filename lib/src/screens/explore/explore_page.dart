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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart' hide Visibility;
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/screens/room_directory_search.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/create_room_form/create_room_form.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/widgets/user_search_widget.dart';
import 'package:provider/provider.dart';

/// Which half of the page is open.
enum ExploreMode {
  create,
  find;

  /// Which half a legacy path means.
  ///
  /// `/main/newroom` and `/main/newspace` were one page behind a flag, and
  /// both of them mean "the create form", so both land on [create]. The space
  /// toggle inside the form is the user's choice to make, not something the
  /// route should decide for them.
  static ExploreMode fromPath(String? path) {
    if (path == null) return ExploreMode.find;
    if (path.endsWith('newroom') || path.endsWith('newspace')) {
      return ExploreMode.create;
    }
    return ExploreMode.find;
  }
}

/// The one page for making or finding a room or a space.
///
/// This replaces three destinations that were one question asked three ways.
/// `/main/newroom` and `/main/newspace` were a single page behind a flag, and
/// `/main/addroom` was a separate four-tab page whose third tab was the same
/// create form again. Worse, the two `+` buttons in the shell pointed at
/// *different* ones: the rail's could only create a space and the room list's
/// could only create a room, so the same gesture in two adjacent columns did
/// two different things and neither could reach the other.
///
/// The shape is two questions, and the answer to the second is a filter rather
/// than a separate page:
///
/// - **Create** is one form, because a room and a space are the same call with
///   one flag, and the form already toggles between them.
/// - **Find** is one directory under three filters. Rooms and spaces come from
///   the same endpoint and are told apart by `room_type`, so looking for a
///   space is the same request filtered over the response rather than a
///   different screen.
///
/// Joining by ID or alias sits below the search rather than beside it. It is
/// the escape hatch for the room whose name you already know, so it belongs
/// after the search rather than competing with it for a tab.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.initialMode});

  /// Which half to open on. Null means read it from the route's query, so the
  /// deep link /main/explore?mode=create opens on the form and the plain
  /// /main/explore opens on the directory.
  final ExploreMode? initialMode;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late ExploreMode _mode = _resolveInitialMode();

  /// Reads the mode from the explicit argument, then the route query, then
  /// defaults to the directory.
  ///
  /// The query is the one that matters for a deep link, and it is read rather
  /// than passed through the router's builder because the legacy paths are
  /// redirects: by the time this page builds, the route is already
  /// `/main/explore` and the old path is gone.
  ExploreMode _resolveInitialMode() {
    final explicit = widget.initialMode;
    if (explicit != null) return explicit;
    final query = GoRouterState.of(context).uri.queryParameters['mode'];
    if (query == 'create') return ExploreMode.create;
    return ExploreMode.find;
  }

  late _FindKind _kind = _FindKind.rooms;

  final TextEditingController _joinController = TextEditingController();
  bool _showJoinById = false;
  bool _joining = false;
  String? _joinError;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text(l10n.exploreTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: MoonrelayInfoPage.maxContentWidth),
          // A `Column` with an `Expanded` below, not a `ListView`.
          //
          // The directory search scrolls its own results and reaches for
          // `Expanded` to fill what it is given, which inside a `ListView` is
          // an unbounded height and throws "RenderFlex children have non-zero
          // flex but incoming height constraints are unbounded" the moment
          // the page opens. The create half does want to scroll, so it gets its
          // own `SingleChildScrollView` rather than making the Find half
          // scrollable too and giving up the bounded box it needs.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spaceLg,
                  t.spaceMd,
                  t.spaceLg,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Two questions, not five destinations. A segmented
                    // control rather than an app-bar tab bar, because the two
                    // answers have different shapes and a tab bar would imply
                    // they are peers in a list, which is exactly what the old
                    // four-tab page implied.
                    SegmentedButton<ExploreMode>(
                      segments: [
                        ButtonSegment<ExploreMode>(
                          value: ExploreMode.create,
                          icon: const Icon(LucideIcons.plus, size: 18),
                          label: Text(l10n.exploreCreateTab),
                        ),
                        ButtonSegment<ExploreMode>(
                          value: ExploreMode.find,
                          icon: const Icon(LucideIcons.search, size: 18),
                          label: Text(l10n.exploreFindTab),
                        ),
                      ],
                      selected: {_mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (next) =>
                          setState(() => _mode = next.first),
                    ),
                    SizedBox(height: t.spaceLg),
                  ],
                ),
              ),
              Expanded(
                child: _mode == ExploreMode.create
                    ? const SingleChildScrollView(child: CreateRoomWidget())
                    : _buildFind(context, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFind(BuildContext context, AppLocalizations l10n) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FindFilterBar(
          kind: _kind,
          onChanged: (next) => setState(() => _kind = next),
        ),
        SizedBox(height: t.spaceMd),
        // Keyed on the filter so switching tabs discards the previous list
        // rather than showing rooms under a heading that says spaces. The
        // request is the same either way; only what is kept from it changes.
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_kind),
            child: switch (_kind) {
              _FindKind.people => const UserSearchWidget(embedded: true),
              _FindKind.rooms || _FindKind.spaces => RoomDirectorySearch(
                  embedded: true,
                  kindFilter: _kind == _FindKind.spaces
                      ? DirectoryKindFilter.spaces
                      : DirectoryKindFilter.rooms,
                  onJoined: (_) => Navigator.of(context).maybePop(),
                ),
            },
          ),
        ),
        // Joining by id applies to rooms, not to people, so it is hidden
        // under the People filter rather than sitting there doing nothing.
        if (_kind != _FindKind.people) SizedBox(height: t.spaceLg),
        if (_kind != _FindKind.people && _showJoinById)
          _buildJoinById(context, l10n)
        else if (_kind != _FindKind.people)
          InfoPanel(
            children: [
              InfoPanelRow(
                icon: LucideIcons.hash,
                label: l10n.exploreJoinById,
                onTap: () => setState(() => _showJoinById = true),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildJoinById(BuildContext context, AppLocalizations l10n) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return InfoPanel(
      title: l10n.exploreJoinById,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: t.spaceSm),
          child: TextField(
            controller: _joinController,
            enabled: !_joining,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.roomIdOrAlias,
              errorText: _joinError,
              isDense: true,
            ),
            onSubmitted: (_) => _joinById(),
          ),
        ),
        InfoPanelRow(
          icon: LucideIcons.logIn,
          label: l10n.joinRoom,
          destructive: true,
          onTap: _joining ? null : _joinById,
          trailing: _joining
              ? SizedBox(
                  width: t.iconSizeSmall,
                  height: t.iconSizeSmall,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ],
    );
  }

  /// Joins [_joinController]'s contents as a room id or an alias.
  ///
  /// Takes no BuildContext on purpose: it reads 	his.context, so the
  /// mounted check below guards the same context the later reads use. A
  /// passed-in context made the analyzer treat the two as unrelated.
  Future<void> _joinById() async {
    final target = _joinController.text.trim();
    if (target.isEmpty) return;

    final client = context.read<Client>();
    final log = context.read<Logger>();
    setState(() {
      _joining = true;
      _joinError = null;
    });

    final result = await withRetry(
      // No server hint: the alias form carries its own. Same call the old
      // join-by-id tab made.
      () => client.joinRoom(target, via: const <String>[]),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'joinRoom',
    );

    if (!mounted) return;
    switch (result) {
      case RetrySuccess(:final value):
        setState(() => _joining = false);
        // The router is looked up here rather than captured before the await:
        // `mounted` is the State's, and this is a `State.context` use, so the
        // guard above is the right one and capturing early would only make the
        // navigator outlive the widget if the join took a minute.
        context.go(MoonRoutePaths.roomChatPath(value));
      case RetryFailed(:final error):
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _joining = false;
          // The homeserver's own wording is the useful part here: "Unknown
          // room" and "not allowed" are different problems and a generic
          // "could not join" throws that away.
          _joinError = error is TimeoutException
              ? l10n.couldNotJoinRoomTimeout
              : l10n.couldNotJoinRoom('$error');
        });
    }
  }
}

/// What the Find half is looking for.
///
/// Rooms and spaces are the same directory with a filter over the response.
/// People are not in the directory at all, so they are a separate widget
/// behind the same switch rather than a third value on
/// [DirectoryKindFilter], which would have made that enum lie about what it
/// filters.
enum _FindKind { rooms, spaces, people }

/// The filter row above the results.
class _FindFilterBar extends StatelessWidget {
  const _FindFilterBar({required this.kind, required this.onChanged});

  final _FindKind kind;
  final ValueChanged<_FindKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<_FindKind>(
      segments: [
        ButtonSegment<_FindKind>(
          value: _FindKind.rooms,
          icon: const Icon(LucideIcons.hash, size: 16),
          label: Text(l10n.exploreRooms),
        ),
        ButtonSegment<_FindKind>(
          value: _FindKind.spaces,
          icon: const Icon(LucideIcons.folder, size: 16),
          // Its own key rather than the home dashboard's exploreSpaces, which
          // reads "Explore spaces". Two buttons on two screens meaning the
          // same word is fine; one key meaning two different sentences is not,
          // and it had already happened.
          label: Text(l10n.exploreSpacesTab),
        ),
        ButtonSegment<_FindKind>(
          value: _FindKind.people,
          icon: const Icon(LucideIcons.userRound, size: 16),
          label: Text(l10n.explorePeople),
        ),
      ],
      selected: {kind},
      showSelectedIcon: false,
      onSelectionChanged: (next) => onChanged(next.first),
    );
  }
}
