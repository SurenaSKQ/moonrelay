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

class VideoMessageType extends StatelessWidget {
  const VideoMessageType({super.key, required this.event});
  final Event event;

  Future<void> _downloadFile() async {
    if (event.hasAttachment) {
      final attFile = await event.downloadAndDecryptAttachment();
      await FilePicker.saveFile(
        dialogTitle: 'Save video',
        fileName: _fileName,
        bytes: attFile.bytes,
      );
    }
  }

  String? get _fileName => event.content['filename']?.toString();
  String? get _mimeType => event.content['mimetype']?.toString();

  /// Duration in milliseconds from the content's info blob.
  int? get _duration => event.content['info'] is Map
      ? (event.content['info'] as Map)['duration'] as int?
      : null;

  /// Human-friendly duration, e.g. "1:23".
  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 80, maxWidth: 280),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Video icon
              Icon(
                Icons.videocam,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fileName ?? 'video_file',
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
                      '${_mimeType ?? "Unknown type"}${_duration != null ? " · ${_formatDuration(_duration!)}" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Rubik',
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Download button
              Tooltip(
                message: 'Download video',
                child: IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  onPressed: _downloadFile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
