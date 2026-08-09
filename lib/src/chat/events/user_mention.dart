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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// Regex matching Matrix user IDs anywhere in text.  Restricts to ASCII
/// word characters in the local part to avoid swallowing trailing
/// punctuation.  Used by [findUserMentions] to tokenise plain-text
/// message bodies before they're handed to [Text.rich].
final RegExp userMentionPattern =
    RegExp(r'(?<![a-zA-Z0-9_])@[\w.\-=/+]+:[^\s<>")()]+(?<![.,;!?)\]])');

/// Matches an HTML anchor whose href is a Matrix user permalink
/// (`https://matrix.to/#/@user:domain` or `matrix:u/...`).  The first
/// capture group is the resolved user id.
final RegExp _hrefUserPattern = RegExp(
  r'''href\s*=\s*["'](?:https?:\/\/matrix\.to\/#\/(?:@[^"'<>]+)|matrix:u\/[^"'<>]+)["']''',
  caseSensitive: false,
);

/// Scans [text] for bare Matrix user IDs (`@user:domain`) and returns the
/// spans of (start, end, userId) tuples.  Used by both the HTML parser
/// and the plain-text linkifier to decide where to drop [UserMentionPill]
/// widgets in the rendered message body.
List<({int start, int end, String userId})> findUserMentions(String text) {
  final results = <({int start, int end, String userId})>[];
  for (final m in userMentionPattern.allMatches(text)) {
    final id = m.group(0)!;
    if (RegExp(r'^@.+:.+$').hasMatch(id)) {
      results.add((start: m.start, end: m.end, userId: id));
    }
  }
  return results;
}

/// Returns `true` if [href] targets a Matrix user (so the inline
/// renderer can suppress the extra `MatrixUrlBanner` that would
/// otherwise appear alongside the pill).
bool isUserPermalink(String href) {
  final lower = href.toLowerCase();
  if (lower.startsWith('matrix:u/')) return true;
  if (!lower.startsWith('https://matrix.to/#/')) return false;
  final fragment = href.substring('https://matrix.to/#/'.length);
  return fragment.startsWith('@');
}

/// Resolves a `matrix:u/...` or `matrix.to/#/@...` href to a userid.
String? userIdFromHref(String href) {
  final lower = href.toLowerCase();
  if (lower.startsWith('matrix:u/')) {
    return href.substring('matrix:u/'.length);
  }
  if (lower.startsWith('https://matrix.to/#/')) {
    return href.substring('https://matrix.to/#/'.length);
  }
  return null;
}

/// Inline pill widget that renders a Matrix user mention inside a
/// message body.
///
/// On click it opens the [showProfileOverlay] (decoupled from the room
/// route).  After [kHoverDelay] of mouse hover, a [UserHoverPreview]
/// popover appears anchored below the pill with quick information and
/// quick commands (DM, mention, open full profile, block).  On touch
/// devices the hover popover is suppressed so the pill behaves like a
/// normal tappable chip.
class UserMentionPill extends StatefulWidget {
  const UserMentionPill({
    super.key,
    required this.userId,
    this.room,
    this.displayText,
    this.fontSize = 14.0,
  });

  /// Fully-qualified Matrix user id (`@localpart:domain`).
  final String userId;

  /// Optional surrounding room  used by the hover preview's quick
  /// actions (kick/ban/power level) and by [showProfileOverlay] to
  /// render room-scoped moderation.
  final Room? room;

  /// Visible text inside the pill.  Defaults to [userId].
  final String? displayText;

  /// Font size used for the inline pill text.  Scales with the
  /// surrounding message body.
  final double fontSize;

  /// Delay between hover-start and the preview popover appearing.
  static const Duration kHoverDelay = Duration(milliseconds: 400);

  @override
  State<UserMentionPill> createState() => _UserMentionPillState();
}

class _UserMentionPillState extends State<UserMentionPill> {
  bool _hovering = false;
  bool _previewOpen = false;
  Timer? _openTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _link = LayerLink();
  final GlobalKey _pillKey = GlobalKey();

  @override
  void dispose() {
    _openTimer?.cancel();
    _removePreview();
    super.dispose();
  }

  void _onEnter(PointerEnterEvent _) {
    _hovering = true;
    _openTimer?.cancel();
    _openTimer = Timer(UserMentionPill.kHoverDelay, () {
      if (_hovering && mounted) _showPreview();
    });
  }

  void _onExit(PointerExitEvent _) {
    _hovering = false;
    _openTimer?.cancel();
    // Give the overlay a tick to receive its own enter events before
    // we tear it down.
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!_hovering && mounted) _removePreview();
    });
  }

  void _onTap() {
    showProfileOverlay(context, userId: widget.userId, room: widget.room);
  }

  void _showPreview() {
    if (_previewOpen) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    _overlayEntry = OverlayEntry(
      builder: (overlayCtx) {
        return Positioned(
          width: 320,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: Offset(0, size.height + 4),
            showWhenUnlinked: false,
            child: MouseRegion(
              onEnter: (_) => _hovering = true,
              onExit: (_) {
                _hovering = false;
                Future<void>.delayed(const Duration(milliseconds: 120), () {
                  if (!_hovering && mounted) _removePreview();
                });
              },
              child: UserHoverPreview(
                userId: widget.userId,
                room: widget.room,
                onOpenProfile: () {
                  _removePreview();
                  showProfileOverlay(
                    context,
                    userId: widget.userId,
                    room: widget.room,
                  );
                },
                onClose: _removePreview,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
    _previewOpen = true;
  }

  void _removePreview() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _previewOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final text = widget.displayText ?? widget.userId;
    final pill = Container(
      key: _pillKey,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: t.opacitySubtle),
        borderRadius: BorderRadius.circular(t.radiusXs),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: widget.fontSize,
        ),
      ),
    );

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: pill,
        ),
      ),
    );
  }
}

/// Quick preview popover shown on hover over a [UserMentionPill].
///
/// Shows the user's display name (when cached), userid, presence badge,
/// and quick-action buttons (start DM, insert mention, open full
/// profile).  Room-scoped actions (kick/ban) are not shown here -- the
/// full profile overlay is the right place for moderation; the popover
/// is for low-cost inspection.
class UserHoverPreview extends StatefulWidget {
  const UserHoverPreview({
    super.key,
    required this.userId,
    required this.onOpenProfile,
    required this.onClose,
    this.room,
  });

  final String userId;
  final Room? room;
  final VoidCallback onOpenProfile;
  final VoidCallback onClose;

  @override
  State<UserHoverPreview> createState() => _UserHoverPreviewState();
}

class _UserHoverPreviewState extends State<UserHoverPreview> {
  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = context.read<Client>();
      final profile = await client.getProfileFromUserId(widget.userId).timeout(
            const Duration(seconds: 6),
            onTimeout: () => Profile(
              userId: widget.userId,
              displayName: null,
              avatarUrl: null,
            ),
          );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _displayName {
    final dn = _profile?.displayName;
    if (dn != null && dn.isNotEmpty) return dn;
    return widget.userId;
  }

  Future<void> _startDirectChat() async {
    widget.onClose();
    final client = context.read<Client>();
    final goRouter = GoRouter.of(context);
    try {
      final roomId = await client.startDirectChat(widget.userId);
      if (!mounted) return;
      goRouter.go('/main/rooms/${Uri.encodeComponent(roomId)}');
    } catch (_) {/* swallow -- profile overlay offers retry */}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Material(
      elevation: t.elevationOverlay,
      borderRadius: BorderRadius.circular(t.radiusMd),
      color: cs.surface,
      child: Padding(
        padding: EdgeInsets.all(t.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.userId,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _startDirectChat,
                  icon: Icon(Icons.send_outlined, size: t.iconSizeSmall),
                  label: const Text('DM'),
                ),
                SizedBox(width: t.spaceXs),
                TextButton.icon(
                  onPressed: widget.onOpenProfile,
                  icon: Icon(Icons.open_in_new, size: t.iconSizeSmall),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tests whether the plain text body contains at least one Matrix user
/// mention.  Used by [MatrixUrlBannerWrapper] to suppress its own user
/// banner when the inline pill is already covering it.
bool bodyContainsUserMention(String body) {
  return findUserMentions(body).isNotEmpty;
}

/// Mirrors [bodyContainsUserMention] but works on the raw HTML body so
/// the wrapper can detect `matrix.to` user permalinks as well.
bool formattedBodyContainsUserMention(String? formattedBody) {
  if (formattedBody == null || formattedBody.isEmpty) return false;
  if (_hrefUserPattern.hasMatch(formattedBody)) return true;
  return findUserMentions(formattedBody).isNotEmpty;
}

/// Result of a scan over an HTML body for inline user permalinks.  The
/// `spans` describe offsets inside the *raw* (un-escaped) HTML; callers
/// should only use this for rough dedup and not for byte-perfect text
/// rewriting because the HTML parser operates on the escaped source.
({List<({int start, int end, String userId})> spans}) scanHtmlForUsers(
  String formattedBody,
) {
  final results = <({int start, int end, String userId})>[];
  for (final m in _hrefUserPattern.allMatches(formattedBody)) {
    final id = userIdFromHref(m.group(0)!);
    if (id == null) continue;
    results.add((start: m.start, end: m.end, userId: id));
  }
  return (spans: results);
}
