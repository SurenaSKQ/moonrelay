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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

/// Shared decision for whether an attachment should start downloading
/// when its bubble is first shown.
///
/// Two settings feed in. [AutoDownloadPolicy] is the per-media-type
/// always / wifi / never choice the user already had, and
/// `SettingsController.attachmentClickThresholdMb` is the size guard on
/// top of it: anything larger than the threshold wants an explicit click
/// regardless of the policy.
///
/// Before this existed, each of the five renderers carried its own copy
/// of the policy switch and ignored the size threshold entirely, so a
/// 400 MB video on a metered connection downloaded silently.
class AttachmentDownloadPolicy {
  const AttachmentDownloadPolicy({
    required this.shouldAutoDownload,
    required this.requiresExplicitClick,
    required this.knownSizeBytes,
  });

  /// Permissive default for widgets that build before the settings
  /// controller is readable, and for isolated tests with no provider.
  /// Downloading is the pre-threshold behaviour, so this fails open on
  /// the side of showing the attachment rather than hiding it.
  static const AttachmentDownloadPolicy permissive = AttachmentDownloadPolicy(
    shouldAutoDownload: true,
    requiresExplicitClick: false,
    knownSizeBytes: null,
  );

  /// The same decision as [permissive] but with the size no longer
  /// gating, used once the user has explicitly asked for the download.
  AttachmentDownloadPolicy asDownloading() => AttachmentDownloadPolicy(
        shouldAutoDownload: true,
        requiresExplicitClick: false,
        knownSizeBytes: knownSizeBytes,
      );

  /// This decision with the size threshold dropped, honouring only the
  /// media policy.
  ///
  /// For stickers, which are small by nature and have no
  /// sticker-specific policy of their own. A threshold here would only
  /// ever replace a sticker with a "click to download" tile, which is a
  /// worse outcome than fetching a few hundred KB.
  AttachmentDownloadPolicy get ignoringSizeThreshold => AttachmentDownloadPolicy(
        shouldAutoDownload: shouldAutoDownload || requiresExplicitClick,
        requiresExplicitClick: false,
        knownSizeBytes: knownSizeBytes,
      );

  /// Whether to start the download on first render.
  final bool shouldAutoDownload;

  /// Whether the download is being withheld for size. Distinguishes
  /// "too big, click to fetch" from "your policy says never", which the
  /// bubble needs to say different things and offer different actions.
  final bool requiresExplicitClick;

  /// The attachment size in bytes, or `null` when the event carries no
  /// `info.size`. An unknown size cannot be compared against the
  /// threshold, so it is treated as small enough to honour the policy.
  final int? knownSizeBytes;

  /// Attachment size in bytes from the event's `info` blob.
  ///
  /// Returns `null` when `info` is missing or malformed rather than
  /// guessing a size, so the caller can decide the conservative policy.
  static int? sizeOf(Event event) {
    final info = event.content['info'];
    if (info is! Map) return null;
    final raw = info['size'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  /// Resolves the combined policy for [event] given its [mediaPolicy].
  ///
  /// Falls back to "download" when no [SettingsController] is in the
  /// tree, matching the previous behaviour of the five call sites and
  /// keeping isolated widget tests working.
  factory AttachmentDownloadPolicy.of(
    BuildContext context, {
    required Event event,
    required AutoDownloadPolicy mediaPolicy,
  }) {
    // The size is read first and unconditionally: it comes off the event
    // itself and is useful to display regardless of whether a settings
    // controller is in the tree. Only the threshold depends on the
    // controller, and a missing one falls back to the stored default.
    final size = sizeOf(event);
    var thresholdMb = defaultThresholdMb;
    try {
      thresholdMb = context.read<SettingsController>().attachmentClickThresholdMb;
    } catch (_) {
      // No controller in the tree; keep the default threshold.
    }

    final policyAllows = switch (mediaPolicy) {
      AutoDownloadPolicy.always || AutoDownloadPolicy.wifi => true,
      AutoDownloadPolicy.never => false,
    };

    // Only enforce the threshold when the size is actually known. An
    // absent `info.size` must not silently become "too big to download",
    // or events from clients that omit the field would never load.
    final overThreshold = size != null &&
        size > thresholdMb * 1024 * 1024;

    return AttachmentDownloadPolicy(
      shouldAutoDownload: policyAllows && !overThreshold,
      requiresExplicitClick: policyAllows && overThreshold,
      knownSizeBytes: size,
    );
  }

  /// Default click-to-download threshold, used when the settings
  /// controller is unavailable. Matches the stored default of 20 MB.
  static const int defaultThresholdMb = 20;

  /// Human-readable size for the click-to-download affordance.
  ///
  /// Returns `null` when the size is unknown, so the caller can fall back
  /// to a generic label rather than printing a wrong number.
  ///
  /// Deliberately does not require localizations: the unit abbreviations
  /// are the same in every language the app ships, and a size shown on a
  /// tap target should not disappear in a widget test or a context
  /// without an `AppLocalizations` ancestor.
  static String? formatSize(BuildContext context, int? bytes) {
    if (bytes == null || bytes < 0) return null;
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final rendered = value >= 10 || unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$rendered ${units[unit]}';
  }
}

/// The placeholder shown in place of an attachment whose download is being
/// withheld until a click.
///
/// Shared so image, video, audio and file bubbles all offer the same
/// affordance instead of each rendering a dead icon with no tap handler,
/// which is what the per-renderer placeholders did before.
class ClickToDownloadTile extends StatelessWidget {
  const ClickToDownloadTile({
    super.key,
    required this.policy,
    required this.onDownload,
    this.icon = Icons.download_outlined,
    this.width = 180,
    this.height = 120,
  });

  final AttachmentDownloadPolicy policy;
  final VoidCallback onDownload;
  final IconData icon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final size = AttachmentDownloadPolicy.formatSize(
      context,
      policy.knownSizeBytes,
    );

    return Semantics(
      button: true,
      label: l10n.clickToDownload,
      child: InkWell(
        onTap: onDownload,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                l10n.clickToDownload,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (size != null) ...[
                const SizedBox(height: 2),
                Text(
                  size,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
