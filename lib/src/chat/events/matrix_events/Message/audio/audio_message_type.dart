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

/// Displays an audio message with a polished card, waveform visual, and
/// download action. A future iteration may replace the download with an
/// in-app audio player.
class AudioMessageType extends StatefulWidget {
  const AudioMessageType({super.key, required this.event});
  final Event event;

  @override
  State<AudioMessageType> createState() => _AudioMessageTypeState();
}

class _AudioMessageTypeState extends State<AudioMessageType> {
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
  String get _extension =>
      (_fileName?.split('.').last ?? 'AUDIO').toUpperCase();

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  int? get _duration => _infoMap['duration'] as int?;
  int? get _fileSize => _infoMap['size'] as int?;

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---- Actions ----

  Future<void> _downloadFile(MatrixFile attFile) async {
    await FilePicker.saveFile(
      dialogTitle: AppLocalizations.of(context)!.saveAudio,
      fileName: _fileName,
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
          constraints: const BoxConstraints(maxWidth: 340),
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
                // Audio icon with pulse ring
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isReady ? Icons.music_note_rounded : Icons.sync_rounded,
                    size: 22,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 14),

                // Metadata column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fileName ?? l10n.audioFileName,
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
                              _extension,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cs.onTertiaryContainer,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (_duration != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.schedule_outlined,
                                size: 12,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.6)),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(_duration!),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          if (_fileSize != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatSize(_fileSize!),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Waveform placeholder (future player)
                      if (isReady) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Container(
                            height: 24,
                            color: cs.primary.withValues(alpha: 0.08),
                            child: Row(
                              children: List.generate(
                                30,
                                (i) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    child: _WaveformBar(
                                      isTall: i % 5 == 0,
                                      isMedium: i % 3 == 0,
                                      color: cs.primary.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Download button
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

/// A single bar in the simulated audio waveform.
class _WaveformBar extends StatelessWidget {
  const _WaveformBar({
    required this.isTall,
    required this.isMedium,
    required this.color,
  });

  final bool isTall;
  final bool isMedium;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = isTall
        ? 20.0
        : isMedium
            ? 14.0
            : 8.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
