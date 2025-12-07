// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';

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
