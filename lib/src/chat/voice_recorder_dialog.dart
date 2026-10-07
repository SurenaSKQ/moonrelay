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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Opens a voice-note recorder dialog. The user can record audio, preview
/// the result, and either discard or send it as an `m.audio` event.
///
/// The recording is captured with [`record`](https://pub.dev/packages/record),
/// previewed locally as a byte buffer, and then sent via
/// [Room.sendFileEvent] using the standard `m.audio` `msgtype`.
Future<void> showVoiceRecorderDialog(BuildContext context, Room room) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _VoiceRecorderDialog(room: room),
  );
}

class _VoiceRecorderDialog extends StatefulWidget {
  const _VoiceRecorderDialog({required this.room});
  final Room room;

  @override
  State<_VoiceRecorderDialog> createState() => _VoiceRecorderDialogState();
}

class _VoiceRecorderDialogState extends State<_VoiceRecorderDialog> {
  final AudioRecorder _recorder = AudioRecorder();

  Timer? _ticker;
  bool _isRecording = false;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  bool _sending = false;
  bool _permissionDenied = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissionStatus() async {
    final status = await Permission.microphone.status;
    if (!mounted) return;
    setState(() => _permissionDenied = !status.isGranted);
  }

  Future<void> _ensurePermission() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.voiceRecorderPermissionDenied),
        ),
      );
    } else {
      setState(() => _permissionDenied = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      await _ensurePermission();
      if (_permissionDenied) return;

      final dir = Directory.systemTemp;
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${dir.path}/$filename';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _filePath = path;
        _elapsed = Duration.zero;
        _error = null;
      });

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_isRecording) return;
        setState(() => _elapsed += const Duration(milliseconds: 200));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _ticker?.cancel();
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _filePath = path ?? _filePath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _error = e;
      });
    }
  }

  Future<void> _discard() async {
    final path = _filePath;
    _filePath = null;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.voiceRecorderCancelled),
      ),
    );
  }

  Future<void> _send() async {
    final path = _filePath;
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return;

      if (!mounted) return;
      setState(() => _sending = true);

      await withRetry(
        () => widget.room.sendFileEvent(
          MatrixFile(
            bytes: bytes,
            name: path.split(Platform.pathSeparator).last,
          ),
        ),
        maxRetries: 1,
        timeout: kUploadTimeout,
        log: null,
        label: 'voiceNote',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e;
      });
    }
  }

  String _formatElapsed() {
    final minutes = _elapsed.inMinutes.remainder(60).toString();
    final seconds = _elapsed.inSeconds.remainder(60).toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(int.parse(minutes))}:${two(int.parse(seconds))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return AlertDialog(
      title: Text(l10n.voiceRecorderTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_permissionDenied)
              Padding(
                padding: EdgeInsets.only(bottom: t.spaceMd),
                child: Text(
                  l10n.voiceRecorderPermissionDenied,
                  style: TextStyle(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(bottom: t.spaceMd),
                child: Text(
                  '${l10n.error}: $_error',
                  style: TextStyle(color: cs.error),
                ),
              ),
            if (_sending) ...[
              const CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: t.spaceMd),
              Text(l10n.voiceRecorderSending),
            ] else if (_isRecording) ...[
              // -- Recording state ---------------------------------------
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.spaceLg,
                  vertical: t.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(t.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cs.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: t.spaceSm),
                    Text(
                      l10n.voiceRecorderDuration(
                        (_elapsed.inMilliseconds / 1000).toStringAsFixed(1),
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.spaceLg),
              Text(
                _formatElapsed(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: t.spaceMd),
              IconButton.filled(
                icon: const Icon(LucideIcons.square),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  padding: EdgeInsets.all(t.spaceLg),
                ),
                tooltip: l10n.stopRecording,
                onPressed: _stopRecording,
              ),
            ] else if (_filePath != null) ...[
              // -- Preview state -----------------------------------------
              Row(
                children: [
                  Icon(LucideIcons.checkCircle, color: cs.primary, size: 22),
                  SizedBox(width: t.spaceSm),
                  Expanded(
                    child: Text(
                      _formatElapsed(),
                      style: TextStyle(
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceSm),
              Text(
                l10n.voiceRecorderTitle,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ] else ...[
              // -- Idle state --------------------------------------------
              Text(
                l10n.voiceRecorderHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: t.spaceLg),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isRecording && _filePath != null && !_sending) ...[
          TextButton(
            onPressed: _sending ? null : _discard,
            child: Text(l10n.voiceRecorderDiscard),
          ),
          FilledButton.icon(
            icon: const Icon(LucideIcons.send, size: 18),
            label: Text(l10n.voiceRecorderSend),
            onPressed: _sending ? null : _send,
          ),
        ] else if (!_isRecording && _filePath == null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          IconButton.filled(
            icon: const Icon(LucideIcons.mic),
            iconSize: 28,
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(14),
            ),
            tooltip: l10n.recordVoiceNote,
            onPressed: _sending ? null : _startRecording,
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ],
    );
  }
}
