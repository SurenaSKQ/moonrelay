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
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  final ValueNotifier<bool> _isReady = ValueNotifier(false);

  /// Set when the most recent load or playback attempt failed.  We
  /// swallow the underlying error so a transient network blip doesn't
  /// throw across the widget tree; instead we surface a retry chip.
  Object? _lastError;
  Uint8List? _bytes;
  bool _autoDownloadResolved = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to streams once and forward to per-stream
    // [ValueNotifier]s so the leaf widgets (slider, play/pause
    // icon) rebuild via [ValueListenableBuilder] instead of forcing
    // a full widget-tree rebuild. The previous implementation called
    // `setState` from three separate stream listeners: for a
    // position that ticks at ~10 Hz during playback that produced
    // 10 setState calls per second per audio message.
    _player.positionStream.listen((p) => _position.value = p);
    _player.durationStream.listen((d) {
      if (d != null) _duration.value = d;
    });
    _player.playerStateStream.listen((s) {
      _isPlaying.value = s.playing;
      _isReady.value = s.processingState != ProcessingState.loading;
    });
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
    // The play button already routes through _downloadOnDemand, so a
    // withheld audio just waits for the user rather than needing its own
    // placeholder.
    final policy = AttachmentDownloadPolicy.of(
      context,
      event: widget.event,
      mediaPolicy: context.read<SettingsController>().autoDownloadFiles,
    );
    if (!policy.shouldAutoDownload) return;
    // Share the in-flight future with the global cache so audio
    // re-entries (e.g. scrolling away and back) don't re-download.
    // `roomId` is nullable on the SDK type; fall back to the event
    // id (which is guaranteed non-null) so the cache key stays valid
    // even before the event has been attached to a room.
    _downloadFuture = RoomMediaCache.instance.getOrDownload(
      widget.event.roomId ?? widget.event.eventId,
      widget.event.eventId,
      () => widget.event.downloadAndDecryptAttachment(),
    );
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
    } on Object catch (e, st) {
      // Don't crash the chat; log and surface the failure.
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st));
      if (mounted) setState(() => _lastError = e);
      rethrow;
    }
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying.value) {
        await _player.pause();
      } else {
        await _ensureAttached();
        await _player.play();
      }
    } on Object catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st));
      if (mounted) setState(() => _lastError = e);
    }
  }

  Future<void> _seekTo(double value) async {
    final d = _duration.value;
    if (d == Duration.zero) return;
    final newPos = Duration(
      milliseconds: (value * d.inMilliseconds).round(),
    );
    try {
      await _player.seek(newPos);
      _position.value = newPos;
    } on Object catch (e, st) {
      // Seeks are best-effort; never bubble them up.
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st));
    }
  }

  Future<void> _downloadFile() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      await FilePicker.saveFile(
        dialogTitle: l10n.saveAudio,
        fileName: _fileName ?? 'audio.$_extension',
        bytes: bytes,
      );
    } on Object catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st));
      // User dismissal is not an error; only report real failures.
      if (kDebugMode) {
        // ignore: avoid_print
        print('Audio save failed: $e');
      }
    }
  }

  Future<void> _retry() async {
    setState(() => _lastError = null);
    try {
      await _togglePlay();
    } on Object catch (_) {
      // The toggle play surfaces a new error inside the catch chain.
    }
  }

  /// Ad-hoc download path used when the auto-download policy is
  /// "never" and the user taps the save icon anyway.  Reuses the
  /// shared cache so a second tap doesn't refetch.
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
    });
    try {
      final mf = await future;
      _bytes = mf.bytes;
      if (!mounted) return;
      await _downloadFile();
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
  void dispose() {
    _player.dispose();
    _position.dispose();
    _duration.dispose();
    _isPlaying.dispose();
    _isReady.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final l10n = AppLocalizations.of(context)!;

    // Fast path: bytes are already in the shared cache, so we don't
    // need a FutureBuilder at all. The audio player will lazily
    // attach the file on first play.
    final cached = RoomMediaCache.instance
        .get(widget.event.roomId ?? widget.event.eventId, widget.event.eventId);
    if (cached != null && cached.isNotEmpty) {
      _bytes ??= cached;
    }

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        final downloaded = snapshot.hasData;
        // Subscribe to all four notifiers; only the widgets that
        // actually read a value re-paint when it changes.
        return ValueListenableBuilder<bool>(
          valueListenable: _isPlaying,
          builder: (context, isPlaying, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isReady,
              builder: (context, isReady, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: _position,
                  builder: (context, position, _) {
                    return ValueListenableBuilder<Duration>(
                      valueListenable: _duration,
                      builder: (context, duration, _) {
                        final displayPos = position.inSeconds.toDouble();
                        final resolvedDuration = duration.inSeconds == 0
                            ? Duration(milliseconds: _durationMs ?? 0)
                            : duration;
                        final displayDur =
                            resolvedDuration.inMilliseconds / 1000.0;
                        final progress = displayDur == 0
                            ? 0.0
                            : (displayPos / displayDur).clamp(0.0, 1.0);
                        return AttachmentCard(
                          maxWidth: MediaSizePrefs.of(context).audioMax,
                          isError: _lastError != null,
                          child: Row(
                            children: [
                              // Prominent: this is the row. Play is the reason
                              // an audio attachment exists.
                              AttachmentLeadingIcon(
                                icon: _lastError != null
                                    ? LucideIcons.rotateCw
                                    : isPlaying
                                        ? LucideIcons.pause
                                        : LucideIcons.play,
                                isError: _lastError != null,
                                onTap: downloaded && isReady
                                    ? (_lastError != null ? _retry : _togglePlay)
                                    : null,
                              ),
                              SizedBox(width: t.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _fileName ?? l10n.audioFileName,
                                      style: TextStyle(
                                        fontSize: sidebarMetricsFor(context)
                                            .titleSize,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 6),
                                    SliderTheme(
                                      data:
                                          SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                      ),
                                      child: Slider(
                                        value: progress,
                                        onChanged:
                                            downloaded ? _seekTo : null,
                                      ),
                                    ),
                                    SizedBox(height: t.spaceXxs),
                                    // Elapsed and total in the mono face, then
                                    // the extension and size, all through the
                                    // shared row so the file attachment above
                                    // this one puts its facts in the same place.
                                    AttachmentMetaRow(
                                      leading: AttachmentBadge(
                                        label: _extension,
                                      ),
                                      elapsedOf: _formatDuration(position),
                                      totalOf: _formatDuration(resolvedDuration),
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
                              SizedBox(width: t.spaceXs),
                              Semantics(
                                label: l10n.downloadAudio,
                                button: true,
                                child: AttachmentLeadingIcon(
                                  // Quiet. It sits beside the play control and
                                  // used to be drawn identically to it, so the
                                  // two competed for the same attention.
                                  emphasis: AttachmentEmphasis.quiet,
                                  icon: LucideIcons.download,
                                  onTap: downloaded
                                      ? _downloadFile
                                      : _downloadOnDemand,
                                  ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

