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

import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Orchestrates the chat timeline lifecycle.
///
/// Creates the [Timeline] via the Matrix SDK, manages scroll-to-load-history,
/// and delegates the actual rendering to [TimelineView].
///
/// TODO: This needs settingsController styling.
class ChatTimeline extends StatefulWidget {
  const ChatTimeline({super.key, required this.room});
  final Room room;

  @override
  State<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends State<ChatTimeline> {
  late final Future<Timeline> _timelineFuture;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingHistory = false;

  /// Incremented on every timeline mutation to trigger list rebuilds.
  int _timelineVersion = 0;

  @override
  void initState() {
    super.initState();
    _timelineFuture = widget.room.getTimeline(
      onChange: (_) => setState(() => _timelineVersion++),
      onInsert: (_) => setState(() => _timelineVersion++),
      onRemove: (_) => setState(() => _timelineVersion++),
      onUpdate: () {},
    );
    // Attach scroll-to-load listener once the timeline is available.
    // Doing this here instead of in build() prevents duplicate listeners
    // on every widget rebuild.
    _timelineFuture.then((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  /// Requests more history when the user scrolls to the top of the timeline.
  ///
  /// Because the list is reversed, "top" corresponds to
  /// [ScrollController.position.maxScrollExtent].
  void _onScroll() {
    if (_scrollController.position.pixels <=
            _scrollController.position.maxScrollExtent &&
        !_isLoadingHistory) {
      _isLoadingHistory = true;
      _timelineFuture.then((t) {
        t.requestHistory().whenComplete(() => _isLoadingHistory = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settings, _) => FutureBuilder<Timeline>(
        future: _timelineFuture,
        builder: (context, snapshot) {
          final timeline = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done ||
              timeline == null) {
            return const LoadingAndTransitionScreen();
          }
          return TimelineView(
            // Force a full rebuild when the underlying timeline data changes.
            key: ValueKey(_timelineVersion),
            timeline: timeline,
            room: widget.room,
            displayType: settings.displayType,
            scrollController: _scrollController,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
