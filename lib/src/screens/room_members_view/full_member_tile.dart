// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/presence_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

class FullMemberTile extends StatefulWidget {
  const FullMemberTile({
    super.key,
    required this.member,
    required this.displayName,
    this.permissionLabel,
    required this.scheme,
  });

  final User member;
  final String displayName;
  final String? permissionLabel;
  final ColorScheme scheme;

  @override
  State<FullMemberTile> createState() => FullMemberTileState();
}

class FullMemberTileState extends State<FullMemberTile> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    // Watched rather than fetched once: the bus delivers presence events
    // as they arrive over /sync, so a member coming online updates this
    // row without the list being reopened. The fetch is kicked off from
    // the same subtree and only seeds the SDK's cache.
    final bus = context.read<PresenceBus?>();
    final membershipLabel = switch (widget.member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    // Absent bus (logged-out tree, or a test with no provider) means the
    // row renders with no presence line, which is the pre-bus behaviour
    // for a user whose presence was never fetched.
    if (bus == null) {
      return _buildTile(context, l10n, t, null, membershipLabel);
    }
    return ValueListenableBuilder<CachedPresence?>(
      valueListenable: bus.listenTo(widget.member.id),
      builder: (context, live, __) => _buildTile(
        context,
        l10n,
        t,
        live ?? bus.presenceOf(widget.member.id),
        membershipLabel,
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    AppLocalizations l10n,
    MoonrelayDesignTokens t,
    CachedPresence? presence,
    String? membershipLabel,
  ) {
    final lastSeenText = _buildLastSeenText(context, presence);
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusMd),
          onTap: () => _showContextMenu(context),
          onSecondaryTap: () => _showContextMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                // Avatar
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AvatarFromUriOrFallbackImage(
                    client: widget.member.room.client,
                    avatarUri: widget.member.avatarUrl,
                  ),
                ),
                SizedBox(width: t.spaceMd),

                // Name + ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.permissionLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: widget.scheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.permissionLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.member.id,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lastSeenText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            lastSeenText,
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.scheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // Membership badge (if not joined)
                if (membershipLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.scheme.tertiaryContainer
                          .withValues(alpha: t.opacitySubtle),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      membershipLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a context menu with actions for this member.
  void _showContextMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 200,
        offset.dy,
        offset.dx + 400,
        offset.dy + 60,
      ),
      items: [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_rounded),
            title: Text(AppLocalizations.of(context)!.viewProfile),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'message',
          child: ListTile(
            leading: Icon(Icons.chat_rounded),
            title: Text(AppLocalizations.of(context)!.sendMessage),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'profile':
          _openProfile(context);
        case 'message':
          _sendMessage(context);
      }
    });
  }

  void _openProfile(BuildContext context) {
    showProfileOverlay(
      context,
      userId: widget.member.id,
      room: widget.member.room,
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    final log = context.read<Logger>();
    final goRouter = GoRouter.of(context);
    final navigator = Navigator.of(context);

    final result = await withRetry(
      () => widget.member.startDirectChat(),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'startDirectChat',
    );

    if (!context.mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        navigator.pop();
        goRouter.go('/main/rooms/$value');
      case RetryFailed(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is TimeoutException
                ? AppLocalizations.of(context)!.couldNotStartChatTimeout
                : AppLocalizations.of(context)!.couldNotStartChat('$error')),
          ),
        );
    }
  }

  String? _buildLastSeenText(BuildContext context, CachedPresence? presence) {
    final ts = presence?.lastActiveTimestamp;
    if (ts == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final timeStr = ts.relativeTimeShort(context);
    return switch (presence!.presence) {
      PresenceType.online => l10n.activeAgo(timeStr),
      _ => l10n.lastSeenAgo(timeStr),
    };
  }
}
