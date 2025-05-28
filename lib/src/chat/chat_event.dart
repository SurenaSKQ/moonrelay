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

import 'package:moonrelay/src/chat/events/matrix_events/Message/basic_text_event.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/file/file_attached_message.dart';
import 'package:moonrelay/src/chat/events/unsupported_event.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

class MessageEventHandler extends StatelessWidget {
  const MessageEventHandler({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    switch (event.type) {
      case EventTypes.Message:
        // TODO: Stickers, emotes; event relationships
        switch (event.messageType) {
          case MessageTypes.Text:
            return BasicTextEvent(event: event);
          case MessageTypes.Image:
            return FileAttachedMessage(event: event);
          case MessageTypes.Audio:
            return const Placeholder();
          case MessageTypes.File:
            return FileAttachedMessage(event: event);

          default:
            return UnsupportedEventType(event: event);
        }
      case 'm.room.name':
        return const Placeholder();
      case 'm.room.topic':
        return const Placeholder();
      case 'm.room.avatar':
        return const Placeholder();
      case 'm.room.pinned_events':
        return const Placeholder();
      default:
        return Center(
          child: Text(
            "${event.type}, ${event.messageType.toString()}",
          ),
        );
    }
  }
}
