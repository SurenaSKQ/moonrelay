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
import 'package:moonrelay/src/widgets/moonrelay_mark.dart';

/// The shared surface for the screens shown before the dashboard can load.
///
/// The welcome, sign-in and register screens are the only place in the app with
/// nothing behind them but the window, and they had drifted apart from each
/// other and from the rest of the app at the same time. Sign-in and register
/// were the same form written twice: one used a shadowed `Container`, the other
/// a Material `Card` with `elevation:`, which renders from a hardcoded black map
/// no theme field reaches and is therefore invisible on the dark ramp. The
/// radii disagreed with each other and with the token scale. The error banner
/// existed three times at three different radii.
///
/// So the primitives live here and the three pages compose them. A page that
/// needs a form control that is not in this file should add it here rather than
/// grow a private copy, which is the mistake this file exists to end.

/// The measure for a form.
///
/// 480 rather than the 680 that `MoonrelayInfoPage` uses, because an input is
/// not a sentence and a field wider than about eighty characters puts the caret
/// in a different place from the label that describes it.
const double kAuthFormWidth = 480;

/// The gap between a field's caption and its input.
const double _captionGap = 4;

/// A page that holds one form or one short column.
///
/// Scrolls, centres, and stops widening past [kAuthFormWidth]. The vertical
/// padding is asymmetric: the top is padded as if the window's own title bar
/// were not already there, so the form does not read as shoved up against the
/// chrome, and the bottom gets more because the keyboard opens over it.
class AuthPage extends StatelessWidget {
  const AuthPage(
      {super.key, required this.child, this.maxWidth = kAuthFormWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Scaffold(
      // The composer behind the keyboard is the only part of this screen the
      // user will ever see while typing, so it has to move.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceXl,
            vertical: t.spaceXl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised panel a form sits in.
///
/// One step above the app floor, with the app's single hairline and the high
/// shadow. The shadow is the right answer here and nowhere else in the app:
/// there is nothing else on screen, so the window is the page and something has
/// to say which rectangle is the form.
///
/// It takes the shadow list directly rather than setting `elevation:`, because
/// Material renders `elevation:` from `kElevationToShadow`, a hardcoded black
/// map that `ThemeData.shadowColor` does not reach, and on a near-black surface
/// that map is arithmetically present and visually absent. `shadowHigh` carries
/// the light rim that does show.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: ext.layers.hairline),
        boxShadow: t.shadowHigh,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(t.spaceXxl),
        child: child,
      ),
    );
  }
}

/// A caption plus an input, the unit every form in this segment is built from.
///
/// The caption sits above the field rather than floating inside it. A floating
/// Material label shrinks and moves when the field has content, which makes the
/// label's position depend on whether you have typed yet, and it is the wrong
/// idiom for a flat left-aligned form anyway.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.caption,
    required this.focusNode,
    this.controller,
    this.hintText,
    this.icon,
    this.obscureText = false,
    this.suffix,
    this.errorText,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String caption;
  final FocusNode focusNode;
  final TextEditingController? controller;
  final String? hintText;
  final IconData? icon;
  final bool obscureText;
  final Widget? suffix;
  final String? errorText;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  /// Called on every keystroke.
  ///
  /// Only the register form uses it, to clear a validation message the moment
  /// the user starts fixing it. A form that keeps showing "that username is
  /// taken" while you are typing over it is nagging.
  final ValueChanged<String>? onChanged;

  final Iterable<String>? autofillHints;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final input = ext.components.input;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthCaption(caption),
        SizedBox(height: _captionGap),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofillHints: autofillHints,
          enabled: enabled,
          style: TextStyle(fontSize: 14, color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacitySubtle),
            ),
            prefixIcon: icon == null
                ? null
                : Icon(icon,
                    size: input.iconSize, color: scheme.onSurfaceVariant),
            suffixIcon: suffix,
            errorText: errorText,
            // The component tokens, not a literal. Every field in this segment
            // used to spell out `(horizontal: 16, vertical: 14)`, which is not
            // what `input.contentPaddingV` says, so the token and the truth had
            // quietly parted.
            contentPadding: EdgeInsets.symmetric(
              horizontal: input.contentPaddingH,
              vertical: input.contentPaddingV,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(input.cornerRadius),
              borderSide: BorderSide(
                color: scheme.outlineVariant,
                width: input.borderWidth,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(input.cornerRadius),
              borderSide: BorderSide(
                color: scheme.outlineVariant,
                width: input.borderWidth,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(input.cornerRadius),
              borderSide:
                  BorderSide(color: scheme.primary, width: input.borderWidth),
            ),
          ),
        ),
      ],
    );
  }
}

/// A panel that is a well rather than a card.
///
/// One step below the floor with the app's single hairline and no shadow. The
/// same treatment `InfoPanel` gives a group of facts in a settings page, and for
/// the same reason: a screen with four raised cards is four things competing,
/// and only one of them is the thing you are here to do.
///
/// So exactly one panel per screen is raised ([AuthCard]) and the rest are
/// wells. Reading them together is the only way to tell them apart.
class AuthPanel extends StatelessWidget {
  const AuthPanel({
    super.key,
    required this.child,
    this.padding,
    this.leading,
    this.title,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// The glyph beside [title]. Sized by the caller.
  final IconData? leading;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;
    final display = Theme.of(context).textTheme.titleMedium?.fontFamily;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: ext.layers.hairline),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(t.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Row(
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    Icon(leading, size: t.iconSizeSmall, color: scheme.primary),
                    SizedBox(width: t.spaceSm),
                  ],
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: display,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceSm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Body copy inside a panel.
///
/// One height for the whole segment. The old cards each set `height: 1.5` on
/// their own, and the welcome screen's branding used 0.8 alpha over
/// `onSurfaceVariant` for its description, which lands in roughly the same
/// lightness as plain `onSurfaceVariant` but by a different route.
class AuthBody extends StatelessWidget {
  const AuthBody(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
          fontSize: 13.5, height: 1.55, color: scheme.onSurfaceVariant),
    );
  }
}

/// The gap between two panels in a column.
class AuthStackGap extends StatelessWidget {
  const AuthStackGap({super.key});

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return SizedBox(height: t.spaceLg);
  }
}

/// The caption above an input, and above a group of choices in a settings
/// panel.
///
/// 13 / w500 / `onSurfaceVariant`, which is the same treatment `InfoPanelRow`
/// gives a label, so a form and a settings panel speak about their fields in
/// one voice.
class AuthCaption extends StatelessWidget {
  const AuthCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// A banner inside a form: a failure, something pending, or a plain note.
///
/// One widget for all three because there were four near-identical containers
/// across the two forms at three different radii, and a message the user is
/// meant to read is the last thing that should look like an afterthought.
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.message,
    this.icon,
    this.tone = AuthNoticeTone.failure,
    this.busy = false,
  });

  final String message;
  final IconData? icon;

  /// What the notice is about. Not decoration: the tone picks the fill and the
  /// foreground, and a failure that reads as information is worse than no
  /// message at all.
  final AuthNoticeTone tone;

  /// Replaces [icon] with a spinner. Used by the SSO flow, which is waiting
  /// rather than reporting anything.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;

    final (Color fill, Color foreground, IconData? fallback) = switch (tone) {
      AuthNoticeTone.failure => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
      AuthNoticeTone.pending => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          null,
        ),
      AuthNoticeTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          null,
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (busy)
              SizedBox(
                width: t.iconSizeSmall,
                height: t.iconSizeSmall,
                child: CircularProgressIndicator(
                  strokeWidth: t.borderWidthMedium,
                  color: foreground,
                ),
              )
            else if (icon != null || fallback != null)
              Padding(
                // Nudge the glyph onto the first line of the message rather than
                // centring it against however many lines there are, which is
                // what `Row`'s default centre does to a three-line failure.
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  icon ?? fallback,
                  size: t.iconSizeSmall,
                  color: foreground,
                ),
              ),
            SizedBox(width: t.spaceSm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, height: 1.4, color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AuthNoticeTone { failure, pending, neutral }

/// The full-width button every form ends with.
///
/// The component token's radius, the token's minimum touch height, and the same
/// icon size whatever the state, so the button does not resize between "Sign In"
/// and "Signing in" and shift the links under it.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final button = ext.components.button;
    final scheme = Theme.of(context).colorScheme;

    final Widget? glyph = busy
        ? SizedBox(
            width: t.iconSizeSmall,
            height: t.iconSizeSmall,
            child: CircularProgressIndicator(
              strokeWidth: t.borderWidthMedium,
              color: filled ? scheme.onPrimary : scheme.primary,
            ),
          )
        : icon == null
            ? null
            : Icon(
                icon,
                size: button.iconSize,
                color: filled ? scheme.onPrimary : scheme.primary,
              );

    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // The glyph is absent rather than defaulted when there is nothing to
        // say. A button that is only a label should look like a label.
        if (glyph != null) ...<Widget>[glyph, SizedBox(width: button.iconGap)],
        Flexible(
          child: Text(
            label,
            // No `maxLines`: a translated label is longer than the English one
            // and clipping a button's own text is a worse failure than letting
            // the row wrap. `Flexible` plus the button's own min height means a
            // two-line label grows the button instead of losing its second line.
            softWrap: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: filled ? scheme.onPrimary : scheme.primary,
            ),
          ),
        ),
      ],
    );

    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(
        Size.fromHeight(t.minTapTarget),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: t.spaceLg,
          vertical: button.padding.vertical,
        ),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(button.cornerRadius),
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: scheme.outline,
                  width: button.borderWidth,
                ),
        ),
      ),
    );

    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

/// The quiet links under a form's button: "use a token instead", and so on.
///
/// A row that wraps rather than a column, because two of them fit side by side
/// and one of them alone looks lost centred on its own line.
class AuthLinks extends StatelessWidget {
  const AuthLinks({super.key, required this.links});

  final List<(String, VoidCallback)> links;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 0,
      children: <Widget>[
        for (final (String label, VoidCallback onTap) in links)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              // A link is not a button: no minimum height, no fill, and the
              // accent's text colour rather than a surface pair, so it reads as
              // a way out of the form rather than as a fourth thing to press.
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

/// The mark and the wordmark, as the two of them together.
///
/// The wordmark used to spell `fontFamily: 'Oxanium'` at a literal 36, which is
/// the only hardcoded family left in the app and a size that is not on any
/// scale. It is the display face at 22 now, which is what `IdentityHeader` gives
/// a page's own name, and the mark beside it is the real brand asset rather than
/// a moon glyph from the icon set.
class AuthBrandLockup extends StatelessWidget {
  const AuthBrandLockup({
    super.key,
    required this.name,
    required this.tagline,
    this.markSize = 40,
  });

  final String name;
  final String tagline;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final display = Theme.of(context).textTheme.titleMedium?.fontFamily;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MoonrelayMark(
          size: markSize,
          // The accent, not `onSurface`: this is the one place in the app where
          // the mark is allowed to carry the brand's colour, and it is also the
          // only place the user sees it before they have chosen anything, so it
          // has to look deliberate rather than like another grey glyph.
          color: scheme.primary,
        ),
        SizedBox(height: t.spaceMd),
        Semantics(
          label: name,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: display,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
        ),
        SizedBox(height: t.spaceXs),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The heading at the top of a form card, with its back control beside it.
///
/// One row and one size, so the three pages that have a heading agree on what a
/// heading is. The register page used 20 while sign-in used `titleLarge`.
class AuthCardHeader extends StatelessWidget {
  const AuthCardHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.backTooltip,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final String backTooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;
    final display = Theme.of(context).textTheme.titleMedium?.fontFamily;

    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: onBack,
          tooltip: backTooltip,
          visualDensity: VisualDensity.compact,
          color: scheme.onSurfaceVariant,
        ),
        SizedBox(width: t.spaceXs),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: display,
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
