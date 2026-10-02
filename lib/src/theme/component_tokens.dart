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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';

/// Per-component semantic tokens derived from [MoonrelayDesignTokens].
///
/// Each sub-token class holds the visual constants relevant to a single
/// Material component family (buttons, inputs, cards, etc.). Widget code
/// references `theme.components.button.cornerRadius` instead of a bare double.
@immutable
class MoonrelayComponentTokens {
  const MoonrelayComponentTokens({
    required this.button,
    required this.input,
    required this.card,
    required this.appBar,
    required this.list,
    required this.dialog,
    required this.divider,
    required this.chip,
    required this.badge,
    required this.navigation,
    required this.chat,
    required this.snackBar,
    required this.progress,
    required this.avatar,
    required this.tooltip,
  });

  final MoonrelayButtonTokens button;
  final MoonrelayInputTokens input;
  final MoonrelayCardTokens card;
  final MoonrelayAppBarTokens appBar;
  final MoonrelayListTokens list;
  final MoonrelayDialogTokens dialog;
  final MoonrelayDividerTokens divider;
  final MoonrelayChipTokens chip;
  final MoonrelayBadgeTokens badge;
  final MoonrelayNavigationTokens navigation;
  final MoonrelayChatTokens chat;
  final MoonrelaySnackBarTokens snackBar;
  final MoonrelayProgressTokens progress;
  final MoonrelayAvatarTokens avatar;
  final MoonrelayTooltipTokens tooltip;

  /// Derives all component tokens from [tokens].
  factory MoonrelayComponentTokens.fromDesignTokens(
    MoonrelayDesignTokens tokens,
  ) {
    return MoonrelayComponentTokens(
      button: MoonrelayButtonTokens.fromDesignTokens(tokens),
      input: MoonrelayInputTokens.fromDesignTokens(tokens),
      card: MoonrelayCardTokens.fromDesignTokens(tokens),
      appBar: MoonrelayAppBarTokens.fromDesignTokens(tokens),
      list: MoonrelayListTokens.fromDesignTokens(tokens),
      dialog: MoonrelayDialogTokens.fromDesignTokens(tokens),
      divider: MoonrelayDividerTokens.fromDesignTokens(tokens),
      chip: MoonrelayChipTokens.fromDesignTokens(tokens),
      badge: MoonrelayBadgeTokens.fromDesignTokens(tokens),
      navigation: MoonrelayNavigationTokens.fromDesignTokens(tokens),
      chat: MoonrelayChatTokens.fromDesignTokens(tokens),
      snackBar: MoonrelaySnackBarTokens.fromDesignTokens(tokens),
      progress: MoonrelayProgressTokens.fromDesignTokens(tokens),
      avatar: MoonrelayAvatarTokens.fromDesignTokens(tokens),
      tooltip: MoonrelayTooltipTokens.fromDesignTokens(tokens),
    );
  }

  MoonrelayComponentTokens copyWith({
    MoonrelayButtonTokens? button,
    MoonrelayInputTokens? input,
    MoonrelayCardTokens? card,
    MoonrelayAppBarTokens? appBar,
    MoonrelayListTokens? list,
    MoonrelayDialogTokens? dialog,
    MoonrelayDividerTokens? divider,
    MoonrelayChipTokens? chip,
    MoonrelayBadgeTokens? badge,
    MoonrelayNavigationTokens? navigation,
    MoonrelayChatTokens? chat,
    MoonrelaySnackBarTokens? snackBar,
    MoonrelayProgressTokens? progress,
    MoonrelayAvatarTokens? avatar,
    MoonrelayTooltipTokens? tooltip,
  }) {
    return MoonrelayComponentTokens(
      button: button ?? this.button,
      input: input ?? this.input,
      card: card ?? this.card,
      appBar: appBar ?? this.appBar,
      list: list ?? this.list,
      dialog: dialog ?? this.dialog,
      divider: divider ?? this.divider,
      chip: chip ?? this.chip,
      badge: badge ?? this.badge,
      navigation: navigation ?? this.navigation,
      chat: chat ?? this.chat,
      snackBar: snackBar ?? this.snackBar,
      progress: progress ?? this.progress,
      avatar: avatar ?? this.avatar,
      tooltip: tooltip ?? this.tooltip,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayComponentTokens &&
        other.button == button &&
        other.input == input &&
        other.card == card &&
        other.appBar == appBar &&
        other.list == list &&
        other.dialog == dialog &&
        other.divider == divider &&
        other.chip == chip &&
        other.badge == badge &&
        other.navigation == navigation &&
        other.chat == chat &&
        other.snackBar == snackBar &&
        other.progress == progress &&
        other.avatar == avatar &&
        other.tooltip == tooltip;
  }

  @override
  int get hashCode => Object.hashAll([
        button,
        input,
        card,
        appBar,
        list,
        dialog,
        divider,
        chip,
        badge,
        navigation,
        chat,
        snackBar,
        progress,
        avatar,
        tooltip,
      ]);
}

// -- Button tokens -----------------------------------------------------

@immutable
class MoonrelayButtonTokens {
  const MoonrelayButtonTokens({
    required this.cornerRadius,
    required this.borderWidth,
    required this.minHeight,
    required this.padding,
    this.labelStyle,
    required this.iconSize,
    required this.iconGap,
  });

  final double cornerRadius;
  final double borderWidth;
  final double minHeight;
  final EdgeInsets padding;
  final TextStyle? labelStyle;
  final double iconSize;
  final double iconGap;

  factory MoonrelayButtonTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayButtonTokens(
      cornerRadius: t.radiusMd,
      borderWidth: t.borderWidthMedium,
      minHeight: t.minTapTarget * 0.6,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceMd,
        vertical: t.spaceSm / 2,
      ),
      iconSize: t.iconSizeMedium,
      iconGap: t.spaceXs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayButtonTokens &&
        other.cornerRadius == cornerRadius &&
        other.borderWidth == borderWidth &&
        other.minHeight == minHeight &&
        other.padding == padding &&
        other.labelStyle == labelStyle &&
        other.iconSize == iconSize &&
        other.iconGap == iconGap;
  }

  @override
  int get hashCode => Object.hashAll([
        cornerRadius,
        borderWidth,
        minHeight,
        padding,
        labelStyle,
        iconSize,
        iconGap,
      ]);
}

// -- Input tokens ------------------------------------------------------

@immutable
class MoonrelayInputTokens {
  const MoonrelayInputTokens({
    required this.cornerRadius,
    required this.borderWidth,
    required this.contentPaddingV,
    required this.contentPaddingH,
    this.textStyle,
    this.hintStyle,
    required this.iconSize,
  });

  final double cornerRadius;
  final double borderWidth;
  final double contentPaddingV;
  final double contentPaddingH;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final double iconSize;

  factory MoonrelayInputTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayInputTokens(
      cornerRadius: t.radiusMd,
      borderWidth: t.borderWidthMedium,
      contentPaddingV: t.spaceMd,
      contentPaddingH: t.spaceLg,
      iconSize: t.iconSizeMedium,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayInputTokens &&
        other.cornerRadius == cornerRadius &&
        other.borderWidth == borderWidth &&
        other.contentPaddingV == contentPaddingV &&
        other.contentPaddingH == contentPaddingH &&
        other.textStyle == textStyle &&
        other.hintStyle == hintStyle &&
        other.iconSize == iconSize;
  }

  @override
  int get hashCode => Object.hashAll([
        cornerRadius,
        borderWidth,
        contentPaddingV,
        contentPaddingH,
        textStyle,
        hintStyle,
        iconSize,
      ]);
}

// -- Card tokens -------------------------------------------------------

@immutable
class MoonrelayCardTokens {
  const MoonrelayCardTokens({
    required this.elevation,
    required this.cornerRadius,
    required this.padding,
    required this.margin,
  });

  final double elevation;
  final double cornerRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;

  factory MoonrelayCardTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayCardTokens(
      elevation: 0,
      cornerRadius: t.radiusMd,
      padding: EdgeInsets.all(t.spaceLg),
      margin: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: t.spaceXs,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayCardTokens &&
        other.elevation == elevation &&
        other.cornerRadius == cornerRadius &&
        other.padding == padding &&
        other.margin == margin;
  }

  @override
  int get hashCode =>
      Object.hashAll([elevation, cornerRadius, padding, margin]);
}

// -- AppBar tokens -----------------------------------------------------

@immutable
class MoonrelayAppBarTokens {
  const MoonrelayAppBarTokens({
    required this.elevation,
    required this.scrolledElevation,
    this.titleStyle,
    required this.iconSize,
    required this.toolbarHeight,
  });

  final double elevation;
  final double scrolledElevation;
  final TextStyle? titleStyle;
  final double iconSize;
  final double toolbarHeight;

  factory MoonrelayAppBarTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayAppBarTokens(
      elevation: t.elevationNone,
      scrolledElevation: t.elevationLow,
      iconSize: t.iconSizeMedium,
      toolbarHeight: t.minTapTarget,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayAppBarTokens &&
        other.elevation == elevation &&
        other.scrolledElevation == scrolledElevation &&
        other.titleStyle == titleStyle &&
        other.iconSize == iconSize &&
        other.toolbarHeight == toolbarHeight;
  }

  @override
  int get hashCode => Object.hashAll([
        elevation,
        scrolledElevation,
        titleStyle,
        iconSize,
        toolbarHeight,
      ]);
}

// -- List tokens -------------------------------------------------------

@immutable
class MoonrelayListTokens {
  const MoonrelayListTokens({
    required this.contentPadding,
    required this.minVerticalPadding,
    this.titleStyle,
    this.subtitleStyle,
    this.leadingTextStyle,
  });

  final EdgeInsets contentPadding;
  final double minVerticalPadding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? leadingTextStyle;

  factory MoonrelayListTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayListTokens(
      contentPadding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceSm,
      ),
      minVerticalPadding: t.spaceSm,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayListTokens &&
        other.contentPadding == contentPadding &&
        other.minVerticalPadding == minVerticalPadding &&
        other.titleStyle == titleStyle &&
        other.subtitleStyle == subtitleStyle &&
        other.leadingTextStyle == leadingTextStyle;
  }

  @override
  int get hashCode => Object.hashAll([
        contentPadding,
        minVerticalPadding,
        titleStyle,
        subtitleStyle,
        leadingTextStyle,
      ]);
}

// -- Dialog tokens -----------------------------------------------------

@immutable
class MoonrelayDialogTokens {
  const MoonrelayDialogTokens({
    required this.cornerRadius,
    required this.titlePadding,
    required this.contentPadding,
    required this.actionsPadding,
  });

  final double cornerRadius;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;
  final EdgeInsets actionsPadding;

  factory MoonrelayDialogTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayDialogTokens(
      cornerRadius: t.radiusMd,
      titlePadding: EdgeInsets.fromLTRB(
        t.spaceXl,
        t.spaceXl,
        t.spaceXl,
        t.spaceSm,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        t.spaceXl,
        t.spaceSm,
        t.spaceXl,
        t.spaceSm,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        t.spaceXl,
        t.spaceSm,
        t.spaceXl,
        t.spaceLg,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayDialogTokens &&
        other.cornerRadius == cornerRadius &&
        other.titlePadding == titlePadding &&
        other.contentPadding == contentPadding &&
        other.actionsPadding == actionsPadding;
  }

  @override
  int get hashCode => Object.hashAll([
        cornerRadius,
        titlePadding,
        contentPadding,
        actionsPadding,
      ]);
}

// -- Divider tokens ----------------------------------------------------

@immutable
class MoonrelayDividerTokens {
  const MoonrelayDividerTokens({
    required this.thickness,
    required this.indent,
    required this.endIndent,
  });

  final double thickness;
  final double indent;
  final double endIndent;

  factory MoonrelayDividerTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayDividerTokens(
      thickness: t.borderWidthThin,
      indent: 0,
      endIndent: 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayDividerTokens &&
        other.thickness == thickness &&
        other.indent == indent &&
        other.endIndent == endIndent;
  }

  @override
  int get hashCode => Object.hashAll([thickness, indent, endIndent]);
}

// -- Chip tokens -------------------------------------------------------

@immutable
class MoonrelayChipTokens {
  const MoonrelayChipTokens({
    required this.cornerRadius,
    required this.borderWidth,
    required this.padding,
    required this.height,
  });

  final double cornerRadius;
  final double borderWidth;
  final EdgeInsets padding;
  final double height;

  factory MoonrelayChipTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayChipTokens(
      cornerRadius: t.radiusSm,
      borderWidth: t.borderWidthThin,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: t.spaceXs,
      ),
      height: t.minTapTarget * 0.6,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayChipTokens &&
        other.cornerRadius == cornerRadius &&
        other.borderWidth == borderWidth &&
        other.padding == padding &&
        other.height == height;
  }

  @override
  int get hashCode =>
      Object.hashAll([cornerRadius, borderWidth, padding, height]);
}

// -- Badge tokens ------------------------------------------------------

@immutable
class MoonrelayBadgeTokens {
  const MoonrelayBadgeTokens({
    required this.size,
    this.labelStyle,
    required this.padding,
  });

  final double size;
  final TextStyle? labelStyle;
  final EdgeInsets padding;

  factory MoonrelayBadgeTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayBadgeTokens(
      size: t.spaceMd,
      padding: EdgeInsets.all(t.spaceXxs),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayBadgeTokens &&
        other.size == size &&
        other.labelStyle == labelStyle &&
        other.padding == padding;
  }

  @override
  int get hashCode => Object.hashAll([size, labelStyle, padding]);
}

// -- Navigation tokens -------------------------------------------------

@immutable
class MoonrelayNavigationTokens {
  const MoonrelayNavigationTokens({
    required this.indicatorRadius,
    required this.iconSize,
    required this.labelFontSize,
    required this.padding,
  });

  final double indicatorRadius;
  final double iconSize;
  final double labelFontSize;
  final EdgeInsets padding;

  factory MoonrelayNavigationTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayNavigationTokens(
      indicatorRadius: t.radiusSm,
      iconSize: t.iconSizeMedium,
      labelFontSize: 12,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: t.spaceXs,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayNavigationTokens &&
        other.indicatorRadius == indicatorRadius &&
        other.iconSize == iconSize &&
        other.labelFontSize == labelFontSize &&
        other.padding == padding;
  }

  @override
  int get hashCode => Object.hashAll([
        indicatorRadius,
        iconSize,
        labelFontSize,
        padding,
      ]);
}

// -- Chat tokens -------------------------------------------------------

/// Geometry and type scale for the message timeline.
///
/// The timeline is the most-read surface in the app and used to carry the
/// most bare numbers in it: `EdgeInsets.all(10)` on the bubble, a hardcoded
/// 48px avatar gutter, a 480px cap and a 64px gutter as file constants, and a
/// timestamp at `bodySize * 0.6875` that grew past the body it labelled when
/// the user raised their font size. None of that was on the 8-point grid and
/// none of it was reachable from a settings change.
///
/// Everything that shapes a message row now lives here instead, derived from
/// [MoonrelayDesignTokens] so the chat moves when the design scale moves. The
/// single value the user owns is the bubble radius, which arrives as a setting
/// and overrides [bubbleRadius] at the point of use.
@immutable
class MoonrelayChatTokens {
  const MoonrelayChatTokens({
    required this.bubbleRadius,
    required this.avatarSize,
    required this.avatarGutter,
    required this.rowSpacing,
    required this.groupSpacing,
    required this.messagePaddingH,
    required this.messagePaddingV,
    required this.bubbleMaxWidth,
    required this.bubbleGutter,
    required this.measureMaxWidth,
    required this.replyBarWidth,
    required this.reactionRadius,
    required this.composerMinHeight,
  });

  /// Default bubble corner radius.  The user's `bubbleRadius` setting wins
  /// over this; the token is only the fallback for tests and for surfaces
  /// that render a bubble without a settings context.
  final double bubbleRadius;

  /// Diameter of the sender avatar in the row gutter.
  final double avatarSize;

  /// Width of the column the avatar sits in.
  ///
  /// Derived rather than hardcoded because the 48 that used to sit in
  /// `timeline_item.dart` was the avatar plus an unstated gap, and anyone
  /// who changed the avatar size had no way to find the other number.
  final double avatarGutter;

  /// Vertical gap between two messages from the same sender.
  ///
  /// Deliberately tight.  Consecutive messages from one person read as a
  /// paragraph, so they get hairline separation.
  final double rowSpacing;

  /// Vertical gap in front of a message that starts a new sender group.
  ///
  /// The gap between groups is the only thing that tells the eye where one
  /// speaker stops and the next begins, since the avatar and name only
  /// appear on the first message of a run.
  final double groupSpacing;

  /// Horizontal padding inside a message bubble.
  final double messagePaddingH;

  /// Vertical padding inside a message bubble.
  final double messagePaddingV;

  /// Hard ceiling on how wide a message may grow before it wraps.
  final double bubbleMaxWidth;

  /// Empty column reserved to the right of a bubble, so bubbles float
  /// instead of forming a full-width slab.  A widget on a narrow pane
  /// should scale this down rather than drop it.
  final double bubbleGutter;

  /// Hard ceiling on the line length of a message body in the flat
  /// (non-bubble) display modes.
  ///
  /// Without this, a message in the expanded dashboard shell runs the full
  /// width of the pane, which at that size is a fifteen-hundred-pixel line of
  /// body text.  Sixty-odd characters is the readability ceiling.
  final double measureMaxWidth;

  /// Width of the accent bar that marks a quoted reply.
  final double replyBarWidth;

  /// Corner radius for reaction chips, which are pills.
  final double reactionRadius;

  /// Minimum height of the composer, so it stays a comfortable tap target.
  final double composerMinHeight;

  /// Sender name is smaller than the body it labels.
  ///
  /// It used to render at exactly the body size in bold, which put two
  /// sixteen-pixel runs a few pixels apart in a tie that weight alone had to
  /// break.  Dropping the label below the content is what creates the
  /// hierarchy.
  static const double _senderScale = 0.8125;
  static const double _senderSizeMin = 12.0;
  static const double _senderSizeMax = 20.0;

  /// Timestamps, the edited marker, and reaction counts are a fixed size.
  ///
  /// They are metadata.  Scaling them with the body meant that at the top of
  /// the user's font-size range the timestamp rendered larger than a default
  /// message body, which inverts the hierarchy the moment anyone used the
  /// accessibility setting the slider exists to support.
  static const double _metadataSize = 11.0;
  static const double _metadataSizeMin = 10.0;

  /// Ceiling on metadata relative to the body, so a very small body size
  /// cannot push the timestamp down into illegibility.
  static const double _metadataMaxBodyRatio = 0.7;

  /// Font size for a sender name, given the user's chosen body size.
  double senderFontSize(double bodySize) =>
      (bodySize * _senderScale).clamp(_senderSizeMin, _senderSizeMax);

  /// Font size for message metadata, given the user's chosen body size.
  double metadataFontSize(double bodySize) {
    final capped = bodySize * _metadataMaxBodyRatio;
    return capped < _metadataSize ? capped.clamp(_metadataSizeMin, _metadataSize)
        : _metadataSize;
  }

  factory MoonrelayChatTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayChatTokens(
      bubbleRadius: MoonrelayDesignTokens.baseCornerRadius,
      avatarSize: t.iconSizeLarge * 1.5,
      avatarGutter: t.iconSizeLarge * 1.5 + t.spaceMd,
      rowSpacing: t.spaceXxs,
      groupSpacing: t.spaceSm,
      // Wider than tall. A bubble whose horizontal padding matches its
      // vertical padding reads as a box drawn around the text rather than a
      // surface the text sits on.
      messagePaddingH: t.spaceMd,
      messagePaddingV: t.spaceSm,
      // Roughly 66 characters of body text at the default size.
      bubbleMaxWidth: 520,
      bubbleGutter: t.spaceXxl * 2,
      measureMaxWidth: 660,
      replyBarWidth: t.spaceXs,
      reactionRadius: t.radiusFull,
      composerMinHeight: t.minTapTarget,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayChatTokens &&
        other.bubbleRadius == bubbleRadius &&
        other.avatarSize == avatarSize &&
        other.avatarGutter == avatarGutter &&
        other.rowSpacing == rowSpacing &&
        other.groupSpacing == groupSpacing &&
        other.messagePaddingH == messagePaddingH &&
        other.messagePaddingV == messagePaddingV &&
        other.bubbleMaxWidth == bubbleMaxWidth &&
        other.bubbleGutter == bubbleGutter &&
        other.measureMaxWidth == measureMaxWidth &&
        other.replyBarWidth == replyBarWidth &&
        other.reactionRadius == reactionRadius &&
        other.composerMinHeight == composerMinHeight;
  }

  @override
  int get hashCode => Object.hashAll([
        bubbleRadius,
        avatarSize,
        avatarGutter,
        rowSpacing,
        groupSpacing,
        messagePaddingH,
        messagePaddingV,
        bubbleMaxWidth,
        bubbleGutter,
        measureMaxWidth,
        replyBarWidth,
        reactionRadius,
        composerMinHeight,
      ]);
}

// -- SnackBar tokens ---------------------------------------------------

@immutable
class MoonrelaySnackBarTokens {
  const MoonrelaySnackBarTokens({
    required this.cornerRadius,
    required this.padding,
    this.contentStyle,
  });

  final double cornerRadius;
  final EdgeInsets padding;
  final TextStyle? contentStyle;

  factory MoonrelaySnackBarTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelaySnackBarTokens(
      cornerRadius: t.radiusSm,
      padding: EdgeInsets.all(t.spaceLg),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelaySnackBarTokens &&
        other.cornerRadius == cornerRadius &&
        other.padding == padding &&
        other.contentStyle == contentStyle;
  }

  @override
  int get hashCode => Object.hashAll([cornerRadius, padding, contentStyle]);
}

// -- Progress tokens ---------------------------------------------------

@immutable
class MoonrelayProgressTokens {
  const MoonrelayProgressTokens({
    required this.strokeWidth,
    required this.linearMinHeight,
  });

  final double strokeWidth;
  final double linearMinHeight;

  factory MoonrelayProgressTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayProgressTokens(
      strokeWidth: t.borderWidthMedium,
      linearMinHeight: t.spaceSm,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayProgressTokens &&
        other.strokeWidth == strokeWidth &&
        other.linearMinHeight == linearMinHeight;
  }

  @override
  int get hashCode => Object.hashAll([strokeWidth, linearMinHeight]);
}

// -- Avatar tokens -----------------------------------------------------

@immutable
class MoonrelayAvatarTokens {
  const MoonrelayAvatarTokens({
    required this.sizeSmall,
    required this.sizeMedium,
    required this.sizeLarge,
    required this.borderWidth,
  });

  final double sizeSmall;
  final double sizeMedium;
  final double sizeLarge;
  final double borderWidth;

  factory MoonrelayAvatarTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayAvatarTokens(
      sizeSmall: t.iconSizeMedium,
      sizeMedium: t.iconSizeLarge * 1.5,
      sizeLarge: t.iconSizeLarge * 2.5,
      borderWidth: t.borderWidthThin,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayAvatarTokens &&
        other.sizeSmall == sizeSmall &&
        other.sizeMedium == sizeMedium &&
        other.sizeLarge == sizeLarge &&
        other.borderWidth == borderWidth;
  }

  @override
  int get hashCode => Object.hashAll([
        sizeSmall,
        sizeMedium,
        sizeLarge,
        borderWidth,
      ]);
}

// -- Tooltip tokens ----------------------------------------------------

@immutable
class MoonrelayTooltipTokens {
  const MoonrelayTooltipTokens({
    required this.cornerRadius,
    required this.padding,
    this.textStyle,
  });

  final double cornerRadius;
  final EdgeInsets padding;
  final TextStyle? textStyle;

  factory MoonrelayTooltipTokens.fromDesignTokens(MoonrelayDesignTokens t) {
    return MoonrelayTooltipTokens(
      cornerRadius: t.radiusSm,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: t.spaceXs,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayTooltipTokens &&
        other.cornerRadius == cornerRadius &&
        other.padding == padding &&
        other.textStyle == textStyle;
  }

  @override
  int get hashCode => Object.hashAll([cornerRadius, padding, textStyle]);
}
