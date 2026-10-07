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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  const FullscreenVideoPlayer({super.key, required this.controller});
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

  /// The pending auto-hide, held so it can be cancelled.
  ///
  /// This was a bare `Future.delayed` guarded by an `_hideScheduleId` counter,
  /// which stops a stale hide from firing but cannot stop the timer itself: a
  /// user who opened and closed a video left a live three second timer on the
  /// event loop, every time. A widget test caught it as
  /// "A Timer is still pending even after the widget tree was disposed",
  /// which is the only reason this is a field.
  Timer? _chromeTimer;

  /// The volume to restore when unmuting, so mute is a toggle rather than a
  /// reset to full.
  double _volumeBeforeMute = 1;

  /// Whether the last thing the user did was mute, which the volume control
  /// shows. A keyboard-only mute with nothing on screen saying so is a trap:
  /// the video goes silent and the user has no way to know why.
  bool _muted = false;

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
    _showChrome();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _chromeTimer = null;
    _chromeController.dispose();
    super.dispose();
  }

  void _scheduleChromeHide() {
    _chromeController.stop();
    _chromeController.forward();
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      _chromeTimer = null;
      if (mounted) _hideChrome();
    });
  }

  void _showChrome() {
    _scheduleChromeHide();
  }

  void _hideChrome() {
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

  Future<void> _toggleMute(VideoPlayerController c) async {
    // `keyM` steps up from silence rather than toggling between two numbers, so
    // pressing it repeatedly after a manual mute turns the sound on instead of
    // turning it off again on every other press.
    final next = _muted || c.value.volume > 0 ? 0.0 : _volumeBeforeMute;
    try {
      if (next == 0) {
        _volumeBeforeMute = c.value.volume == 0 ? 1 : c.value.volume;
        await c.setVolume(0);
      } else {
        await c.setVolume(_volumeBeforeMute);
      }
    } catch (_) {
      // Expected and uninteresting: the controller can be disposed between the
      // keypress and the platform call, and there is no fallback for volume,
      // so the button keeps showing the previous state.
    }
    if (!mounted) return;
    setState(() => _muted = next == 0);
    _showChrome();
  }

  /// Keyboard control for a surface the user opened in order to watch
  /// something. Every desktop player has these four, and this one had none:
  /// pausing meant finding a button that fades out after three seconds.
  KeyEventResult _onKey(VideoPlayerController c, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.enter:
        _togglePlay(c);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _seekRelative(c, const Duration(seconds: 5));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _seekRelative(c, -const Duration(seconds: 5));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        _toggleMute(c);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final layers = Theme.of(context).moonrelay.layers;
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return _MediaSurface(
          onKey: (event) => _onKey(c, event),
          child: Scaffold(
            // The same backdrop the image viewer uses. It was `Colors.black`
            // here and `0xCC000000` over a black scaffold there, which is a
            // visible seam when a user opens a video full screen and then opens a
            // still from the same conversation, and one of the two is wrong in
            // light mode.
            backgroundColor: layers.mediaBackdrop,
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
                                tooltip: l10n.close,
                                icon: const Icon(
                                  // Lucide, like every other close in the app.
                                  LucideIcons.x,
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
                                  borderRadius:
                                      BorderRadius.circular(t.radiusSm),
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
                                    tooltip: l10n.videoSkipBack(10),
                                    icon: const Icon(
                                      LucideIcons.rotateCcw,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () => _seekRelative(
                                      c,
                                      -const Duration(seconds: 10),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.videoSkipBack(5),
                                    icon: const Icon(
                                      LucideIcons.undo2,
                                      color: Colors.white,
                                      size: 24,
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
                                    tooltip: l10n.videoSkipForward(5),
                                    icon: const Icon(
                                      LucideIcons.redo2,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () => _seekRelative(
                                      c,
                                      const Duration(seconds: 5),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.videoSkipForward(10),
                                    icon: const Icon(
                                      LucideIcons.rotateCw,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () => _seekRelative(
                                      c,
                                      const Duration(seconds: 10),
                                    ),
                                  ),
                                  IconButton(
                                    // Mute is a button as well as the M key,
                                    // because a shortcut with nothing on
                                    // screen to show it leaves the user with a
                                    // silent video and no reason for it.
                                    tooltip: _muted
                                        ? l10n.videoUnmute
                                        : l10n.videoMute,
                                    icon: Icon(
                                      _muted
                                          ? LucideIcons.volumeX
                                          : LucideIcons.volume2,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () => _toggleMute(c),
                                  ),
                                  IconButton(
                                    tooltip: c.value.isPlaying
                                        ? l10n.pauseVideo
                                        : l10n.playVideo,
                                    icon: Icon(
                                      c.value.isPlaying
                                          ? LucideIcons.pause
                                          : LucideIcons.play,
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

/// The two things a full-screen media surface needs that cannot live inside
/// the player itself: a focus target, so the keyboard reaches it without the
/// user having to click something first, and a system icon style.
///
/// It is a separate widget rather than two more nested widgets inside `build`
/// for one reason: this file's build method is a wall of closing brackets with
/// no structural test over it, and adding wrapper levels to it by hand is how
/// you end up three errors deep in a spread operator.
class _MediaSurface extends StatelessWidget {
  const _MediaSurface({required this.onKey, required this.child});

  final KeyEventResult Function(KeyEvent event) onKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        // Light icons in both brightnesses, because this surface is the same
        // near-black in both. Reading the theme's own overlay style would put dark
        // system icons over a black surface in light mode.
        value: SystemUiOverlayStyle.light,
        child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) => onKey(event),
            child: child),
      );
}
