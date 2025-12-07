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

import 'package:moonrelay/src/chat/events/matrix_events/Message/bubble_message_item.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/i_r_c_message_item.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/message_event_base.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/modern_message_item.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
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
// Drag and Drop
// Replies
// Stickers
// ALL events need to be finished including misc. ones

class _ChatTimelineState extends State<ChatTimeline> {
  late final Future<Timeline> _timelineFuture;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // FIXME There is a really bad crash bug here that causes the index to overflow
    // Cannot replicate again :(
    return Consumer<SettingsController>(
      builder: (context, settings, child) => FutureBuilder<Timeline>(
        future: _timelineFuture,
        builder: (context, snapshot) {
          final timeline = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done ||
              timeline == null) {
            return LoadingScreen();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.position.maxScrollExtent == 0 &&
                timeline.canRequestHistory) {
              timeline.requestHistory();
            }
          });

          _scrollController.addListener(
            () {
              if (_scrollController.position.pixels ==
                      _scrollController.position.maxScrollExtent &&
                  timeline.canRequestHistory) {
                timeline.requestHistory();
              }
            },
          );
          // NOTE - Possible optimization? Is this really a good way to handle settings in here?
          // NOTE - Design rework : Avatar must be at top

          // FIXME - Sometimes the damn thing puts messages out of order????
          // FIXME - This needs optimization and proper styling
          // FIXME - This possibly needs a new custom widget instead of a generic List Tile
          return Expanded(
            child: AnimatedList(
              controller: _scrollController,
              key: _listKey,
              reverse: true,
              initialItemCount: timeline.events.length,
              itemBuilder: (context, index, animation) {
                MessageItemBase messageView = switch (settings.displayType) {
                  DisplayType.irc => IRCMessageItem(
                      event: timeline.events[index], room: widget.room),
                  DisplayType.modern => ModernMessageItem(
                      event: timeline.events[index], room: widget.room),
                  DisplayType.bubbles => BubbleMessageItem(
                      event: timeline.events[index], room: widget.room),
                };

                if ((timeline.events[index].relationshipEventId != null)) {
                  return Container();
                } else {
                  return FadeTransition(
                    opacity: animation,
                    child: ListTile(
                      leading: messageView.buildAvatar(context),
                      title: messageView.buildTitle(context),
                      subtitle: messageView.buildSubtitle(context),
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
      },
      onRemove: (i) {
        _listKey.currentState?.removeItem(i, (_, __) => const ListTile());
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
