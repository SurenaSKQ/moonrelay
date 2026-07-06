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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Renders MSC3381 / `m.poll.start` events as a card with the question,
/// the answer options, and a button to vote. Aggregated vote counts are
/// computed by scanning the room's timeline for `m.poll.response` events
/// related to this poll.
class PollMessageType extends StatefulWidget {
  const PollMessageType({
    super.key,
    required this.event,
    required this.room,
    this.timeline,
  });
  final Event event;
  final Room room;
  final Timeline? timeline;

  @override
  State<PollMessageType> createState() => _PollMessageTypeState();
}

class _PollMessageTypeState extends State<PollMessageType> {
  late Future<_PollState> _state;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  Future<_PollState> _load() async {
    final events = widget.timeline?.events ?? [];
    final responses = events
        .where((e) => _isPollResponseFor(e, widget.event.eventId))
        .toList();

    final voteCounts = <String, int>{};
    final userVoteIds = <String>{};
    final clientUserId = widget.room.client.userID;
    for (final r in responses) {
      final rel = r.content['m.poll.response'];
      final ids = _answersInResponse(rel);
      for (final id in ids) {
        voteCounts[id] = (voteCounts[id] ?? 0) + 1;
        if (r.senderId == clientUserId) {
          userVoteIds.add(id);
        }
      }
    }

    final poll = widget.event.content['m.poll'];
    if (poll is! Map) {
      return _PollState.invalid();
    }
    final question = (poll['question'] is Map)
        ? (poll['question']['body']?.toString() ?? '')
        : poll['question']?.toString() ?? '';
    final answers = (poll['answers'] is List)
        ? (poll['answers'] as List).whereType<Map>().toList()
        : <Map<dynamic, dynamic>>[];
    final answersCast = answers
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final ended = (poll['end_time'] is int) ||
        (widget.event.content['end_time'] is int);
    final maxSelections =
        (poll['max_selections'] as int?) ?? 1;

    return _PollState(
      question: question,
      answers: answersCast,
      voteCounts: voteCounts,
      userVoteIds: userVoteIds,
      ended: ended,
      maxSelections: maxSelections,
      totalVotes: responses.length,
    );
  }

  bool _isPollResponseFor(Event e, String pollStartEventId) {
    final rel = e.content['m.relates_to'];
    if (rel is! Map) return false;
    if (rel['rel_type'] != 'm.poll.response') return false;
    return rel['event_id'] == pollStartEventId;
  }

  List<String> _answersInResponse(dynamic rel) {
    if (rel is! Map) return const [];
    final a = rel['answers'];
    if (a is List) return a.map((e) => e.toString()).toList();
    return const [];
  }

  Future<void> _vote(String answerId) async {
    setState(() {});
    try {
      await withRetry(
        () => widget.room.sendEvent(<String, dynamic>{
          'm.relates_to': <String, dynamic>{
            'rel_type': 'm.poll.response',
            'event_id': widget.event.eventId,
            'm.poll.response': <String, dynamic>{
              'answers': [answerId],
            },
          },
          'body': '',
          'msgtype': 'm.text',
        }),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: null,
        label: 'pollVote',
      );
      if (mounted) setState(() => _state = _load());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<_PollState>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading(cs);
        }
        if (!snapshot.hasData || !snapshot.data!.valid) {
          return _buildUnavailable(cs);
        }
        final state = snapshot.data!;
        return _buildCard(state, cs, l10n);
      },
    );
  }

  Widget _buildCard(_PollState state, ColorScheme cs, AppLocalizations l10n) {
    final maxCount = state.voteCounts.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Icon(LucideIcons.listChecks, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.ended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.pollClosed,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: cs.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Options ───────────────────────────────────────────────
          ...state.answers.map((a) {
            final id = a['id']?.toString() ?? '';
            final text = a['body']?.toString() ?? '';
            final count = state.voteCounts[id] ?? 0;
            final voted = state.userVoteIds.contains(id);
            final percent = maxCount == 0
                ? 0.0
                : (count / maxCount).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PollOptionTile(
                text: text,
                count: count,
                percent: percent,
                voted: voted,
                closed: state.ended,
                onTap: state.ended ? null : () => _vote(id),
                l10n: l10n,
                cs: cs,
              ),
            );
          }),

          const SizedBox(height: 4),
          Text(
            l10n.pollTotalVotes(state.totalVotes),
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Container(
      width: 220,
      height: 80,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildUnavailable(ColorScheme cs) {
    return Container(
      width: 220,
      height: 80,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          LucideIcons.listChecks,
          size: 28,
          color: cs.error,
        ),
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.text,
    required this.count,
    required this.percent,
    required this.voted,
    required this.closed,
    required this.onTap,
    required this.l10n,
    required this.cs,
  });

  final String text;
  final int count;
  final double percent;
  final bool voted;
  final bool closed;
  final VoidCallback? onTap;
  final AppLocalizations l10n;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          // ── Fill bar ─────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: voted
                      ? cs.primary
                      : cs.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // ── Content ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                if (voted)
                  Icon(LucideIcons.check, size: 16, color: cs.onPrimary)
                else
                  Icon(LucideIcons.circle, size: 16, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: voted ? FontWeight.w700 : FontWeight.w500,
                      color: voted ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  l10n.pollResults(count),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: voted ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PollState {
  _PollState({
    required this.question,
    required this.answers,
    required this.voteCounts,
    required this.userVoteIds,
    required this.ended,
    required this.maxSelections,
    required this.totalVotes,
  });

  factory _PollState.invalid() => _PollState(
        question: '',
        answers: const [],
        voteCounts: const {},
        userVoteIds: const {},
        ended: false,
        maxSelections: 1,
        totalVotes: 0,
      );

  final String question;
  final List<Map<String, dynamic>> answers;
  final Map<String, int> voteCounts;
  final Set<String> userVoteIds;
  final bool ended;
  final int maxSelections;
  final int totalVotes;

  bool get valid => question.isNotEmpty && answers.isNotEmpty;
}