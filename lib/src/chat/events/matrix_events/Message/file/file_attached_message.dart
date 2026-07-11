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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.event.hasAttachment) {
      _downloadFuture = widget.event.downloadAndDecryptAttachment();
    }
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Returns an appropriate icon based on file extension / MIME type.
  IconData _fileIcon() {
    final ext = _extension ?? '';
    final mime = _mimeType ?? '';
    if (ext.contains('PDF') || mime.contains('pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (ext.contains('ZIP') ||
        ext.contains('RAR') ||
        ext.contains('TAR') ||
        ext.contains('GZ') ||
        ext.contains('7Z')) {
      return Icons.folder_zip_rounded;
    }
    if (ext.contains('DOC') ||
        ext.contains('DOCX') ||
        ext.contains('XLS') ||
        ext.contains('XLSX') ||
        ext.contains('PPT') ||
        ext.contains('PPTX')) {
      return Icons.description_rounded;
    }
    if (ext.contains('TXT') || mime.contains('text')) {
      return Icons.article_outlined;
    }
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('audio/')) return Icons.music_note_rounded;
    if (mime.startsWith('video/')) return Icons.videocam_rounded;
    return Icons.insert_drive_file_outlined;
  }

  // ---- Actions ----

  Future<void> _downloadFile(MatrixFile attFile) async {
    await FilePicker.saveFile(
      dialogTitle: AppLocalizations.of(context)!.selectDownloadTarget,
      fileName: _fileName ?? 'file',
      bytes: attFile.bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final matrixFile = snapshot.data;

        return Container(
          constraints: BoxConstraints(maxWidth: MediaSizePrefs.of(context).fileMax),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ── File type icon ──────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _fileIcon(),
                    size: 22,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 14),

                // ── File info ───────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fileName ?? l10n.unknown,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Extension badge
                          if (_extension != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    cs.tertiaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _extension!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onTertiaryContainer,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          if (_fileSize != null) ...[
                            if (_extension != null) const SizedBox(width: 8),
                            Icon(Icons.archive_outlined,
                                size: 12,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.6)),
                            const SizedBox(width: 2),
                            Text(
                              _formatSize(_fileSize!),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Download button ─────────────────────────────────────
                Tooltip(
                  message: l10n.downloadAudio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.download_rounded, size: 20),
                      color: cs.primary,
                      onPressed: isReady && matrixFile != null
                          ? () => _downloadFile(matrixFile)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
