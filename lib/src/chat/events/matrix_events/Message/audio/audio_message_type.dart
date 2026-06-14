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

/// Displays an audio message with file info, duration, and a download button.
///
/// A future iteration may replace the download action with in-app playback
/// using a low-level audio package (e.g. `flutter_soloud` or `just_audio`).
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
      (_fileName?.split('.').last ?? 'audio').toUpperCase();

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  /// Duration in milliseconds from the content's info blob.
  int? get _duration => _infoMap['duration'] as int?;

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ---- Actions ----

  Future<void> _downloadFile() async {
    if (_downloadFuture == null) return;
    final attFile = await _downloadFuture!;
    await FilePicker.saveFile(
      dialogTitle: 'Save audio',
      fileName: _fileName,
      bytes: attFile.bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 80, maxWidth: 320),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Audio icon (pulsing while loading)
                  Icon(
                    isReady ? Icons.music_note : Icons.sync,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),

                  // File metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fileName ?? 'audio_file',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Rubik',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_extension${_duration != null ? " · ${_formatDuration(_duration!)}" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Rubik',
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Download button
                  Tooltip(
                    message: 'Download audio',
                    child: IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: isReady ? _downloadFile : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
