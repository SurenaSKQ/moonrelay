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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';
class KnockRequestsSection extends StatefulWidget {
  const KnockRequestsSection({
    super.key,required this.room});
  final Room room;

  @override
  State<KnockRequestsSection> createState() => KnockRequestsSectionState();
}

class KnockRequestsSectionState extends State<KnockRequestsSection> {
  List<User> _knockingUsers = const [];
  bool _knocksLoaded = false;

  /// Last [SyncPulse.version] observed at build time. The build re-runs
  /// the knock-list fetch whenever the pulse version advances; we
  /// compare against the previously observed value so a build caused by
  /// another field (locale, theme) doesn't trigger a redundant fetch.
  int _lastPulseVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadKnocks();
  }

  Future<void> _loadKnocks() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final matrixEvents =
          await widget.room.client.getMembersByRoom(widget.room.id);
      final members = matrixEvents
              ?.map((e) => Event.fromMatrixEvent(e, widget.room).asUser)
              .where((u) => u.membership == Membership.knock)
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _knockingUsers = members;
        _knocksLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _knocksLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _approve(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final name =
        widget.room.unsafeGetUserFromMemoryOrFallback(userId).calcDisplayname();

    // Confirmation dialog.  Showing display name + Matrix ID + a
    // "View profile" link gives the moderator enough context to be
    // confident the right person is being invited; knock requests
    // are easy to spoof with a similar-looking displayname.
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.knockApproveConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              userId,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.knockApproveConfirmBody),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.viewProfile),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.approve),
          ),
        ],
      ),
    );
    // "View profile" returns null; fall through to navigation so the
    // moderator can see who they're letting in.
    if (approved == null) {
      if (!mounted) return;
      openRoomSubpage(
        context,
        widget.room.id,
        'profile/${Uri.encodeComponent(userId)}',
      );
      return;
    }
    if (approved != true) return;

    try {
      await widget.room.invite(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.knockApproved(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }

  Future<void> _deny(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final name =
        widget.room.unsafeGetUserFromMemoryOrFallback(userId).calcDisplayname();
    try {
      await widget.room.kick(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.knockDenied(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    // Read the debounced sync pulse so we refresh the knock list on
    // every coalesced tick. The pulse provider is always in scope for
    // this screen (it's mounted inside the account-aware router), so a
    // missing pulse would indicate a wiring bug rather than a transient
    // state and we let the build continue without a refresh.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _lastPulseVersion) {
      _lastPulseVersion = pulseVersion;
      // Refresh asynchronously; the build phase must not await.
      _loadKnocks();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            l10n.pendingKnocks,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        if (!_knocksLoaded)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.spaceSm),
            child: SizedBox(
              height: t.spaceXl,
              width: t.spaceXl,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (_knockingUsers.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.spaceSm),
            child: Text(
              l10n.noPendingKnocks,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          )
        else
          ..._knockingUsers.map((user) {
            return Card(
              elevation: t.elevationNone,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
                side:
                    BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                title: Text(user.calcDisplayname()),
                subtitle: Text(user.id,
                    style: const TextStyle(
                        fontFamily: 'JetBrainsMono', fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: Icon(LucideIcons.x, size: t.iconSizeSmall),
                      label: Text(l10n.denyKnock),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                      ),
                      onPressed: () => _deny(user.id),
                    ),
                    SizedBox(width: t.spaceXs),
                    FilledButton.tonalIcon(
                      icon: Icon(LucideIcons.check, size: t.iconSizeSmall),
                      label: Text(l10n.approveKnock),
                      onPressed: () => _approve(user.id),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
