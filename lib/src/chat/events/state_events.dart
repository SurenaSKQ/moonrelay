import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class StateEventsStub extends StatelessWidget {
  const StateEventsStub({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all()),
      child: Text(event.body),
    );
  }
}
