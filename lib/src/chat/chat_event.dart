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

import 'package:moonrelay/src/chat/events/formatted_text_widget.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/audio/audio_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/file/file_attached_message.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/image/image_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/video_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/state_events.dart';
import 'package:moonrelay/src/chat/events/unsupported_event.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Routes each [Event] to the appropriate rendering widget based on its type
/// and message type.
///
/// This is the central dispatch point for the entire event-rendering tree.
/// Extend this when adding support for new event or message types (stickers,
/// polls, location sharing, etc.).
class MessageEventHandler extends StatelessWidget {
  const MessageEventHandler({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    switch (event.type) {
      case EventTypes.Message:
        // TODO: Stickers, emotes; event relationships (replies, reactions, edits)
        switch (event.messageType) {
          case MessageTypes.Text:
          case MessageTypes.Emote:
          case MessageTypes.Notice:
            return FormattedTextWidget(event: event);
          case MessageTypes.Image:
            return ImageMessageType(event: event);
          case MessageTypes.Audio:
            return AudioMessageType(event: event);
          case MessageTypes.Video:
            return VideoMessageType(event: event);
          case MessageTypes.File:
            return FileAttachedMessage(event: event);
          default:
            return UnsupportedEventType(event: event);
        }
      case 'm.room.member':
      case 'm.room.name':
      case 'm.room.topic':
      case 'm.room.avatar':
      case 'm.room.create':
      case 'm.room.encryption':
      case 'm.room.pinned_events':
      case 'm.room.canonical_alias':
      case 'm.room.power_levels':
      case 'm.room.tombstone':
        return StateEvents(event: event);
      default:
        return StateEvents(event: event);
    }
  }
}
