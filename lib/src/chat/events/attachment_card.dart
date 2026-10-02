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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The surface every control-bearing attachment sits on.
///
/// Audio, file, video, location, and poll each grew their own container and
/// they drifted: the audio card padded with `spaceMd` and the file card with
/// a literal 14, the error fill was `errorContainer` at `opacitySubtle` in
/// one and `opacityDisabled` in the other, and the three width caps came
/// from three different preferences. None of those differences were load
/// bearing, and together they meant a scroll of mixed attachments read as a
/// handful of unrelated components rather than as one kind of thing.
///
/// One container, one fill, one border, one radius, one padding. The error
/// state is a variant of the same surface rather than a second design.
///
/// Pictures are deliberately *not* cards. A photo or a sticker in a chat is
/// the photograph, and boxing it puts a frame around something that was
/// already a finished image; the image and sticker renderers stay
/// chrome-free and take only a radius from the token scale. What earns a
/// card is a surface with controls on it, which is why the audio scrubber
/// and the file download button get one and a photograph does not.
class AttachmentCard extends StatelessWidget {
  const AttachmentCard({
    super.key,
    required this.child,
    required this.maxWidth,
    this.footer,
    this.flushChild = false,
    this.isError = false,
  });

  /// The attachment's own content, already laid out as a column or a row.
  final Widget child;

  /// Optional metadata row below [child], such as the filename and duration
  /// strip under a video.
  ///
  /// When present the card switches to a flush layout: [child] runs to the
  /// card's edges and the padding is applied to the footer alone. A video
  /// player inset inside twelve pixels of padding reads as a small screen in
  /// a box; the same twelve pixels around an audio row is just padding.
  final Widget? footer;

  /// Width cap for the card, from [MediaSizePrefs] in the calling renderer.
  final double maxWidth;

  /// Whether [child] should run to the card's edges rather than sit inside
  /// the card's padding. Implied by [footer].
  final bool flushChild;

  /// Swaps the surface to its error treatment.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final cs = Theme.of(context).colorScheme;
    final footer = this.footer;
    final flush = flushChild || footer != null;
    final body = flush ? child : Padding(padding: EdgeInsets.all(t.spaceMd), child: child);

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isError
            ? cs.errorContainer.withValues(alpha: t.opacityDisabled)
            : cs.surfaceContainerHighest.withValues(alpha: t.opacityDisabled),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(
          color: isError
              ? cs.error.withValues(alpha: t.opacitySubtle)
              : cs.outlineVariant.withValues(alpha: t.opacityDisabled),
        ),
      ),
      child: footer == null
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                body,
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.spaceMd,
                    t.spaceSm,
                    t.spaceSm,
                    t.spaceSm,
                  ),
                  child: footer,
                ),
              ],
            ),
    );
  }
}

/// The tinted square that leads an attachment row: a play control, a file
/// type glyph, a video icon.
///
/// Sized here rather than at each call site so the audio, file, and video
/// rows line up against each other down the timeline. The three had drifted
/// to 44, 44, and 36 pixels, and a video row sat visibly shorter than the
/// file row above it.
class AttachmentLeadingIcon extends StatelessWidget {
  const AttachmentLeadingIcon({
    super.key,
    required this.icon,
    this.isError = false,
    this.size = 44,
    this.iconSize = 22,
    this.onTap,
  });

  final IconData icon;
  final bool isError;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final cs = Theme.of(context).colorScheme;
    final tint =
        isError ? cs.error : cs.primary;
    final radius = t.radiusMd;

    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: t.opacityFocus),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: tint),
    );

    if (onTap == null) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: box,
        ),
      ),
    );
  }
}

/// Small uppercase tag for a file extension or MIME subtype.
class AttachmentBadge extends StatelessWidget {
  const AttachmentBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceXs,
        vertical: t.spaceXxs,
      ),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: t.opacitySubtle),
        borderRadius: BorderRadius.circular(t.radiusXs),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: cs.onTertiaryContainer,
        ),
      ),
    );
  }
}