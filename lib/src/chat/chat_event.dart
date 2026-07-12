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

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/chat/events/formatted_text_widget.dart';
import 'package:moonrelay/src/chat/events/matrix_url_banner_wrapper.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/audio/audio_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/file/file_attached_message.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/image/image_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/location/location_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/sticker/sticker_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/video_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/state_events.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/verification_notice_event.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/verification_request_event.dart';
import 'package:moonrelay/src/chat/events/unsupported_event.dart';
import 'package:moonrelay/src/chat/poll_message_type.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/encryption/trust_indicator.dart';

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
  const MessageEventHandler({
    super.key,
    required this.event,
    this.timeline,
    this.room,
    this.fontSize = 16.0,
    this.onJumpToEvent,
  });

  final Event event;

  /// The timeline this event belongs to, used to look up replied-to events
  /// locally without an extra network round-trip.
  final Timeline? timeline;

  /// The room this event belongs to, used to fetch replied-to events.
  final Room? room;

  /// Font size for message text, propagated from the parent.
  final double fontSize;

  /// Called when the user taps a reply preview to jump to the replied-to
  /// event.  Receives the event ID of the target event.
  final void Function(String eventId)? onJumpToEvent;

  @override
  Widget build(BuildContext context) {
    final fs = fontSize;

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
              Expanded(child: _renderContent(fs)),
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
              Expanded(child: _renderContent(fs)),
            ],
          ),
        ],
      );
    }

    return _renderContent(fs);
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
    final fromOriginal = event.originalSource?.content['device_id'] as String?;
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

  /// Strips the `<mx-reply>…</mx-reply>` wrapper from a Matrix HTML body
  /// so that the actual message content remains.
  static String _stripReplyHtml(String html) {
    return html.replaceAll(
      RegExp(r'<mx-reply>.*</mx-reply>', dotAll: true, caseSensitive: false),
      '',
    );
  }

  Widget _renderContent(double fontSize) {
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
        // Check if this event is a reply.
        final replyId = event.inReplyToEventId();
        final isReply = replyId != null;

        // Verification events are sent as m.room.message events with
        // a msgtype of m.key.verification.request, .start, .done, etc.
        if (event.messageType.startsWith('m.key.verification.')) {
          if (event.messageType == EventTypes.KeyVerificationRequest) {
            return VerificationRequestEvent(event: event);
          }
          return VerificationNoticeEvent(event: event);
        }

        switch (event.messageType) {
          case MessageTypes.Text:
          case MessageTypes.Emote:
          case MessageTypes.Notice:
            if (isReply) {
              return _buildReplyContent(replyId, fontSize);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextContent(fontSize),
                if (isEditedMessage(event)) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.Image:
            return ImageMessageType(event: event);
          case MessageTypes.Audio:
            return AudioMessageType(event: event);
          case MessageTypes.Video:
            return VideoMessageType(event: event);
          case MessageTypes.File:
            return FileAttachedMessage(event: event);
          case MessageTypes.Location:
            return LocationMessageType(event: event);
          case MessageTypes.Sticker:
            return StickerMessageType(event: event);
          default:
            if (event.type == 'm.poll.start' || event.type == 'm.poll') {
              return PollMessageType(
                event: event,
                room: room ?? event.room,
                timeline: timeline,
              );
            }
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
      case EventTypes.Sticker:
        return StickerMessageType(event: event);
      default:
        // Poll events have `type == m.poll.start`.
        if (event.type == 'm.poll.start') {
          return PollMessageType(
            event: event,
            room: room ?? event.room,
            timeline: timeline,
          );
        }
        // Fallback: check if the event type itself looks like a
        // verification event (some legacy servers may send them as
        // raw event types rather than m.room.message + msgtype).
        if (event.type.startsWith('m.key.verification.')) {
          if (event.type == EventTypes.KeyVerificationRequest) {
            return VerificationRequestEvent(event: event);
          }
          return VerificationNoticeEvent(event: event);
        }
        return StateEvents(event: event);
    }
  }

  /// Builds the content for a text/emote/notice event that is not a reply.
  ///
  /// Wraps the formatted text widget with [MatrixUrlBannerWrapper] so that
  /// any Matrix URLs (room aliases, user IDs, permalinks) found in the body
  /// render as interactive banners below the message.
  Widget _buildTextContent(double fontSize) {
    final textWidget = FormattedTextWidget(
      event: event,
      baseFontSize: fontSize,
      room: room,
    );
    if (room == null) return textWidget;
    return MatrixUrlBannerWrapper(
      textBody: event.body,
      room: room!,
      event: event,
      child: textWidget,
    );
  }

  /// Builds the content for a reply event: a reply preview header followed
  /// by the actual message body (with the `<mx-reply>` wrapper stripped).
  Widget _buildReplyContent(String replyId, double fontSize) {
    // Strip reply HTML from the formatted body so we only render the
    // actual message.
    final rawFormatted = event.content['formatted_body'] as String?;
    final strippedHtml =
        rawFormatted != null ? _stripReplyHtml(rawFormatted) : null;

    // Try to find the replied-to event locally first.
    Event? repliedTo;
    if (timeline != null) {
      try {
        repliedTo = timeline!.events.firstWhere(
          (e) => e.eventId == replyId,
        );
      } catch (_) {
        repliedTo = null;
      }
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReplyPreview(
          repliedTo: repliedTo,
          replyId: replyId,
          room: room,
          onJumpToEvent: onJumpToEvent,
        ),
        const SizedBox(height: 4),
        FormattedTextWidget(
          event: event,
          formattedBodyOverride: strippedHtml,
          baseFontSize: fontSize,
        ),
      ],
    );

    if (room == null) return content;
    return MatrixUrlBannerWrapper(
      textBody: event.body,
      room: room!,
      event: event,
      child: content,
    );
  }
}

/// Displays a short preview of the replied-to message above the reply.
///
/// Tries to show the replied-to message body (truncated with ellipsis)
/// prefixed by a vertical bar in the accent colour.  If the replied-to
/// event isn't available locally, fetches it via [Room.getEventById].
///
/// Long replies (e.g. a quoted code block or a multi-line message) are
/// shown collapsed by default with a "Show more" affordance so a noisy
/// chat doesn't fill the viewport with quoted context.
class _ReplyPreview extends StatefulWidget {
  const _ReplyPreview({
    required this.repliedTo,
    required this.replyId,
    this.room,
    this.onJumpToEvent,
  });

  final Event? repliedTo;
  final String replyId;
  final Room? room;

  /// Called when the user taps the reply preview to jump to the replied-to
  /// event in the timeline.
  final void Function(String eventId)? onJumpToEvent;

  @override
  State<_ReplyPreview> createState() => _ReplyPreviewState();
}

class _ReplyPreviewState extends State<_ReplyPreview> {
  /// When true the full reply body is shown instead of the truncated
  /// single-line preview.  Toggled via the "Show more / Show less"
  /// affordance that appears next to the preview when the body is
  /// long enough to truncate.
  bool _expanded = false;

  /// Number of characters above which the body is considered
  /// "long" and the expand toggle is shown.  Honoured as a fallback
  /// when the [SettingsController] cannot be read from the tree (e.g.
  /// in isolated widget tests).
  static const int _defaultCollapseThreshold = 90;

  @override
  Widget build(BuildContext context) {
    int collapseThreshold = _defaultCollapseThreshold;
    try {
      collapseThreshold =
          context.read<SettingsController>().replyPreviewThreshold;
    } catch (_) {
      // No controller in tree — fall back to the static default.
    }
    if (widget.repliedTo != null) {
      return _buildForBody(context, widget.repliedTo!.body, collapseThreshold);
    }

    // If we have a room, try to fetch the replied-to event.
    if (widget.room != null) {
      return FutureBuilder<Event?>(
        future: widget.room!.getEventById(widget.replyId),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return _buildForBody(
              context,
              snapshot.data!.body,
              collapseThreshold,
            );
          }
          // While loading or on error, show nothing.
          return const SizedBox.shrink();
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildForBody(
    BuildContext context,
    String body,
    int collapseThreshold,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final clean = body.replaceAll(RegExp(r'^>.*$', multiLine: true), '').trim();
    final display = clean.isNotEmpty ? clean : body.trim();
    final canExpand = display.length > collapseThreshold;

    final barAndText = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical bar indicator
        Container(
          width: 3,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          constraints: BoxConstraints(
            minHeight: 20,
            // Cap the bar at a short height so very long quoted text
            // doesn't push the rest of the chat down — the toggle
            // affordance below it gives the user a way to read the
            // full body when they actually want to.
            maxHeight: _expanded ? double.infinity : 40,
          ),
        ),
        Expanded(
          child: Text(
            display,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
            maxLines: _expanded ? null : 1,
            overflow: _expanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onJumpToEvent != null)
          GestureDetector(
            onTap: () => widget.onJumpToEvent!(widget.replyId),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: barAndText,
            ),
          )
        else
          barAndText,
        if (canExpand)
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 2),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                child: Text(
                  _expanded
                      ? AppLocalizations.of(context)!.replyShowLess
                      : AppLocalizations.of(context)!.replyShowMore,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return preview;
  }
}

/// A small "(edited)" marker rendered immediately after a message body.
///
/// Inline rather than a popup because Matrix edits may happen many times
/// over the lifetime of a message; a permanent indicator is clearer than
/// a hidden affordance.
class _EditedMarker extends StatelessWidget {
  const _EditedMarker({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        l10n.editedIndicator,
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Whether [event] has a `m.replace` relation pointing to an original event.
bool isEditedMessage(Event event) {
  try {
    final rel = event.content['m.relates_to'];
    if (rel is! Map) return false;
    return rel['rel_type'] == 'm.replace' && rel['event_id'] is String;
  } catch (_) {
    return false;
  }
}
