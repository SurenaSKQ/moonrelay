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
import 'package:moonrelay/src/settings/theme_spec.dart';
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

  /// Derives all component tokens from [tokens] and [spec].
  factory MoonrelayComponentTokens.fromDesignTokens(
    MoonrelayDesignTokens tokens,
    MoonrelayThemeSpec spec,
  ) {
    return MoonrelayComponentTokens(
      button: MoonrelayButtonTokens.fromDesignTokens(tokens),
      input: MoonrelayInputTokens.fromDesignTokens(tokens),
      card: MoonrelayCardTokens.fromDesignTokens(tokens, spec),
      appBar: MoonrelayAppBarTokens.fromDesignTokens(tokens),
      list: MoonrelayListTokens.fromDesignTokens(tokens),
      dialog: MoonrelayDialogTokens.fromDesignTokens(tokens, spec),
      divider: MoonrelayDividerTokens.fromDesignTokens(tokens),
      chip: MoonrelayChipTokens.fromDesignTokens(tokens),
      badge: MoonrelayBadgeTokens.fromDesignTokens(tokens),
      navigation: MoonrelayNavigationTokens.fromDesignTokens(tokens),
      chat: MoonrelayChatTokens.fromDesignTokens(tokens, spec),
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

  factory MoonrelayCardTokens.fromDesignTokens(
    MoonrelayDesignTokens t,
    MoonrelayThemeSpec spec,
  ) {
    return MoonrelayCardTokens(
      elevation: spec.surfaceElevation,
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

  factory MoonrelayDialogTokens.fromDesignTokens(
    MoonrelayDesignTokens t,
    MoonrelayThemeSpec spec,
  ) {
    return MoonrelayDialogTokens(
      cornerRadius: spec.cornerRadius,
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

@immutable
class MoonrelayChatTokens {
  const MoonrelayChatTokens({
    required this.bubbleRadius,
    required this.avatarSize,
    required this.spacing,
    required this.messagePaddingH,
    required this.messagePaddingV,
    required this.replyBarWidth,
    required this.reactionRadius,
    required this.composerMinHeight,
  });

  final double bubbleRadius;
  final double avatarSize;
  final double spacing;
  final double messagePaddingH;
  final double messagePaddingV;
  final double replyBarWidth;
  final double reactionRadius;
  final double composerMinHeight;

  factory MoonrelayChatTokens.fromDesignTokens(
    MoonrelayDesignTokens t,
    MoonrelayThemeSpec spec,
  ) {
    return MoonrelayChatTokens(
      bubbleRadius: spec.defaultBubbleRadius,
      avatarSize: t.iconSizeLarge * 1.5,
      spacing: t.spaceSm,
      messagePaddingH: t.spaceLg,
      messagePaddingV: t.spaceSm,
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
        other.spacing == spacing &&
        other.messagePaddingH == messagePaddingH &&
        other.messagePaddingV == messagePaddingV &&
        other.replyBarWidth == replyBarWidth &&
        other.reactionRadius == reactionRadius &&
        other.composerMinHeight == composerMinHeight;
  }

  @override
  int get hashCode => Object.hashAll([
        bubbleRadius,
        avatarSize,
        spacing,
        messagePaddingH,
        messagePaddingV,
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
