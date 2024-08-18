// Copyright (C) 2024 Surena Karimpour Ghannadi
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

import 'package:azhi_main/src/widgets/chat_box.dart';
import 'package:go_router/go_router.dart';
import 'package:azhi_main/src/widgets/room_info_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:matrix/matrix.dart';

class FluentRoomPage extends StatefulWidget {
  const FluentRoomPage({super.key, required this.room});
  final Room room;
  @override
  State<FluentRoomPage> createState() => _FluentRoomPageState();
}

class _FluentRoomPageState extends State<FluentRoomPage> {
  late final Future<Timeline> _timelineFuture;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  // Counts events
  int _count = 0;

  @override
  void initState() {
    _timelineFuture = widget.room.getTimeline(onChange: (i) {
      print('on change! $i');
      _listKey.currentState?.setState(() {});
    }, onInsert: (i) {
      print('on insert! $i');
      _listKey.currentState?.insertItem(i);
      _count++;
    }, onRemove: (i) {
      print('On remove $i');
      _count--;
      _listKey.currentState?.removeItem(i, (_, __) => const ListTile());
    }, onUpdate: () {
      print('On update');
    });
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return mt.Scaffold(
      backgroundColor: FluentTheme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          RoomInfoCard(room: widget.room),
          Expanded(
            child: FutureBuilder<Timeline>(
              future: _timelineFuture,
              builder: (context, snapshot) {
                final timeline = snapshot.data;
                if (timeline == null) {
                  return const Center(
                    child: ProgressRing(),
                  );
                }
                _count = timeline.events.length;
                return Column(
                  children: [
                    Center(
                      child: Button(
                        onPressed: () => timeline.requestHistory(),
                        child: const Text("Load more"),
                      ),
                    ),
                    const Divider(
                      direction: Axis.horizontal,
                      size: 2,
                    ),
                    Expanded(
                      child: AnimatedList(
                        key: _listKey,
                        reverse: true,
                        initialItemCount: timeline.events.length,
                        itemBuilder: (context, index, animation) {
                          return (timeline.events[index].relationshipEventId !=
                                  null)
                              ? Container()
                              : ScaleTransition(
                                  scale: animation,
                                  child: Opacity(
                                    opacity:
                                        timeline.events[index].status.isSent
                                            ? 1
                                            : 0.5,
                                    child: ListTile(
                                      leading: OutlinedButton(
                                        child: CircleAvatar(
                                          foregroundImage: timeline
                                                      .events[index]
                                                      .senderFromMemoryOrFallback
                                                      .avatarUrl ==
                                                  null
                                              ? null
                                              : NetworkImage(
                                                  timeline
                                                      .events[index]
                                                      .senderFromMemoryOrFallback
                                                      .avatarUrl!
                                                      .getThumbnail(
                                                        widget.room.client,
                                                        width: 56,
                                                        height: 56,
                                                      )
                                                      .toString(),
                                                ),
                                        ),
                                        onPressed: () => context.push(
                                            '${GoRouterState.of(context).uri}/profile/${timeline.events[index].senderFromMemoryOrFallback.id}'),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              timeline.events[index]
                                                  .senderFromMemoryOrFallback
                                                  .calcDisplayname(),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            timeline
                                                .events[index].originServerTs
                                                .toIso8601String(),
                                            style: const TextStyle(
                                                fontSize: 8,
                                                fontFamily: 'JetBrainsMono'),
                                          ),
                                        ],
                                      ),
                                      subtitle: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: FluentTheme.of(context)
                                                .accentColor,
                                            width: 1,
                                            strokeAlign:
                                                BorderSide.strokeAlignOutside,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: FluentTheme.of(context)
                                              .acrylicBackgroundColor,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            timeline.events[index]
                                                .getDisplayEvent(timeline)
                                                .body,
                                            style: const TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                fontSize: 14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                        },
                      ),
                    )
                  ],
                );
              },
            ),
          ),
          const Divider(
            direction: Axis.vertical,
            size: 1,
          ),
          ChatBox(room: widget.room),
        ],
      ),
    );
  }
}
