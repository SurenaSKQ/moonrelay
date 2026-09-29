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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/fullscreen_video_player.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:video_player/video_player.dart';

class InitializedVideoPlayer extends StatelessWidget {
  const InitializedVideoPlayer({
    super.key,required this.controller, required this.l10n});

  final VideoPlayerController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        return MouseRegion(
          child: GestureDetector(
            onTap: () async {
              try {
                if (v.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
              } catch (_) {
                // Swallow controller exceptions: they don't affect
                // the visual state meaningfully and the user can
                // retry by tapping again.
              }
            },
            onDoubleTap: () {
              try {
                final navigator = Navigator.of(context);
                final c = controller;
                final route = MaterialPageRoute(
                  builder: (_) => FullscreenVideoPlayer(controller: c),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!navigator.mounted) return;
                  navigator.push(route);
                });
              } catch (_) {
                // Navigator may not be available yet; defer.
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: v.aspectRatio == 0 ? 1.0 : v.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                if (!v.isPlaying)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: t.opacitySubtle),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  // [Semantics] instead of [Tooltip] for the same
                  // reason as the thumbnail overlay above: this
                  // button mounts as soon as the player
                  // initialises, and Tooltip's OverlayPortal would
                  // re-trigger the chat-page layout race.
                  child: Semantics(
                    label: l10n.fullscreenVideo,
                    button: true,
                    child: Material(
                      color: Colors.black.withValues(alpha: t.opacitySubtle),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          final navigator = Navigator.of(context);
                          final c = controller;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!navigator.mounted) return;
                            navigator.push(MaterialPageRoute(
                              builder: (_) =>
                                  FullscreenVideoPlayer(controller: c),
                            ));
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            LucideIcons.maximize,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.9),
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
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spaceSm,
                      vertical: t.spaceXs,
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