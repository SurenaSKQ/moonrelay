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

// The command palette, opened with `Ctrl+Shift+P`.
//
// This is the whole surface: an input, a row of filters, one ranked list and a
// footer that is honest about failure. Everything it knows lives in
// [PaletteController] and everything it ranks lives in [palette_result.dart].
//
// Three things it does that the previous version did not.
//
// **The keyboard drives it.** Arrow keys move a cursor, Enter runs the row
// under it, Home and End jump, Escape closes. The old palette had no arrow
// handling at all and ran something on Enter only when exactly one result
// matched, so a palette you opened with the keyboard could not be operated with
// the keyboard.
//
// **The filters narrow rather than replace.** `#`, `@` and `>` restrict the
// list; with no prefix, everything competes in one ranked list. The old five
// modes were replacements, which is why the header comment's promise that
// "opened, the user sees recents" was untrue: the empty state rendered all
// eight commands and put recents below a divider under the fold.
//
// **A source that failed says so.** The footer names it. The old version
// returned an empty page from three bare `catch (_)` blocks, so a homeserver
// that was down looked exactly like a query with no results.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_controller.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_result.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_sources.dart';
import 'package:provider/provider.dart';

/// Opens the command palette as a modal route.
///
/// Root navigator, so it floats above whichever shell is mounted. A desktop
/// user has four panes and a title bar and none of them is a good place to put a
/// global search field, because every one of them already has a job.
Future<void> showCommandPalette(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => const CommandPalettePage(),
    ),
  );
}

class CommandPalettePage extends StatelessWidget {
  const CommandPalettePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PaletteController>(
      create: (BuildContext context) => PaletteController(
        client: context.read<Client>(),
        log: context.read<Logger>(),
        sources: const PaletteSources(),
      ),
      child: const _CommandPaletteView(),
    );
  }
}

/// The intent a row asks the view to run.
///
/// A result carries a closure that takes a `BuildContext`, which is the wrong
/// shape here: the palette is about to pop itself, so the context that closure
/// would receive is the one being torn down. That is how the old `_runAction`
/// ended up calling `Navigator.pop()` and then handing the callback its own
/// dying context behind an `if (!mounted) return` guard that could never fire
/// usefully. Dispatching an intent and running it after the pop means the
/// closure is invoked with a context that is still alive.
sealed class _PaletteIntent {
  const _PaletteIntent();
}

class _RunResult extends _PaletteIntent {
  const _RunResult(this.result);
  final PaletteResult result;
}

class _Close extends _PaletteIntent {
  const _Close();
}

class _MoveCursor extends _PaletteIntent {
  const _MoveCursor(this.delta);
  final int delta;
}

class _JumpToEdge extends _PaletteIntent {
  const _JumpToEdge({required this.last});
  final bool last;
}

class _RunSelected extends _PaletteIntent {
  const _RunSelected();
}

/// Wraps the view in a keyboard handler so the list can hold focus without the
/// input field eating every arrow key.
class _CommandPaletteView extends StatefulWidget {
  const _CommandPaletteView();

  @override
  State<_CommandPaletteView> createState() => _CommandPaletteViewState();
}

class _CommandPaletteViewState extends State<_CommandPaletteView> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final FocusNode _listFocus = FocusNode(debugLabel: 'palette-results');

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _ctl.dispose();
    _inputFocus.dispose();
    _listFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 120) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    context.read<PaletteController>().loadMore(l10n);
  }

  /// Dispatches [intent], popping first for anything that leaves.
  void _dispatch(_PaletteIntent intent) {
    final PaletteController controller = context.read<PaletteController>();
    final NavigatorState navigator = Navigator.of(context);

    switch (intent) {
      case _MoveCursor(:final int delta):
        controller.moveSelection(delta);
        _scrollSelectedIntoView();
      case _JumpToEdge(:final bool last):
        controller.selectEdge(last: last);
        _scrollSelectedIntoView();
      case _RunSelected():
        final PaletteResult? selected = controller.selected;
        if (selected == null) return;
        _dispatch(_RunResult(selected));
      case _RunResult(:final PaletteResult result):
        // Pop first so the result's closure runs against the context underneath
        // rather than this one, which is about to be gone.
        navigator.pop();
        final BuildContext target = navigator.context;
        if (!target.mounted) return;
        result.run(target);
      case _Close():
        navigator.pop();
    }
  }

  void _scrollSelectedIntoView() {
    if (!_scroll.hasClients) return;
    final int index = context.read<PaletteController>().selectedIndex;
    // A row is 48 pixels plus the 4 that separate them, which is the height the
    // list was built with. Measuring instead of hardcoding would need a key on
    // every row, and the number is derived from the same token in both places,
    // so they agree by construction or not at all.
    const double rowExtent = 52;
    final double top = index * rowExtent;
    final double viewport = _scroll.position.viewportDimension;
    if (top < _scroll.position.pixels) {
      _scroll.jumpTo(top);
    } else if (top + rowExtent > _scroll.position.pixels + viewport) {
      _scroll.jumpTo(top + rowExtent - viewport);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _dispatch(const _MoveCursor(1));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _dispatch(const _MoveCursor(-1));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        _dispatch(const _MoveCursor(8));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _dispatch(const _MoveCursor(-8));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _dispatch(const _JumpToEdge(last: false));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _dispatch(const _JumpToEdge(last: true));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _dispatch(const _RunSelected());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _dispatch(const _Close());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.slash:
        // Not intercepted. `/` reaching the field is the whole reason a palette
        // that filters to rooms exists, and shift is checked so that typing
        // "and/or" is not a command.
        if (shift) return KeyEventResult.ignored;
        return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final PaletteController controller = context.watch<PaletteController>();

    return Material(
      color: Colors.transparent,
      // A fullscreen outside-tap detector, because the `PageRoute`'s
      // `barrierDismissible` is not sufficient: the page is laid out over the
      // barrier and the barrier's detector loses the gesture arena. The card
      // marks itself so taps in the padding around a row do not dismiss.
      child: BarrierDismissableOverlay(
        child: BlurBackground(
          overlayColor: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: BarrierDismissBoundary(
                  child: _PaletteCard(
                    controller: controller,
                    textController: _ctl,
                    inputFocus: _inputFocus,
                    listFocus: _listFocus,
                    scrollController: _scroll,
                    onKey: _onKey,
                    onInput: (String value) =>
                        controller.onInputChanged(value, l10n),
                    onFilter: (PaletteSource source) {
                      final String next = controller.toggleFilter(source, l10n);
                      // The chips edit the query, so the field has to be told,
                      // or the chips and the text disagree about what is
                      // being searched.
                      _ctl.value = TextEditingValue(
                        text: next,
                        selection: TextSelection.collapsed(
                          offset: next.length,
                        ),
                      );
                    },
                    onRun: _dispatch,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.controller,
    required this.textController,
    required this.inputFocus,
    required this.listFocus,
    required this.scrollController,
    required this.onKey,
    required this.onInput,
    required this.onFilter,
    required this.onRun,
  });

  final PaletteController controller;
  final TextEditingController textController;
  final FocusNode inputFocus;
  final FocusNode listFocus;
  final ScrollController scrollController;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final void Function(String) onInput;
  final void Function(PaletteSource) onFilter;
  final void Function(_PaletteIntent) onRun;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;

    return Material(
      elevation: t.elevationOverlay,
      borderRadius: BorderRadius.circular(t.radiusLg),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(t.spaceLg, t.spaceLg, t.spaceLg, 0),
            child: Focus(
              // The list node owns the arrows, the field owns the characters.
              // Both are below this node so one handler sees either.
              onKeyEvent: onKey,
              child: TextField(
                controller: textController,
                focusNode: inputFocus,
                autofocus: true,
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  hintText: controller.hasQuery
                      ? l10n.commandPaletteSearchHint
                      : l10n.commandPaletteHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(LucideIcons.command),
                  suffixIcon: controller.busy
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: onInput,
                onSubmitted: (_) => onRun(const _RunSelected()),
              ),
            ),
          ),
          _FilterRow(active: controller.filter, onToggle: onFilter),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Focus(
                focusNode: listFocus,
                onKeyEvent: onKey,
                canRequestFocus: false,
                skipTraversal: true,
                descendantsAreFocusable: false,
                child: _Results(
                  controller: controller,
                  scrollController: scrollController,
                  onRun: onRun,
                ),
              ),
            ),
          ),
          _Footer(controller: controller),
          Divider(height: 1, color: ext.layers.hairline),
          _Hints(),
        ],
      ),
    );
  }
}

/// The prefix filters, shown as chips rather than as a hint line.
///
/// The old palette inferred its mode from a leading character and then stripped
/// it, so the only evidence of which mode you were in was a 14-pixel icon and a
/// line of 12-pixel grey text. Chips are pressable, so they also let you *set*
/// the filter rather than only read it.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.active, required this.onToggle});

  final PaletteSource? active;
  final void Function(PaletteSource) onToggle;

  static const List<PaletteSource> _offered = <PaletteSource>[
    PaletteSource.room,
    PaletteSource.user,
    PaletteSource.page,
    PaletteSource.message,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: t.paneBarHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: t.spaceLg,
          vertical: (t.paneBarHeight - 28) / 2,
        ),
        children: <Widget>[
          for (final PaletteSource source in _offered)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: _labelFor(source, l10n),
                prefix: source.prefix,
                selected: active?.matches(source) ?? false,
                onTap: () => onToggle(source),
                scheme: scheme,
                ext: ext,
              ),
            ),
        ],
      ),
    );
  }

  static String _labelFor(PaletteSource source, AppLocalizations l10n) =>
      switch (source) {
        PaletteSource.room => l10n.commandPaletteRooms,
        PaletteSource.user => l10n.searchUsersResults,
        PaletteSource.page => l10n.appSettings,
        PaletteSource.message => l10n.searchMessages,
        _ => source.name,
      };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.prefix,
    required this.selected,
    required this.onTap,
    required this.scheme,
    required this.ext,
  });

  final String label;
  final String? prefix;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final dynamic ext;

  @override
  Widget build(BuildContext context) {
    final t = ext.tokens;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(t.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusFull),
            border: Border.all(
              color: selected ? scheme.primary : ext.layers.hairline,
              width: t.borderWidthThin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (prefix != null)
                Text(
                  prefix!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              if (prefix != null) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.controller,
    required this.scrollController,
    required this.onRun,
  });

  final PaletteController controller;
  final ScrollController scrollController;
  final void Function(_PaletteIntent) onRun;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<PaletteResult> results = controller.results;

    if (results.isEmpty) {
      return _Empty(controller: controller, l10n: l10n);
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: results.length,
      itemBuilder: (BuildContext context, int index) {
        final PaletteResult result = results[index];
        return _Row(
          result: result,
          selected: index == controller.selectedIndex,
          // Tap runs whatever the row is, not whatever the cursor happens to be
          // on. Using the cursor's row for a tap on a different row is the kind
          // of off-by-one that makes a list feel haunted.
          onTap: () => onRun(_RunResult(result)),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.result,
    required this.selected,
    required this.onTap,
  });

  final PaletteResult result;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      // The selected row is carried by a fill rather than by a border, because
      // a border on a dense list draws more attention than the row it is
      // marking. `glow` is the earthshine on the focused thing.
      color: selected ? ext.layers.active : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: t.paneBarHeight,
          padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
          child: Row(
            children: <Widget>[
              Icon(
                result.icon,
                size: t.iconSizeMedium,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              SizedBox(width: t.spaceMd),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (result.subtitle != null && result.subtitle!.isNotEmpty)
                      Text(
                        result.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
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

/// What the palette says when there is nothing to show.
///
/// Three distinct states, and the old palette had one. "Nothing matched" and
/// "still looking" look identical in a list that is empty, and the third is the
/// one the old version could not express at all: something failed.
class _Empty extends StatelessWidget {
  const _Empty({required this.controller, required this.l10n});

  final PaletteController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    final String message;
    if (controller.failures.isNotEmpty) {
      message = l10n.paletteSourceFailed;
    } else if (controller.phase == PalettePhase.searching) {
      message = l10n.paletteSearching;
    } else if (controller.hasQuery) {
      message = l10n.commandPaletteNoResults;
    } else {
      message = l10n.paletteTypeToSearch;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              controller.failures.isNotEmpty
                  ? LucideIcons.cloudOff
                  : controller.phase == PalettePhase.searching
                      ? LucideIcons.loader
                      : LucideIcons.search,
              size: t.iconSizeLarge,
              color: ext.layers.hairline,
            ),
            SizedBox(height: t.spaceMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The failure notice.
///
/// Says which source failed, because "some results failed" is not actionable
/// and "message search is unavailable" is at least honest about what is
/// missing.
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PaletteController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.failures.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ext = Theme.of(context).moonrelay;
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: ext.layers.hover,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          Icon(LucideIcons.triangleAlert, size: 14, color: scheme.error),
          SizedBox(width: t.spaceSm),
          Expanded(
            child: Text(
              l10n.paletteSourceFailedNamed(
                controller.failures.keys
                    .map((PaletteSource s) => s.name)
                    .join(', '),
              ),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The key hints, in the space a palette always has and never uses.
class _Hints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).moonrelay.tokens;
    final scheme = Theme.of(context).colorScheme;
    final TextStyle style = TextStyle(
      fontSize: 11,
      color: scheme.onSurfaceVariant,
    );

    Widget key(String label, String description) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusXs),
                border: Border.all(
                  color: scheme.onSurfaceVariant
                      .withValues(alpha: t.opacitySubtle),
                ),
              ),
              child: Text(label, style: style),
            ),
            SizedBox(width: t.spaceXs),
            Text(description, style: style),
          ],
        );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceSm,
      ),
      child: Wrap(
        spacing: t.spaceMd,
        runSpacing: t.spaceXs,
        children: <Widget>[
          key('↑↓', l10n.paletteHintNavigate),
          key('↵', l10n.paletteHintOpen),
          key('Esc', l10n.paletteHintClose),
        ],
      ),
    );
  }
}
