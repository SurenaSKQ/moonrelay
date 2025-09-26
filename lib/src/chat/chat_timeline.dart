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

import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class ChatTimeline extends StatefulWidget {
  const ChatTimeline({super.key, required this.room});
  final Room room;

  @override
  State<ChatTimeline> createState() => _ChatTimelineState();
}

//TODO: This needs settingsController styling.

// FIXME Work needed 2025 - get a complete chat timeline by EOY 2025
// FIXME Need following featrues for 'Chat Timeline v1':
// Fix scrolling
// Drag and Drop
// Replies
// Stickers
// ALL events need to be finished including misc. ones

class _ChatTimelineState extends State<ChatTimeline> {
  late final Future<Timeline> _timelineFuture;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  // Counts events
  // ignore: unused_field
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    // FIXME There is a really bad crash bug here that causes the index to overflow
    return Consumer<SettingsController>(
      builder: (context, value, child) => FutureBuilder<Timeline>(
        future: _timelineFuture,
        builder: (context, snapshot) {
          final timeline = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done ||
              timeline == null) {
            return LoadingAndTransitionScreen();
          }
          _scrollController.addListener(
            () {
              if (_scrollController.position.pixels <=
                  _scrollController.position.maxScrollExtent) {
                // User has scrolled to the top (not bottom lol), request more data
                timeline.requestHistory();
              }
            },
          );
          _count = timeline.events.length;
          return Expanded(
            child: AnimatedList(
              controller: _scrollController,
              key: _listKey,
              reverse: true,
              initialItemCount: timeline.events.length,
              itemBuilder: (context, index, animation) {
                if ((timeline.events[index].relationshipEventId != null)) {
                  return Container();
                } else {
                  return FadeTransition(
                    opacity: animation,
                    child: TimelineItem(
                      event: timeline.events[index],
                      previousEvent:
                          (index >= 1 ? timeline.events[index - 1] : null),
                      room: widget.room,
                      displayType: value.displayType,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _timelineFuture = widget.room.getTimeline(
      onChange: (i) {
        _listKey.currentState?.setState(() {});
      },
      onInsert: (i) {
        _listKey.currentState?.insertItem(i);
        _count++;
      },
      onRemove: (i) {
        _count--;
        _listKey.currentState?.removeItem(i, (_, __) => const ListTile());
      },
      onUpdate: () {},
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
