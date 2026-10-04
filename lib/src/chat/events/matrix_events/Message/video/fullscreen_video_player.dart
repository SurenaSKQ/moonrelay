// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  const FullscreenVideoPlayer({
    super.key,required this.controller});
  final VideoPlayerController controller;

  @override
  State<FullscreenVideoPlayer> createState() => FullscreenVideoPlayerState();
}

class FullscreenVideoPlayerState extends State<FullscreenVideoPlayer>
    with TickerProviderStateMixin {
  /// Auto-hide chrome (top bar, controls) after the user stops moving the
  /// mouse.  Mirrors native gallery apps so the video is unobstructed most
  /// of the time but the controls are reachable within a second.
  late final AnimationController _chromeController;
  late final Animation<double> _chromeOpacity;

  /// Monotonic counter so stale "hide chrome" futures can't fire after a
  /// fresh user interaction has overwritten the schedule.
  int _hideScheduleId = 0;

  @override
  void initState() {
    super.initState();
    _chromeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _chromeOpacity =
        CurvedAnimation(parent: _chromeController, curve: Curves.easeOut);
    _scheduleChromeHide();
  }

  @override
  void dispose() {
    _chromeController.dispose();
    super.dispose();
  }

  void _scheduleChromeHide() {
    _chromeController.stop();
    _chromeController.forward();
    final id = ++_hideScheduleId;
    Future<void>.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (id != _hideScheduleId) return;
      await _chromeController.reverse();
    });
  }

  void _showChrome() {
    _hideScheduleId++;
    _scheduleChromeHide();
  }

  void _hideChrome() {
    _hideScheduleId++;
    _chromeController.reverse();
  }

  void _toggleChrome() {
    if (_chromeController.value > 0.5) {
      _hideChrome();
    } else {
      _showChrome();
    }
  }

  Future<void> _togglePlay(VideoPlayerController c) async {
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
    } catch (_) {
      // Swallow controller failures; the user can retry with another
      // tap.
    }
    if (mounted) _showChrome();
  }

  Future<void> _seekRelative(VideoPlayerController c, Duration delta) async {
    try {
      final target = c.value.position + delta;
      final clamped = target < Duration.zero
          ? Duration.zero
          : target > c.value.duration
              ? c.value.duration
              : target;
      await c.seekTo(clamped);
    } catch (_) {
      // Ignore seek failures.
    }
    if (mounted) _showChrome();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Scaffold(
          // The same backdrop the image viewer uses. It was `Colors.black`
          // here and `0xCC000000` over a black scaffold there, which is a
          // visible seam when a user opens a video full screen and then opens a
          // still from the same conversation, and one of the two is wrong in
          // light mode.
          backgroundColor: Theme.of(context).moonrelay.layers.mediaBackdrop,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _togglePlay(c),
                  onDoubleTap: _toggleChrome,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
              if (!c.value.isPlaying)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color:
                              Colors.black.withValues(alpha: t.opacitySubtle),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          // Lucide, like every other play control in the app.
                          // The Material glyph here was the last one, and next
                          // to the audio row's Lucide play it read as two icon
                          // sets rather than as one drawing.
                          LucideIcons.play,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _chromeOpacity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: t.spaceSm,
                          vertical: t.spaceXs,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: t.spaceSm,
                                vertical: t.spaceXs,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withValues(alpha: t.opacityDisabled),
                                borderRadius: BorderRadius.circular(t.radiusSm),
                              ),
                              child: Text(
                                '${_formatPos(c.value.position)} / '
                                '${_formatPos(c.value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FadeTransition(
                  opacity: _chromeOpacity,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '−10s',
                                  icon: const Icon(
                                    Icons.replay_10_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    -const Duration(seconds: 10),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '−5s',
                                  icon: const Icon(
                                    Icons.replay_5_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    -const Duration(seconds: 5),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '+5s',
                                  icon: const Icon(
                                    Icons.forward_5_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    const Duration(seconds: 5),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '+10s',
                                  icon: const Icon(
                                    Icons.forward_10_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    const Duration(seconds: 10),
                                  ),
                                ),
                                IconButton(
                                  tooltip: c.value.isPlaying ? 'Pause' : 'Play',
                                  icon: Icon(
                                    c.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () => _togglePlay(c),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPos(Duration d) {
    if (d == Duration.zero) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
