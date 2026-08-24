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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
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
class MessageEventHandler extends StatefulWidget {
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
  State<MessageEventHandler> createState() => _MessageEventHandlerState();
}

class _MessageEventHandlerState extends State<MessageEventHandler> {
  /// Captures the inputs that influence what this widget renders.  Used
  /// by [didUpdateWidget] to short-circuit rebuilds when nothing
  /// rendering-relevant has changed.
  ///
  /// The matrix SDK mutates [Event.content] and [Event.messageType]
  /// in place, so identity comparison alone isn't enough: we hash the
  /// dispatch-determining fields.  This trims the rebuild cost on every
  /// parent build during rapid scrolling -- the cached subtree is
  /// replayed verbatim when the key is unchanged.
  late _HandlerRenderKey _renderKey;
  Widget? _cachedSubtree;

  @override
  void initState() {
    super.initState();
    _renderKey = _computeKey();
  }

  @override
  void didUpdateWidget(covariant MessageEventHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _computeKey();
    if (next == _renderKey) return;
    _renderKey = next;
    _cachedSubtree = null;
  }

  /// Hash of every input that influences the rendered widget subtree.
  /// Captures identity via the [contentIdentity] / [bodyLength] /
  /// [formattedBodyLength] pair so an in-place edit of an existing
  /// event invalidates the cache.
  _HandlerRenderKey _computeKey() {
    final ev = widget.event;
    final content = ev.content;
    final rawBody = content['body'] as String?;
    final rawFormatted = content['formatted_body'] as String?;
    final timeline = widget.timeline;
    // Compute a hash that changes when a new edit arrives for this event.
    // The SDK stores edits in timeline.aggregatedEvents but does NOT
    // mutate the original event's content, so contentIdentity alone
    // won't detect an edit.  We hash the latest edit event's timestamp
    // to bust the cache when edits arrive.
    int editVersion = 0;
    if (timeline != null &&
        ev.hasAggregatedEvents(timeline, RelationshipTypes.edit)) {
      final edits = ev.aggregatedEvents(timeline, RelationshipTypes.edit);
      // Use the most recent edit's timestamp for versioning.
      var latestTs = 0;
      for (final e in edits) {
        final ts = e.originServerTs.millisecondsSinceEpoch;
        if (ts > latestTs) latestTs = ts;
      }
      editVersion = latestTs;
    }
    return _HandlerRenderKey(
      eventId: ev.eventId,
      type: ev.type,
      messageType: ev.messageType,
      inReplyTo: ev.inReplyToEventId(),
      redacted: ev.redacted,
      originalSourceType: ev.originalSource?.type,
      contentIdentity: identityHashCode(content),
      bodyLength: rawBody?.length ?? 0,
      formattedBodyLength: rawFormatted?.length ?? 0,
      replyThreshold: _cachedReplyThreshold,
      fontSizeBucket: (widget.fontSize * 10).round(),
      timelineIdentity: identityHashCode(timeline),
      roomIdentity: identityHashCode(widget.room),
      editVersion: editVersion,
    );
  }

  /// Cached read of [SettingsController.replyPreviewThreshold], populated
  /// lazily on the first [didChangeDependencies] so widget tests that
  /// don't mount a provider tree still work.  Keying on this in the
  /// [_HandlerRenderKey] lets the cache survive a font-size / threshold
  /// change without being torn down wholesale.
  int _cachedReplyThreshold = 90;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final next =
          context.read<SettingsController>().replyPreviewThreshold;
      if (next != _cachedReplyThreshold) {
        _cachedReplyThreshold = next;
        final updated = _computeKey();
        if (updated != _renderKey) {
          setState(() {
            _renderKey = updated;
            _cachedSubtree = null;
          });
          return;
        }
      }
    } catch (_) {
      // No provider in tree -- keep the static default.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cached = _cachedSubtree;
    if (cached != null) return cached;

    final fs = widget.fontSize;
    // Use `read` rather than `watch` so this widget does NOT subscribe
    // to [EncryptionService] notifications. The verification result is
    // memoized internally (see `EncryptionService.isDeviceVerifiedById`)
    // so the cost per build is O(1), and the widget only needs to
    // re-render when the underlying event or its surroundings change.
    // Previously this `watch` caused every visible message in the
    // timeline to rebuild on every sync tick.
    final enc = context.read<EncryptionService>();
    final result = _build(enc, fs);
    _cachedSubtree = result;
    return result;
  }

  /// The actual dispatch.  Pulled out of [build] so the cache-replay
  /// short-circuit stays one path.
  Widget _build(EncryptionService enc, double fs) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final event = widget.event;

    // If the event is still encrypted (failed to decrypt), show a warning.
    if (event.type == EventTypes.Encrypted && !event.redacted) {
      final isVerified = _isDeviceVerified(enc);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrustIndicator(isVerified: isVerified, size: 14),
              SizedBox(width: t.spaceXs),
              Expanded(child: _renderContent(fs)),
            ],
          ),
        ],
      );
    }

    // Decrypted or non-encrypted events: show verification status inline.
    if (event.type == EventTypes.Message) {
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
                  padding: EdgeInsets.only(
                      top: t.spaceXxs, right: t.spaceXs),
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

  /// Checks whether the device that sent [event] is verified via
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
  static bool _isDeviceVerifiedFor(
      EncryptionService enc, Event event) {
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

  /// Convenience instance accessor used by [_build] so the call sites
  /// stay short and reference the current widget event without a
  /// shadowing local.
  bool _isDeviceVerified(EncryptionService enc) =>
      _isDeviceVerifiedFor(enc, widget.event);

  /// Strips the `<mx-reply>…</mx-reply>` wrapper from a Matrix HTML body
  /// so that the actual message content remains.
  static String _stripReplyHtml(String html) {
    return html.replaceAll(
      RegExp(r'<mx-reply>.*</mx-reply>', dotAll: true, caseSensitive: false),
      '',
    );
  }

  Widget _renderContent(double fontSize) {
    final event = widget.event;
    final room = widget.room;
    final timeline = widget.timeline;
    // Failed decryption: show the decryption-failed placeholder
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

        final isEdited = timeline != null &&
            event.hasAggregatedEvents(timeline, RelationshipTypes.edit);

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
                if (isEdited) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.Image:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ImageMessageType(event: event),
                if (isEdited) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.Audio:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AudioMessageType(event: event),
                if (isEdited) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.Video:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoMessageType(event: event),
                if (isEdited) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.File:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FileAttachedMessage(event: event),
                if (isEdited) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.Location:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LocationMessageType(event: event),
                if (isEdited) _EditedMarker(event: event),
              ],
            );
          case MessageTypes.Sticker:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                StickerMessageType(event: event),
                if (isEdited) _EditedMarker(event: event),
              ],
            );
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
    final event = widget.event;
    final room = widget.room;
    final timeline = widget.timeline;
    // Use the SDK's edit-aware display event so edited messages render
    // with the latest m.new_content body instead of the original text.
    final displayEvent =
        timeline != null ? event.getDisplayEvent(timeline) : event;
    final textWidget = FormattedTextWidget(
      event: displayEvent,
      baseFontSize: fontSize,
      room: room,
    );
    if (room == null) return textWidget;
    return MatrixUrlBannerWrapper(
      textBody: displayEvent.body,
      room: room,
      event: displayEvent,
      child: textWidget,
    );
  }

  /// Builds the content for a reply event: a reply preview header followed
  /// by the actual message body (with the `<mx-reply>` wrapper stripped).
  Widget _buildReplyContent(String replyId, double fontSize) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final event = widget.event;
    final room = widget.room;
    final timeline = widget.timeline;
    final isEdited = timeline != null &&
        event.hasAggregatedEvents(timeline, RelationshipTypes.edit);
    // Use the SDK's edit-aware display event so the reply body reflects
    // the latest edit.
    final displayEvent =
        timeline != null ? event.getDisplayEvent(timeline) : event;
    // Strip reply HTML from the formatted body so we only render the
    // actual message.  For edited messages m.new_content already lacks
    // the <mx-reply> wrapper so stripping is a no-op.
    final rawFormatted = displayEvent.content['formatted_body'] as String?;
    final strippedHtml =
        rawFormatted != null ? _stripReplyHtml(rawFormatted) : null;

    // Try to find the replied-to event locally first.
    Event? repliedTo;
    if (timeline != null) {
      try {
        repliedTo = timeline.events.firstWhere(
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
          onJumpToEvent: widget.onJumpToEvent,
        ),
        SizedBox(height: t.spaceXs),
        FormattedTextWidget(
          event: displayEvent,
          formattedBodyOverride: strippedHtml,
          baseFontSize: fontSize,
        ),
        if (isEdited) _EditedMarker(event: event),
      ],
    );

    if (room == null) return content;
    return MatrixUrlBannerWrapper(
      textBody: displayEvent.body,
      room: room,
      event: displayEvent,
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

  /// Memoized future for the missing-event fetch. Without this the
  /// build method would create a new `getEventById` future on every
  /// parent rebuild: a sync tick while the preview is mounted would
  /// re-issue the network call, leak the in-flight future, and
  /// flicker the placeholder.
  Future<Event?>? _pendingFetch;

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
      // No controller in tree: fall back to the static default.
    }
    if (widget.repliedTo != null) {
      return _buildForBody(context, widget.repliedTo!.body, collapseThreshold);
    }

    // If we have a room, try to fetch the replied-to event. The
    // future is memoized per (room, replyId) so a parent rebuild
    // doesn't re-issue the same fetch.
    if (widget.room != null) {
      _pendingFetch ??= widget.room!.getEventById(widget.replyId);
      return FutureBuilder<Event?>(
        future: _pendingFetch,
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

  @override
  void didUpdateWidget(covariant _ReplyPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the reply target changed, drop the cached fetch so the next
    // build kicks off a fresh one.
    if (oldWidget.replyId != widget.replyId ||
        oldWidget.room?.id != widget.room?.id) {
      _pendingFetch = null;
    }
  }

  @override
  void dispose() {
    _pendingFetch = null;
    super.dispose();
  }

  Widget _buildForBody(
    BuildContext context,
    String body,
    int collapseThreshold,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final clean = body.replaceAll(RegExp(r'^>.*$', multiLine: true), '').trim();
    final display = clean.isNotEmpty ? clean : body.trim();
    final canExpand = display.length > collapseThreshold;

    final barAndText = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical bar indicator
        Container(
          width: 3,
          margin: EdgeInsets.only(right: t.spaceSm),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          constraints: BoxConstraints(
            minHeight: 20,
            // Cap the bar at a short height so very long quoted text
            // doesn't push the rest of the chat down; the toggle
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
            padding: EdgeInsets.only(left: 11, top: t.spaceXxs),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(t.radiusXs),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: t.spaceXs,
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(top: t.spaceXxs),
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

/// Compact equality record used by
/// [_MessageEventHandlerState] to short-circuit rebuilds when nothing
/// rendering-relevant has changed.
///
/// Captures identity (content map, timeline, room) so an in-place
/// edit of an event invalidates the cache, plus length fingerprints
/// of the body / formatted body so an SDK mutation that swaps the
/// string in place still triggers a rebuild.
@immutable
class _HandlerRenderKey {
  const _HandlerRenderKey({
    required this.eventId,
    required this.type,
    required this.messageType,
    required this.inReplyTo,
    required this.redacted,
    required this.originalSourceType,
    required this.contentIdentity,
    required this.bodyLength,
    required this.formattedBodyLength,
    required this.replyThreshold,
    required this.fontSizeBucket,
    required this.timelineIdentity,
    required this.roomIdentity,
    required this.editVersion,
  });

  final String eventId;
  final String type;
  final String messageType;
  final String? inReplyTo;
  final bool redacted;
  final String? originalSourceType;
  final int contentIdentity;
  final int bodyLength;
  final int formattedBodyLength;
  final int replyThreshold;
  final int fontSizeBucket;
  final int timelineIdentity;
  final int roomIdentity;

  /// Monotonic version bumped by the latest edit's timestamp so an edit
  /// arriving via sync invalidates the render cache even though the
  /// original event's content map is untouched.
  final int editVersion;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _HandlerRenderKey &&
        other.eventId == eventId &&
        other.type == type &&
        other.messageType == messageType &&
        other.inReplyTo == inReplyTo &&
        other.redacted == redacted &&
        other.originalSourceType == originalSourceType &&
        other.contentIdentity == contentIdentity &&
        other.bodyLength == bodyLength &&
        other.formattedBodyLength == formattedBodyLength &&
        other.replyThreshold == replyThreshold &&
        other.fontSizeBucket == fontSizeBucket &&
        other.timelineIdentity == timelineIdentity &&
        other.roomIdentity == roomIdentity &&
        other.editVersion == editVersion;
  }

  @override
  int get hashCode => Object.hash(
        eventId,
        type,
        messageType,
        inReplyTo,
        redacted,
        originalSourceType,
        contentIdentity,
        bodyLength,
        formattedBodyLength,
        replyThreshold,
        fontSizeBucket,
        timelineIdentity,
        roomIdentity,
        editVersion,
      );
}
