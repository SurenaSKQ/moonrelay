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
import 'package:moonrelay/src/helpers/feedback.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

// -- Power levels editor -----------------------------------------------------

/// Opens the `m.room.power_levels` editor for [room] and writes it back.
///
/// Seven sliders over the default and per-action levels. The per-user
/// overrides in the `users` map are read and written back unchanged: the
/// dialog has never had a control for them, so a round trip through it
/// preserves them rather than dropping them, which is the only safe
/// behaviour for a field with no editor. Adding a per-user override editor
/// means writing that, not just re-saving the map.
Future<void> showPowerLevelsEditor(BuildContext context, Room room) async {
  final l10n = AppLocalizations.of(context)!;
  // Captured before any await so it can be used after the gap without
  // tripping the use_build_context_synchronously lint.
  final client = context.read<Client>();
  final state = _asStringMap(room.getState('m.room.power_levels')?.content);

  int read(String key, int fallback) {
    final v = state[key];
    return v is int ? v : fallback;
  }

  var usersDefault = read('users_default', 0);
  var evDefault = read('events_default', 0);
  var stDefault = read('state_default', 50);
  var banLvl = read('ban', 50);
  var kickLvl = read('kick', 50);
  var inviteLvl = read('invite', 50);
  var redactLvl = read('redact', 50);

  final userOverrides = <String, int>{};
  for (final entry in state.entries) {
    final value = entry.value;
    if (entry.key.startsWith('@') && value is int) {
      userOverrides[entry.key] = value;
    }
  }

  final updated = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l10n.powerLevelsSection),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LevelSlider(
                  label: l10n.powerLevelUsersDefault,
                  value: usersDefault,
                  onChanged: (v) => usersDefault = v,
                ),
                _LevelSlider(
                  label: l10n.powerLevelEventsDefault,
                  value: evDefault,
                  onChanged: (v) => evDefault = v,
                ),
                _LevelSlider(
                  label: l10n.powerLevelStateDefault,
                  value: stDefault,
                  onChanged: (v) => stDefault = v,
                ),
                _LevelSlider(
                  label: l10n.powerLevelBan,
                  value: banLvl,
                  onChanged: (v) => banLvl = v,
                ),
                _LevelSlider(
                  label: l10n.powerLevelKick,
                  value: kickLvl,
                  onChanged: (v) => kickLvl = v,
                ),
                _LevelSlider(
                  label: l10n.powerLevelInvite,
                  value: inviteLvl,
                  onChanged: (v) => inviteLvl = v,
                ),
                _LevelSlider(
                  label: l10n.powerLevelRedact,
                  value: redactLvl,
                  onChanged: (v) => redactLvl = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.editSave),
          ),
        ],
      ),
    ),
  );
  if (updated != true || !context.mounted) return;

  await context.showActionResult(
    action: () => client.setRoomStateWithKey(
      room.id,
      'm.room.power_levels',
      '',
      <String, dynamic>{
        'users_default': usersDefault,
        'events_default': evDefault,
        'state_default': stDefault,
        'ban': banLvl,
        'kick': kickLvl,
        'invite': inviteLvl,
        'redact': redactLvl,
        'users': userOverrides,
      },
    ),
    // No success message: a successful write redraws the room's permission
    // summary behind the dialog, so there is nothing to confirm.
    successMessage: null,
    formatError: (e) => l10n.actionFailed('$e'),
  );
}

/// One labelled power level with its numeric readout.
class _LevelSlider extends StatelessWidget {
  const _LevelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              '$value',
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ],
        ),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: value.toDouble(),
          onChanged: (n) => onChanged(n.toInt()),
        ),
      ],
    );
  }
}

/// Coerces a room state content map to `Map<String, dynamic>`.
Map<String, dynamic> _asStringMap(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  final out = <String, dynamic>{};
  raw.forEach((k, v) => out[k.toString()] = v);
  return out;
}
