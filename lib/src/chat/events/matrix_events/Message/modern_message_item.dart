// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/events/formatted_text_widget.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/message_event_base.dart';
import 'package:moonrelay/src/chat/events/matrix_url_banner_wrapper.dart';
import 'package:moonrelay/src/chat/events/unsupported_event.dart';
import 'package:moonrelay/src/chat/timeline_item_sender_name_and_timestamp.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

class ModernMessageItem implements MessageItemBase {
  ModernMessageItem({
    required this.event,
    required this.room,
  });

  @override
  final Event event;

  @override
  final Room room;

  // TODO: Multiple file download; split download utility; (future work) bind FFI to windows defender / ClamAV

  Future<String?> _downloadFile() async {
    if (event.hasAttachment) {
      MatrixFile attFile = await event.downloadAndDecryptAttachment();
      return await FilePicker.saveFile(
          dialogTitle: 'Select download target',
          fileName: FileUtilities(event: event).getFileName(),
          bytes: attFile.bytes);
    }
    return null;
  }

  @override
  Widget buildAvatar(BuildContext context) => AvatarFromUriOrFallbackImage(
        client: room.client,
        avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
        onTap: () => context.push(
          '${GoRouterState.of(context).uri}/profile/${event.senderFromMemoryOrFallback.id}',
        ),
      );

  @override
  Widget buildTitle(BuildContext context) {
    return TimelineItemSenderNameAndTimestamp(event: event, omitSender: false);
  }

  @override
  Widget buildSubtitle(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;
    switch (event.type) {
      case EventTypes.Message:
        // TODO: Stickers, emotes; event relationships
        switch (event.messageType) {
          case MessageTypes.Text:
            final formattedBody =
                event.content['formatted_body'] as String?;
            final format = event.content['format'] as String?;
            final textWidget = formattedBody != null &&
                    format == 'org.matrix.custom.html'
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
          case MessageTypes.Image:
            return FutureBuilder(
              future: event.getAttachmentUri(),
              builder: (context, asyncSnapshot) {
                if (asyncSnapshot.connectionState != ConnectionState.done) {
                  return CircularProgressIndicator();
                }
                if (asyncSnapshot.hasData) {
                  return Image.network(
                    asyncSnapshot.data.toString(),
                    headers: {
                      "authorization": "Bearer ${room.client.accessToken}"
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 48),
                  );
                }
                return SizedBox.shrink();
              },
            );
          case MessageTypes.Audio:
            return const Placeholder();
          case MessageTypes.File:
            return ElevatedButton(
              child: const Text("Download"),
              onPressed: () => _downloadFile(),
            );
          default:
            return UnsupportedEventType(event: event);
        }
      default:
        return Text(
          event.body,
          style: TextStyle(fontSize: fs),
        );
    }
  }
}

// FIXME - Make this an extentions on origin type
class FileUtilities {
  const FileUtilities({required this.event});
  final Event event;

  String? getFileMIMEType() => event.content['mimetype']?.toString();
  String? getFileExtention() =>
      event.content['filename']?.toString().split('.').last.toUpperCase();
  String? getFileName() => event.content['filename']?.toString();
}
