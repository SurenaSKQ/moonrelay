// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'package:azhi_main/src/chat/timeline_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:matrix/matrix.dart';

class AzhiChatTimeline extends StatefulWidget {
  const AzhiChatTimeline({super.key, required this.room});
  final Room room;

  @override
  State<AzhiChatTimeline> createState() => _AzhiChatTimelineState();
}

//TODO: This needs settingsController styling.
class _AzhiChatTimelineState extends State<AzhiChatTimeline> {
  late final Future<Timeline> _timelineFuture;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  // Counts events
  // ignore: unused_field
  int _count = 0;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Timeline>(
      future: _timelineFuture,
      builder: (context, snapshot) {
        final timeline = snapshot.data;
        if (timeline == null) {
          return Center(
            child: SpinKitCubeGrid(
              color: FluentTheme.of(context).accentColor,
            ),
          );
        }
        // Add a listener to the scroll controller
        _scrollController.addListener(
          () {
            if (_scrollController.position.pixels ==
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
              return (timeline.events[index].relationshipEventId != null)
                  ? Container()
                  : ScaleTransition(
                      scale: animation,
                      child: Opacity(
                        opacity: timeline.events[index].status.isSent ? 1 : 0.5,
                        child: TimelineItem(
                          event: timeline.events[index],
                          previousEvent:
                              (index >= 1 ? timeline.events[index - 1] : null),
                          room: widget.room,
                        ),
                      ),
                    );
            },
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _timelineFuture = widget.room.getTimeline(
      onChange: (i) {
        if (kDebugMode) {
          print('on change! $i');
        }
        _listKey.currentState?.setState(() {});
      },
      onInsert: (i) {
        if (kDebugMode) {
          print('on insert! $i');
        }
        _listKey.currentState?.insertItem(i);
        _count++;
      },
      onRemove: (i) {
        if (kDebugMode) {
          print('On remove $i');
        }
        _count--;
        _listKey.currentState?.removeItem(i, (_, __) => const ListTile());
      },
      onUpdate: () {
        if (kDebugMode) {
          print('On update');
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the controller
    super.dispose();
  }
}
