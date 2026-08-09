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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// A lightweight preview of a single message event.
///
/// We use this instead of the SDK's [Event] because constructing an [Event]
/// requires a [Room] reference, which we don't have for rooms we haven't joined.
class _PreviewEvent {
  final String type;
  final String senderId;
  final DateTime originServerTs;
  final String body;

  _PreviewEvent({
    required this.type,
    required this.senderId,
    required this.originServerTs,
    required this.body,
  });

  static _PreviewEvent? fromMatrixEvent(MatrixEvent m) {
    final type = m.type;
    if (type != EventTypes.Message) return null;
    final body = m.content['body'] as String?;
    if (body == null || body.isEmpty) return null;
    return _PreviewEvent(
      type: type,
      senderId: m.senderId,
      originServerTs: m.originServerTs,
      body: body,
    );
  }
}

/// A preview page for a room the user has not yet joined.
///
/// Shows room identity information (name, topic, avatar, member count), a Join
/// button, and the last few messages in the room (filtered to non-state events).
class RoomPreviewScreen extends StatefulWidget {
  const RoomPreviewScreen({
    super.key,
    required this.roomId,
    this.roomAlias,
    this.via,
  });

  /// The Matrix room ID to preview.
  final String roomId;

  /// Optional canonical alias for display/joining.
  final String? roomAlias;

  /// Optional server names to use when joining/peeking.
  final List<String>? via;

  @override
  State<RoomPreviewScreen> createState() => _RoomPreviewScreenState();
}

class _RoomPreviewScreenState extends State<RoomPreviewScreen> {
  /// Room summary fetched from the server.
  GetRoomSummaryResponse$3? _summary;

  /// Events fetched via peek / getRoomEvents.
  List<_PreviewEvent>? _events;

  bool _summaryLoading = true;
  bool _eventsLoading = true;
  bool _joining = false;
  String? _summaryError;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadEvents();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  /// Fetches the room summary (name, topic, avatar, etc.).
  Future<void> _loadSummary() async {
    final client = context.read<Client>();
    final log = context.read<Logger>();
    try {
      final summary = await client.getRoomSummary(
        widget.roomAlias ?? widget.roomId,
        via: widget.via,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _summaryLoading = false;
      });
    } catch (e) {
      log.w('Failed to load room summary for ${widget.roomId}', error: e);
      if (!mounted) return;
      setState(() {
        _summaryError = '$e';
        _summaryLoading = false;
      });
    }
  }

  /// Tries to fetch recent messages from the room.
  ///
  /// For public / world-readable rooms this will succeed; for private rooms
  /// the server will reject the request and we silently hide the message list.
  Future<void> _loadEvents() async {
    final client = context.read<Client>();
    final log = context.read<Logger>();
    try {
      final response = await client.getRoomEvents(
        widget.roomId,
        Direction.b,
        limit: 20,
      );
      if (!mounted) return;

      // Parse into _PreviewEvent objects and filter out state events.
      final events = <_PreviewEvent>[];
      for (final matrixEvent in response.chunk) {
        final preview = _PreviewEvent.fromMatrixEvent(matrixEvent);
        if (preview != null) {
          events.add(preview);
        }
      }
      // Sort so oldest is first (top-to-bottom reading order).
      events.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

      setState(() {
        _events = events;
        _eventsLoading = false;
      });
    } catch (e) {
      log.i('Could not peek into room ${widget.roomId}: $e');
      if (!mounted) return;
      setState(() => _eventsLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Joins the room and navigates to it.
  Future<void> _joinRoom() async {
    final client = context.read<Client>();
    final log = context.read<Logger>();
    setState(() {
      _joining = true;
      _joinError = null;
    });

    final roomIdOrAlias = widget.roomAlias ?? widget.roomId;
    final result = await withRetry(
      () => client.joinRoom(
        roomIdOrAlias,
        via: widget.via,
      ),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'joinRoom',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        // joinRoom returns the canonical room ID even when the user
        // joined via an alias; navigate with the ID so the room route
        // resolves (getRoomById only matches room IDs).
        context.pushReplacement(
          '/main/rooms/${Uri.encodeComponent(value)}',
        );
      case RetryFailed(:final error):
        setState(() {
          _joinError = error is TimeoutException
              ? AppLocalizations.of(context)!.joiningTimedOut
              : AppLocalizations.of(context)!.couldNotJoinRoom('$error');
          _joining = false;
        });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roomPreviewTitle),
      ),
      body: ListView(
        padding:
            EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceSm),
        children: [
          // ── Identity card ────────────────────────────────────────────
          _buildIdentityCard(cs, textTheme, l10n),
          SizedBox(height: t.spaceXl),

          // ── Join button ──────────────────────────────────────────────
          _buildJoinSection(cs, l10n),
          SizedBox(height: t.spaceXl),

          // ── Recent messages ──────────────────────────────────────────
          if (!_eventsLoading && _events != null && _events!.isNotEmpty) ...[
            _SectionHeader(title: l10n.roomPreviewLastMessages, scheme: cs),
            SizedBox(height: t.spaceSm),
            ..._events!.map((e) => _buildEventTile(cs, e)),
          ] else if (!_eventsLoading &&
              _events != null &&
              _events!.isEmpty) ...[
            _buildEmptyMessages(cs, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentityCard(
    ColorScheme cs,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    if (_summaryLoading) {
      return _buildLoadingCard(cs, l10n);
    }
    if (_summaryError != null) {
      return _buildErrorCard(cs, l10n);
    }

    final s = _summary!;
    final displayName =
        s.name?.isNotEmpty == true ? s.name : s.canonicalAlias ?? widget.roomId;
    final topic = s.topic;
    final memberCount = s.numJoinedMembers;
    final joinRule = s.joinRule;
    final avatarUri = s.avatarUrl;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            SizedBox(
              width: 80,
              height: 80,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: cs.primaryContainer,
                backgroundImage: avatarUri != null
                    ? NetworkImage(avatarUri.toString())
                    : null,
                onBackgroundImageError: avatarUri != null ? (_, __) {} : null,
                child: avatarUri == null
                    ? Icon(
                        LucideIcons.hash,
                        size: 36,
                        color: cs.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              displayName ?? l10n.unknown,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Room ID (mono)
            Text(
              widget.roomId,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),

            // Topic
            if (topic != null && topic.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  topic,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 12),

            // Badge row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: joinRule == 'public'
                      ? LucideIcons.globe
                      : joinRule == 'knock' || joinRule == 'knock_restricted'
                          ? LucideIcons.logIn
                          : LucideIcons.lock,
                  label: joinRule == 'public'
                      ? l10n.publicRoom
                      : joinRule == 'knock' || joinRule == 'knock_restricted'
                          ? l10n.roomTypeKnock
                          : l10n.roomTypeInviteOnly,
                  scheme: cs,
                ),
                _InfoChip(
                  icon: LucideIcons.users,
                  label: '$memberCount ${l10n.members}',
                  scheme: cs,
                ),
              ],
            ),

            // Not-joined notice
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.tertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 16,
                    color: cs.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.roomPreviewNotJoined,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(ColorScheme cs, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Container(
        height: 260,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text(
              l10n.roomPreviewLoading,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme cs, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 40, color: cs.error),
            const SizedBox(height: 12),
            Text(
              l10n.roomPreviewFailed,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinSection(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      children: [
        if (_joinError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, size: 18, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _joinError!,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _summaryLoading || _joining ? null : _joinRoom,
            icon: _joining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.userPlus, size: 18),
            label: Text(
              _joining ? l10n.joining : l10n.roomPreviewJoin,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventTile(ColorScheme cs, _PreviewEvent event) {
    final senderName = event.senderId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
            child: Text(
              senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Message body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      event.originServerTs.localizedTimeOfDay(context),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.body,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages(ColorScheme cs, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              LucideIcons.messageSquare,
              size: 32,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.roomPreviewNoMessages,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Internal widgets (duplicated here to avoid cross-file dependency)
// ═════════════════════════════════════════════════════════════════════════════

/// A small chip used for metadata badges.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: t.opacitySubtle),
        borderRadius: BorderRadius.circular(t.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          SizedBox(width: t.spaceXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section header label.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface.withValues(alpha: 0.6),
        letterSpacing: 0.5,
      ),
    );
  }
}
