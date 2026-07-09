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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// A small footer that shows "(name) is typing…" for the active room.
///
/// The Matrix SDK exposes [Room.typingUsers] (and updates it on
/// `m.typing` ephemeral events). We listen to the room's sync stream so
/// that the indicator refreshes whenever a typing notification arrives.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.room});
  final Room room;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> {
  StreamSubscription<Object?>? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncSub = widget.room.client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final typingUsers = widget.room.typingUsers
        .where((u) => u.id != widget.room.client.userID)
        .toList();

    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    String label;
    if (typingUsers.length == 1) {
      label = l10n.typingIndicatorOne(typingUsers.first.calcDisplayname());
    } else if (typingUsers.length == 2) {
      label = l10n.typingIndicatorTwo(
        typingUsers[0].calcDisplayname(),
        typingUsers[1].calcDisplayname(),
      );
    } else {
      label = l10n.typingIndicatorMany(
        typingUsers[0].calcDisplayname(),
        typingUsers[1].calcDisplayname(),
        typingUsers.length - 2,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _BouncingDots(color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots({required this.color});
  final Color color;

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i / 3.0) % 1.0;
            final dy = (1 - (phase * 2 - 1).abs()) * -4.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Sends an `m.typing` notification for [room], then schedules a stop
/// after [duration]. Used by the chat box while the user is typing.
class TypingNotifier {
  TypingNotifier(this._room);
  final Room _room;
  Timer? _stopTimer;

  /// Notifies the homeserver that the user is typing, restarting the
  /// auto-stop timer. Safe to call on every keystroke. No-op when the
  /// client is not logged in (no `userID`) — callers in widget tests
  /// and pre-login flows depend on this guard.
  void notify() {
    final userId = _room.client.userID;
    if (userId == null) return;
    unawaited(
      withTimeout(
        () => _room.client.setTyping(
          userId,
          _room.id,
          true,
          timeout: 4000,
        ),
        timeout: const Duration(seconds: 5),
      ),
    );
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(milliseconds: 4000), _stop);
  }

  void _stop() {
    _stopTimer?.cancel();
    final userId = _room.client.userID;
    if (userId == null) return;
    unawaited(
      withTimeout(
        () => _room.client.setTyping(
          userId,
          _room.id,
          false,
        ),
        timeout: const Duration(seconds: 5),
      ),
    );
  }

  void dispose() {
    _stopTimer?.cancel();
    _stopTimer = null;
  }
}