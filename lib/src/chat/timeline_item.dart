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

import 'package:azhi_main/src/chat/chat_event.dart';
import 'package:azhi_main/src/helpers/azhi_color_palette.dart';
import 'package:azhi_main/src/helpers/date_time_extension.dart';
import 'package:azhi_main/src/settings/display_type.dart';
import 'package:azhi_main/src/widgets/avatar_from_uri.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

//FIXME - Display time only when there is significant deviation between two events
//FIXME - Constraint on chat bubbles
class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.event,
    required this.room,
    this.previousEvent,
    required this.displayType,
  });
  final Event event;
  final Event? previousEvent;
  final Room room;
  final DisplayType displayType;

  @override
  Widget build(BuildContext context) {
    bool isEventFromSameSender = previousEvent == null
        ? false
        : (event.senderId.equals(previousEvent!.senderId) ? true : false);

    // NOTE - Possible optimization? Is this really a good way to handle settings in here?
    // NOTE - Design rework : Avatar must be at top
    return ListTile(
      leading: switch (displayType) {
        DisplayType.modern || DisplayType.bubbles => isEventFromSameSender
            ? null
            : AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
                onTap: () => context.push(
                  '${GoRouterState.of(context).uri}/profile/${event.senderFromMemoryOrFallback.id}',
                ),
              ),
        DisplayType.irc => null
      },
      // FIXME - Sometimes the damn thing puts messages out of order????
      // FIXME - This needs optimization and proper styling
      // FIXME - This needs a new custom widget instead of a generic List Tile
      title: TimelineItemSenderNameAndTimestamp(
          event: event, omitSender: isEventFromSameSender),
      subtitle: switch (displayType) {
        DisplayType.bubbles => Container(
            decoration: BoxDecoration(
              color: AzhiColorPalette.cpgDarker,
              border: Border.all(
                  color: AzhiColorPalette.britishRacingGreen, width: 0.7),
            ),
            child: isEventFromSameSender
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(56, 8, 0, 0),
                    child: MessageEventHandler(event: event),
                  )
                : MessageEventHandler(event: event),
          ),
        DisplayType.modern => isEventFromSameSender
            ? Padding(
                padding: const EdgeInsets.fromLTRB(56, 0, 0, 0),
                child: MessageEventHandler(event: event),
              )
            : MessageEventHandler(event: event),
        DisplayType.irc => MessageEventHandler(event: event),
      },
    );
  }
}

// What follows is quite possibly some of the jankiest code I've ever written
class TimelineItemSenderNameAndTimestamp extends StatelessWidget {
  const TimelineItemSenderNameAndTimestamp({
    super.key,
    required this.event,
    required this.omitSender,
  });

  final Event event;
  final bool omitSender;

  @override
  Widget build(BuildContext context) {
    return Row(
      // So get this
      // I can't just solve this the peaceful way when ommitting the name widget
      // So instead I make a SizedBox of size 0 and instead shove the alignment to the end
      // Visually it looks the same; so I'm going to keep this for now
      // NOTE: Rework this and add proper styling
      mainAxisAlignment:
          omitSender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        omitSender
            ? const SizedBox(
                width: 0.0,
                height: 0.0,
              )
            : Expanded(
                child: Text(
                  event.senderFromMemoryOrFallback.calcDisplayname(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        Text(
          event.originServerTs.localizedTimeShort(context),
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
