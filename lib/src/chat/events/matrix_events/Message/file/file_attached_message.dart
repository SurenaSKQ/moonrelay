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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/events/attachment_card.dart';
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/attachment_download_policy.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/sidebar_row.dart';
import 'package:provider/provider.dart';

/// Displays a file attachment with a polished card showing file type icon,
/// name, size, and a download button.
class FileAttachedMessage extends StatefulWidget {
  const FileAttachedMessage({super.key, required this.event});
  final Event event;

  @override
  State<FileAttachedMessage> createState() => _FileAttachedMessageState();
}

class _FileAttachedMessageState extends State<FileAttachedMessage> {
  Future<MatrixFile>? _downloadFuture;

  /// Last error surfaced by the save flow.  When non-null, the bubble's
  /// styling switches to error tones and the save icon flips to a retry
  /// glyph instead of letting the user repeatedly trigger the same
  /// failure silently.
  Object? _lastError;

  bool _autoDownloadResolved = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAutoDownload();
  }

  void _resolveAutoDownload() {
    if (_autoDownloadResolved) return;
    _autoDownloadResolved = true;
    if (!widget.event.hasAttachment) return;
    // The file bubble already renders its own download control and calls
    // [_downloadOnDemand], so gating the auto-download is all that is
    // needed here: a large file waits for that button.
    final policy = AttachmentDownloadPolicy.of(
      context,
      event: widget.event,
      mediaPolicy: context.read<SettingsController>().autoDownloadFiles,
    );
    if (!policy.shouldAutoDownload) return;
    _downloadFuture = widget.event.downloadAndDecryptAttachment();
  }

  // ---- Content helpers ----

  String? get _fileName => widget.event.content['filename']?.toString();
  String? get _mimeType => widget.event.content['mimetype']?.toString();
  String? get _extension {
    final name = _fileName;
    if (name == null) return null;
    return name.split('.').last.toUpperCase();
  }

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  int? get _fileSize => _infoMap['size'] as int?;

  /// Returns an appropriate icon based on file extension / MIME type.
  ///
  /// Lucide rather than Material, because the rest of the app is Lucide and a
  /// Material glyph next to a Lucide one reads as two icon sets rather than as
  /// one drawing. The archive box for a PDF was the worst of it: a PDF is not
  /// a picture, and the icon it used was `picture_as_pdf`, a picture.
  IconData _fileIcon() {
    final ext = _extension ?? '';
    final mime = _mimeType ?? '';
    if (ext.contains('PDF') || mime.contains('pdf')) {
      return LucideIcons.fileText;
    }
    if (ext.contains('ZIP') ||
        ext.contains('RAR') ||
        ext.contains('TAR') ||
        ext.contains('GZ') ||
        ext.contains('7Z')) {
      return LucideIcons.archive;
    }
    if (ext.contains('DOC') ||
        ext.contains('DOCX') ||
        ext.contains('XLS') ||
        ext.contains('XLSX') ||
        ext.contains('PPT') ||
        ext.contains('PPTX')) {
      return LucideIcons.fileSpreadsheet;
    }
    if (ext.contains('TXT') || mime.contains('text')) {
      return LucideIcons.alignLeft;
    }
    if (mime.startsWith('image/')) return LucideIcons.image;
    if (mime.startsWith('audio/')) return LucideIcons.music;
    if (mime.startsWith('video/')) return LucideIcons.video;
    return LucideIcons.file;
  }

  // ---- Actions ----

  /// Saves [attFile] to a user-chosen location.  Called when bytes are
  /// already in memory (auto-download policy was anything other than
  /// "never" or the bytes were already downloaded by another code path).
  Future<void> _downloadFile(MatrixFile attFile) async {
    try {
      await FilePicker.saveFile(
        dialogTitle: AppLocalizations.of(context)!.selectDownloadTarget,
        fileName: _fileName ?? 'file',
        bytes: attFile.bytes,
      );
    } on Object catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st));
      if (mounted) setState(() => _lastError = e);
    }
  }

  /// Ad-hoc download: pull the attachment when the user explicitly
  /// asks for it even if the auto-download policy is "never".  Caches
  /// the bytes via the shared [RoomMediaCache] so a second press (or a
  /// different widget for the same event) reuses the result.
  ///
  /// Uses block-body lambdas for `setState` because the arrow form
  /// `() => _x = future` returns the assigned `Future`, which
  /// `State.setState` rejects as "the closure returned a Future".
  Future<void> _downloadOnDemand() async {
    final future = RoomMediaCache.instance.getOrDownload(
      widget.event.roomId ?? widget.event.eventId,
      widget.event.eventId,
      () => widget.event.downloadAndDecryptAttachment(),
    );
    setState(() {
      _downloadFuture = future;
      _lastError = null;
    });
    try {
      final mf = await future;
      if (!mounted) return;
      await _downloadFile(mf);
    } on Object catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st));
      if (mounted) setState(() => _lastError = e);
    } finally {
      if (mounted) {
        setState(() {
          _downloadFuture = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final matrixFile = snapshot.data;

        return AttachmentCard(
          maxWidth: MediaSizePrefs.of(context).fileMax,
          isError: _lastError != null,
          child: Row(
            children: [
              // -- File type icon --------------------------------------
              // No tap target: it names the type of the thing, and offering a
              // button that does nothing is worse than offering nothing.
              AttachmentLeadingIcon(
                icon: _lastError != null
                    ? LucideIcons.triangleAlert
                    : _fileIcon(),
                isError: _lastError != null,
              ),
              SizedBox(width: t.spaceMd),

              // -- File info -------------------------------------------
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fileName ?? l10n.unknown,
                      style: TextStyle(
                        fontSize: sidebarMetricsFor(context).titleSize,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: t.spaceXxs),
                    // One row, shared with the audio and video rows, so the
                    // extension and the size land in the same place on every
                    // attachment. They had each built their own and drifted:
                    // one led with the badge and one trailed with it.
                    AttachmentMetaRow(
                      leading: _extension == null
                          ? null
                          : AttachmentBadge(label: _extension!),
                      parts: [
                        if (_fileSize != null)
                          AttachmentDownloadPolicy.formatSize(
                            context,
                            _fileSize,
                          )!,
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.spaceSm),

              // -- Download button -------------------------------------
              Semantics(
                label: _lastError != null ? l10n.tapToRetry : l10n.downloadFile,
                button: true,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? Center(
                        child: SizedBox(
                          width: t.iconSizeMedium,
                          height: t.iconSizeMedium,
                          child: CircularProgressIndicator(
                            strokeWidth: t.borderWidthMedium * 2,
                            color: cs.primary,
                          ),
                        ),
                      )
                    : AttachmentLeadingIcon(
                        // Quiet. This is not the thing the row is for; the
                        // file's name and type are, and a second accent square
                        // competed with the leading glyph for the same
                        // attention.
                        emphasis: AttachmentEmphasis.quiet,
                        icon: _lastError != null
                            ? LucideIcons.rotateCw
                            : LucideIcons.download,
                        isError: _lastError != null,
                        onTap: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? null
                            : () async {
                                  if (isReady && matrixFile != null) {
                                    await _downloadFile(matrixFile);
                                  } else {
                                    await _downloadOnDemand();
                                  }
                                },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

