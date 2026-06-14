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
import 'package:moonrelay/src/widgets/encryption/trust_indicator.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:provider/provider.dart';

/// Routes each [Event] to the appropriate rendering widget based on its type
/// and message type.
///
/// This is the central dispatch point for the entire event-rendering tree.
/// Extend this when adding support for new event or message types (stickers,
/// polls, location sharing, etc.).
///
/// Encrypted events (m.room.encrypted) are automatically handled by the SDK;
/// this widget wraps the decrypted content with a trust indicator.
class MessageEventHandler extends StatelessWidget {
  const MessageEventHandler({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    // If the event is still encrypted (failed to decrypt), show a warning.
    if (event.type == EventTypes.Encrypted && !event.redacted) {
      final enc = context.watch<EncryptionService>();
      final isVerified = _isDeviceVerified(enc);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrustIndicator(isVerified: isVerified, size: 14),
              const SizedBox(width: 4),
              Expanded(child: _renderContent()),
            ],
          ),
        ],
      );
    }

    // Decrypted or non-encrypted events: show verification status inline.
    if (event.type == EventTypes.Message) {
      final enc = context.watch<EncryptionService>();
      final isVerified = _isDeviceVerified(enc);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.originalSource?.type == EventTypes.Encrypted)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: TrustIndicator(isVerified: isVerified, size: 12),
                ),
              Expanded(child: _renderContent()),
            ],
          ),
        ],
      );
    }

    return _renderContent();
  }

  /// Checks whether the device that sent this event is verified via
  /// cross-signing.
  ///
  /// For decrypted events the sender's device ID is extracted from
  /// the `device_id` field of the original encrypted event wrapper
  /// ([Event.originalSource]).  For undecryptable events ([EventTypes.Encrypted])
  /// the event itself *is* the encrypted event, so its own content
  /// carries the `device_id`.
  ///
  /// Falls back to user-level verification when the sender's device ID is
  /// not available (e.g. unencrypted events).
  bool _isDeviceVerified(EncryptionService enc) {
    // 1. Try the original encrypted source (available after decryption).
    final fromOriginal =
        event.originalSource?.content['device_id'] as String?;
    if (fromOriginal != null) {
      return enc.isDeviceVerifiedById(event.senderId, fromOriginal);
    }

    // 2. For undecryptable events (type == m.room.encrypted), the event
    //    itself carries the `device_id` in its content.
    if (event.type == EventTypes.Encrypted) {
      final fromContent = event.content['device_id'] as String?;
      if (fromContent != null) {
        return enc.isDeviceVerifiedById(event.senderId, fromContent);
      }
    }

    // 3. Fall back to user-level (master-key) verification.
    return enc.isUserVerifiedById(event.senderId);
  }

  Widget _renderContent() {
    // Failed decryption — show the decryption-failed placeholder
    // with a manual key-request button.
    if (event.type == EventTypes.Encrypted) {
      return DecryptionFailedWidget(
        event: event,
        canRequestSession: event.content['can_request_session'] == true,
      );
    }

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
