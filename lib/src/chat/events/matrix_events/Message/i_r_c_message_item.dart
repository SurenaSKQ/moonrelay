// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/events/formatted_text_widget.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/message_event_base.dart';
import 'package:moonrelay/src/chat/events/matrix_url_banner_wrapper.dart';
import 'package:moonrelay/src/chat/timeline_item_sender_name_and_timestamp.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

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
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;
    final formattedBody = event.content['formatted_body'] as String?;
    final format = event.content['format'] as String?;
    final textWidget = formattedBody != null && format == 'org.matrix.custom.html'
        ? FormattedTextWidget(
            event: event,
            baseFontSize: fs,
          ) as Widget
        : Text(
            event.body,
            style: TextStyle(fontSize: fs),
          );
    return MatrixUrlBannerWrapper(
      textBody: event.body,
      room: room,
      child: textWidget,
    );
  }
}
