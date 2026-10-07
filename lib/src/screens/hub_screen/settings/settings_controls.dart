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

import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// The control vocabulary of the hub's settings pages

/// Width of a slider's well in a settings row.
///
/// Every numeric setting in the hub drew its own, and they did not agree:
/// seven pages said 160 and two said 200, so the one control a reader reaches
/// for most often changed size between pages and the number under it sat at a
/// different distance from the end of the row each time.
///
/// It is a share of the row rather than a fixed track, and it is derived so
/// that at the 680 measure a label, a value and a well still fit on one line
/// at the largest text scale the app offers.
double _hubSliderWell(double rowWidth) => (rowWidth * 0.28).clamp(120.0, 220.0);

/// The size of a row's leading glyph.
///
/// These rows were written with a literal 22, which is not one of the app's
/// three icon sizes and was therefore a fourth one. [iconSizeMedium] is what
/// the room and space pages use beside the same kind of label, and at 20 it
/// sits under a 14px label rather than shouting over it.
const double _hubRowIcon = 20;

/// One numeric setting.
///
/// The row reads label, value, control, in that order, and the value sits
/// under the label rather than beside it. It was beside it before, at whatever
/// width the control happened to be, which meant the numbers a reader was
/// actually comparing were in three different columns depending on the page.
class HubSliderTile extends StatelessWidget {
  const HubSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String title;

  /// Current setting. A `num` rather than a `double`, because half the settings
  /// in the app store an `int` and half a `double`, and requiring every page to
  /// write `.toDouble()` at each call site is fourteen chances to forget. Rounding
  /// it at the boundary is how a slider ends up refusing its own extreme value.
  final num value;

  /// The value as the reader should see it. Built at the call site, since
  /// "140 px" and "1.2×" and "520" are three different sentences about a
  /// number and the widget should not have to guess which one applies.
  final String valueLabel;

  final double min;
  final double max;
  final int divisions;

  /// Null disables the slider, which greys the whole track out.
  ///
  /// Two settings here only mean something while another is on: how long
  /// before presence goes offline needs the switch, and how long drafts are
  /// kept needs drafts. Their rows used to reach that with `enabled: false` on
  /// the tile *and* a null `onChanged` on the slider, two mechanisms for one
  /// state, either of which could be forgotten when the tile was rewritten.
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListTile(
          leading: Icon(icon, size: _hubRowIcon),
          title: Text(title),
          subtitle: Text(valueLabel),
          trailing: SizedBox(
            width: _hubSliderWell(constraints.maxWidth),
            child: Slider(
              // Clamped here rather than at each call site, because the
              // dangerous value is a *persisted* one: a setting stored by a
              // release whose maximum was lower than today's arrives outside
              // the range, and `Slider` asserts on that in debug and paints a
              // thumb off the end of its own track in release. The advanced
              // settings page was the one place that remembered to guard for
              // this, with a private slider row that existed only to do so.
              value: value.toDouble().clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}

/// One setting that is a choice between a small fixed set of values.
///
/// The radio group's plumbing was written out by hand seven times across the
/// hub: a `RadioGroup` wrapping a `Column` of `RadioListTile`s, each with its
/// `mainAxisSize: MainAxisSize.min`, and each group free to disagree about
/// density, leading icons and whether it was inside the section's `Card` at
/// all. This is that, once.
class HubRadioRow<T> extends StatelessWidget {
  const HubRadioRow({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.dense = false,
  });

  /// The selected option, or null when the group has no selection.
  final T? value;

  final List<HubRadioOption<T>> options;

  /// Receives null when a selection is cleared. Callers that cannot represent
  /// "nothing" should ignore it rather than force a value: an unforced choice
  /// is the difference between a control that can be unset and one that
  /// silently snaps back.
  final ValueChanged<T?> onChanged;

  /// Tighter rows, for a group long enough that its scroll is the page's
  /// scroll. The accent picker needs it: thirteen options at full height is
  /// taller than the window.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: value,
      onChanged: onChanged,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            RadioListTile<T>(
              value: option.value,
              dense: dense,
              selected: option.value == value,
              secondary: option.leading ??
                  (option.icon == null ? null : Icon(option.icon!)),
              title: option.leading == null
                  ? Text(option.label)
                  : Row(
                      children: [
                        option.leading!,
                        SizedBox(
                          width: MoonrelayThemeExtension.of(context)
                              .tokens
                              .spaceMd,
                        ),
                        Flexible(
                          child: Text(
                            option.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// One option in a [HubRadioRow].
class HubRadioOption<T> {
  const HubRadioOption({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
  });

  final T value;
  final String label;

  /// Shown before the label, in the radio's own leading slot.
  final IconData? icon;

  /// Replaces [icon] when the option needs something that is not a glyph,
  /// which today is one thing: the accent swatches.
  final Widget? leading;
}

/// A small set of values as chips rather than as a list.
///
/// Density is three options that are all short words, all of which are worth
/// seeing at once, and none of which benefits from a radio's dot. A list of
/// three radios costs more vertical space than it saves in clarity.
class HubChoiceChipRow<T> extends StatelessWidget {
  const HubChoiceChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.label,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;

  /// Null greys the chips out and makes them inert, rather than accepting the
  /// tap and discarding it. A control that looks live and does nothing is
  /// worse than one that looks dead: the reader has no way to tell which.
  final ValueChanged<T>? onSelected;

  /// Names the row, for the one case where a group of chips describes one of
  /// several settings rather than being the setting itself: three auto-download
  /// policies in a single section. Without it the reader sees three rows of
  /// chips and has to count back to find which one they changed.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final name = label;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (name != null)
            Text(name, style: Theme.of(context).textTheme.titleSmall),
          if (name != null) SizedBox(height: t.spaceSm),
          Wrap(
            spacing: t.spaceSm,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(labelOf(value)),
                  selected: value == selected,
                  onSelected:
                      onSelected == null ? null : (_) => onSelected!(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A setting that is a list, which the reader picks from somewhere else.
class HubNavTile extends StatelessWidget {
  const HubNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// The current choice, shown under the title. Not editable in place, which
  /// is what the chevron is telling you.
  final String value;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return ListTile(
      leading: Icon(icon, size: _hubRowIcon),
      title: Text(title),
      subtitle: Text(value, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: Icon(
        LucideIcons.chevronRight,
        size: t.iconSizeSmall + 2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A setting chosen from a list that fits in the row.
class HubDropdownTile<T> extends StatelessWidget {
  const HubDropdownTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: _hubRowIcon),
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        items: [
          for (final item in items)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelOf(item)),
            ),
        ],
      ),
    );
  }
}

/// An on/off setting with a sentence explaining what turning it off does.
class HubSwitchTile extends StatelessWidget {
  const HubSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;

  /// Null disables the row. Not every setting here can always be changed:
  /// what the window does on start depends on there being a tray icon at all,
  /// and the two rows that depend on it say so by refusing input rather than
  /// by pretending to be off.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: _hubRowIcon),
      title: Text(title),
      subtitle: Text(description),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A row that runs something rather than holding a value.
///
/// It looks like every other row and carries no value, which is the tell that
/// it is not a setting: nothing under the label changes, so a reader who
/// assumed it was one would be looking for a difference that never comes.
class HubActionTile extends StatelessWidget {
  const HubActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return ListTile(
      leading: Icon(icon, size: _hubRowIcon),
      title: Text(title),
      subtitle: Text(description),
      onTap: onTap,
      trailing: Icon(
        LucideIcons.chevronRight,
        size: t.iconSizeSmall + 2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A note under a group of controls.
///
/// The weakest text on the page, which is the point: it is a sentence about
/// what the controls above it do, and it should be the last thing read rather
/// than a tenth competing heading.
class InfoFootnote extends StatelessWidget {
  const InfoFootnote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spaceLg,
        t.spaceXs,
        t.spaceLg,
        t.spaceSm,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
