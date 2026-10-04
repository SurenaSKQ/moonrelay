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

import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A [VideoPlayerPlatform] that decodes nothing and renders nothing.
///
/// `video_player` is a plugin, so a widget test that pumps a real
/// `VideoPlayerController` has nothing to talk to: the default instance on
/// desktop is the Windows or Linux texture registry, which needs a window, a
/// GPU and a real file. That is why the full-screen player had no test at all
/// and why the structural changes to it had to be made by hand.
///
/// This fake closes that gap. It records the calls the widget makes, lets a
/// test push `initialized` and `isPlayingStateUpdate` events, and answers
/// `buildViewWithOptions` with a plain box, so the widget tree above the
/// surface is exercised for real while nothing below it is.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  FakeVideoPlayerPlatform({
    this.duration = const Duration(seconds: 42),
    this.size = const Size(1920, 1080),
  });

  /// Reported by the `initialized` event, which is what makes the controller
  /// report an aspect ratio and a real position/duration pair.
  final Duration duration;

  /// Reported by the `initialized` event as the video's natural size.
  final Size size;

  final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast();

  /// Every transport call the widget under test made, in order. Asserting on
  /// this is how a test checks that a key press reached the controller without
  /// having to trust the controller's own notifier.
  final List<String> calls = <String>[];

  /// The position `getPosition` reports and that `seekTo` writes into, because
  /// nothing else moves it in a test: there is no real clock behind playback.
  Duration position = Duration.zero;

  /// The volume `setVolume` writes into, starting at full.
  double volume = 1;

  bool isPlaying = false;

  bool disposed = false;

  /// Pushes an event to every listening controller.
  void emit(VideoEvent event) => _events.add(event);

  /// The event that makes a controller usable: a non-zero duration and a size,
  /// which together give the widget an aspect ratio to lay out against.
  void emitInitialized() => emit(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: duration,
          size: size,
        ),
      );

  void emitPlayingState(bool playing) {
    isPlaying = playing;
    emit(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: playing,
      ),
    );
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('create');
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF000000));

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    calls.add('setLooping($looping)');
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
    isPlaying = true;
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
    isPlaying = false;
  }

  @override
  Future<void> seekTo(int playerId, Duration target) async {
    calls.add('seekTo($target)');
    position = target;
  }

  @override
  Future<void> setVolume(int playerId, double value) async {
    calls.add('setVolume($value)');
    volume = value;
  }

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    disposed = true;
  }

  /// Closes the event stream. A test that forgets this leaves an open stream,
  /// which `flutter test` reports as a leaked handle rather than as a pass.
  Future<void> close() => _events.close();
}
