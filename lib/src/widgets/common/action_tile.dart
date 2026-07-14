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

/// A tappable action tile with icon, label, optional description, and a
/// trailing chevron.  Used across settings pages for editing properties.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.color,
    required this.onTap,
    this.scheme,
  });

  final IconData icon;
  final String label;
  final String? description;
  final Color? color;
  final VoidCallback onTap;
  final ColorScheme? scheme;

  @override
  Widget build(BuildContext context) {
    final cs = scheme ?? Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, size: 22, color: effectiveColor),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: description != null
            ? Text(
                description!,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              )
            : null,
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: cs.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
