// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/message_event_base.dart';
import 'package:moonrelay/src/chat/timeline_item_sender_name_and_timestamp.dart';

class IRCMessageItem implements MessageItemBase {
  IRCMessageItem({
    required this.event,
    required this.room,
  });

  @override
  final Event event;

  @override
  final Room room;

  @override
  Widget buildAvatar(BuildContext context) => SizedBox.shrink();

  @override
  Widget buildTitle(BuildContext context) {
    return TimelineItemSenderNameAndTimestamp(event: event, omitSender: false);
  }

  @override
  Widget buildSubtitle(BuildContext context) {
    return Text(
      event.body,
      style: const TextStyle(fontSize: 16),
    );
  }
}
