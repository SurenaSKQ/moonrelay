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
import 'package:moonrelay/src/chat/events/attachment_card.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/feedback.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The fraction of its bar an option's vote count should fill.
///
/// Relative to the total, not to the leading option. A bar scaled to the
/// maximum is the same drawing for "one vote each across ten options" and
/// "everybody picked the same one": the leading bar comes out full either way,
/// so the chart says nothing about how the votes actually split. Ten options at
/// one vote each rendered as ten full bars.
///
/// Zero votes is zero width rather than a division by zero, and the clamp is
/// belt and braces for a tally that counts each voter once.
double pollBarShare(int count, int totalVotes) =>
    totalVotes <= 0 ? 0 : (count / totalVotes).clamp(0.0, 1.0);

/// One `m.poll.response`, reduced to what the tally needs.
typedef PollResponse = ({String sender, List<String> answers});

/// The result of counting a poll's responses.
class PollTally {
  const PollTally({
    required this.counts,
    required this.answersBySender,
    required this.voters,
  });

  /// Vote count per answer id.
  final Map<String, int> counts;

  /// The answers each sender's current vote consists of.
  final Map<String, Set<String>> answersBySender;

  /// How many people voted, counted once each.
  final int voters;
}

/// Counts a poll's responses, counting each person once.
///
/// MSC3381 supersedes a sender's earlier response with their later one, so a
/// user who changes their mind sends a second response and the first must stop
/// counting. Adding up the raw response events instead made one person who
/// voted twice contribute two votes, which inflated the total and filled a bar
/// that nobody else had voted for.
///
/// [responses] arrives newest first, because that is the order a timeline
/// hands them over, so the walk is reversed to let the newest write win.
PollTally tallyPollResponses(List<PollResponse> responses) {
  final latest = <String, List<String>>{};
  for (final r in responses.reversed) {
    latest[r.sender] = r.answers;
  }
  final counts = <String, int>{};
  final answersBySender = <String, Set<String>>{};
  for (final entry in latest.entries) {
    for (final id in entry.value) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    answersBySender[entry.key] = entry.value.toSet();
  }
  return PollTally(
    counts: counts,
    answersBySender: answersBySender,
    voters: latest.length,
  );
}

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
    final tally = tallyPollResponses(
      events
          .where((e) => _isPollResponseFor(e, widget.event.eventId))
          .map(
            (e) => (
              sender: e.senderId,
              answers: _answersInResponse(e.content['m.poll.response']),
            ),
          )
          .toList(),
    );
    final userVoteIds =
        tally.answersBySender[widget.room.client.userID] ?? const <String>{};

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
    final answersCast = answers.map((m) => m.cast<String, dynamic>()).toList();
    final ended =
        (poll['end_time'] is int) || (widget.event.content['end_time'] is int);

    return _PollState(
      question: question,
      answers: answersCast,
      voteCounts: tally.counts,
      userVoteIds: userVoteIds,
      ended: ended,
      totalVotes: tally.voters,
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
    final l10n = AppLocalizations.of(context)!;
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
      if (!mounted) return;
      setState(() => _state = _load());
    } catch (_) {
      // Surfaced rather than swallowed. This used to be an empty catch, which
      // made a failed vote indistinguishable from a vote that landed: the user
      // tapped an option, nothing changed, and nothing said why. A tap on a
      // poll is the whole interaction, so a silent failure is the user being
      // told, quietly, that the app ignored them.
      if (!mounted) return;
      context.showMessage(l10n.pollVoteFailed);
    }
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
        return _buildCard(context, state, cs, l10n);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    _PollState state,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;

    return AttachmentCard(
      maxWidth: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Header -------------------------------------------------
          Row(
            children: [
              AttachmentLeadingIcon(
                // No size override, for the same reason the video row's is
                // gone: three attachment types were drawing three different
                // squares down one timeline.
                icon: LucideIcons.listChecks,
              ),
              SizedBox(width: t.spaceSm),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: t.spaceXs,
                    vertical: t.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: t.opacityDragged),
                    borderRadius: BorderRadius.circular(t.radiusXs),
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
          SizedBox(height: t.spaceMd),

          // -- Options -----------------------------------------------
          ...state.answers.map((a) {
            final id = a['id']?.toString() ?? '';
            final text = a['body']?.toString() ?? '';
            final count = state.voteCounts[id] ?? 0;
            final voted = state.userVoteIds.contains(id);
            final percent = pollBarShare(count, state.totalVotes);

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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      width: 220,
      height: 80,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(t.radiusLg),
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      width: 220,
      height: 80,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(t.radiusLg),
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: Stack(
        children: [
          // -- Fill bar ---------------------------------------------
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      voted ? cs.primary : cs.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
              ),
            ),
          ),
          // -- Content ----------------------------------------------
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
    required this.totalVotes,
  });

  factory _PollState.invalid() => _PollState(
        question: '',
        answers: const [],
        voteCounts: const {},
        userVoteIds: const {},
        ended: false,
        totalVotes: 0,
      );

  final String question;
  final List<Map<String, dynamic>> answers;
  final Map<String, int> voteCounts;
  final Set<String> userVoteIds;
  final bool ended;

  /// How many people voted, each counted once. Not the number of responses:
  /// re-voting sends a second response, and a poll that adds those up reports
  /// more voters than there are people.
  final int totalVotes;

  bool get valid => question.isNotEmpty && answers.isNotEmpty;
}
