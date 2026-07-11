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

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';

/// Displays an audio message with an in-app `just_audio` player.
///
/// The widget downloads the encrypted attachment, exposes a play/pause
/// toggle, a scrub slider bound to the player's position, and a save
/// button for the rare case the user wants to keep a local copy.
class AudioMessageType extends StatefulWidget {
  const AudioMessageType({super.key, required this.event});
  final Event event;

  @override
  State<AudioMessageType> createState() => _AudioMessageTypeState();
}

class _AudioMessageTypeState extends State<AudioMessageType> {
  Future<MatrixFile>? _downloadFuture;
  final AudioPlayer _player = AudioPlayer();
  Uint8List? _bytes;
  bool _isReady = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.event.hasAttachment) {
      _downloadFuture = widget.event.downloadAndDecryptAttachment().then((m) {
        final bytes = m.bytes;
        _bytes = bytes;
        // Defer play start until next frame so we can attach the URL.
        return m;
      });
    }
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    _player.playerStateStream.listen((s) {
      if (mounted) {
        setState(() {
          _isPlaying = s.playing;
          _isReady = s.processingState != ProcessingState.loading;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ---- Content helpers ----

  String? get _fileName => widget.event.content['filename']?.toString();

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  int? get _durationMs => _infoMap['duration'] as int?;
  int? get _fileSize => _infoMap['size'] as int?;

  String get _extension {
    final n = _fileName;
    if (n == null) return 'AUDIO';
    return n.split('.').last.toUpperCase();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---- Actions ----

  Future<void> _ensureAttached() async {
    if (_bytes == null) return;
    try {
      // just_audio can't stream `mxc://` URLs directly, so we materialise
      // the attachment in a temp file. The bytes are already in memory
      // (decrypted by the SDK), so this is just a flip to a [FileSource].
      final name = _fileName ?? 'audio_${widget.event.eventId}.m4a';
      final tmp = File('${Directory.systemTemp.path}/moonrelay_$name')
        ..writeAsBytesSync(_bytes!);
      await _player.setFilePath(tmp.path);
    } catch (_) {}
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _ensureAttached();
      await _player.play();
    }
  }

  Future<void> _seekTo(double value) async {
    final d = _duration;
    if (d == Duration.zero) return;
    final newPos = Duration(
      milliseconds: (value * d.inMilliseconds).round(),
    );
    await _player.seek(newPos);
    if (mounted) setState(() => _position = newPos);
  }

  Future<void> _downloadFile() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final l10n = AppLocalizations.of(context)!;
    await FilePicker.saveFile(
      dialogTitle: l10n.saveAudio,
      fileName: _fileName ?? 'audio.$_extension',
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.hasData;
        final displayPos = _position.inSeconds.toDouble();
        final displayDur = (_duration.inSeconds == 0
                ? _durationMs ?? 0
                : _duration.inMilliseconds) /
            1000.0;
        final progress = displayDur == 0
            ? 0.0
            : (displayPos / displayDur).clamp(0.0, 1.0);

        return Container(
          constraints: BoxConstraints(maxWidth: MediaSizePrefs.of(context).audioMax),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Play/Pause button (or download icon while loading).
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: cs.primary,
                      size: 22,
                    ),
                    onPressed: isReady && _isReady ? _togglePlay : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Track + metadata
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
                      const SizedBox(height: 6),

                      // Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: isReady ? _seekTo : null,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Time/duration and badges
                      Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(_duration == Duration.zero
                                ? Duration(milliseconds: _durationMs ?? 0)
                                : _duration),
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer
                                  .withValues(alpha: 0.5),
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
                          if (_fileSize != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatSize(_fileSize!),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Save button
                Tooltip(
                  message: l10n.downloadAudio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(
                        LucideIcons.download,
                        size: 18,
                        color: cs.primary,
                      ),
                      onPressed: isReady ? _downloadFile : null,
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