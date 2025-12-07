import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';

abstract class MessageItemBase {
  MessageItemBase({required this.event, required this.room});

  final Event event;

  final Room room;

  /// The "avatar" widget will draw the sending user's avatar
  Widget buildAvatar(BuildContext context);

  /// The title widget will draw the sender name and the message timestamp
  Widget buildTitle(BuildContext context);

  /// This builds the actual message body
  Widget buildSubtitle(BuildContext context);
}
