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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

class JoinRuleTile extends StatelessWidget {
  const JoinRuleTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final IconData icon;
  final String title;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final selected = value == groupValue;

    return ListTile(
      leading: Icon(icon,
          size: t.iconSizeMedium, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: t.iconSizeMedium,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      onTap: enabled ? () => onChanged(value) : null,
      dense: true,
    );
  }
}
