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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final color = ok ? Colors.green : scheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.opacityFocus),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: color.withValues(alpha: t.opacityDisabled)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? LucideIcons.checkCircle : LucideIcons.alertCircle,
              size: 12, color: color),
          SizedBox(width: t.spaceXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        SizedBox(width: t.spaceSm),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class BulletRow extends StatelessWidget {
  const BulletRow({
    super.key,
    required this.icon,
    required this.scheme,
    required this.text,
  });

  final IconData icon;
  final ColorScheme scheme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class FingerprintRow extends StatelessWidget {
  const FingerprintRow({
    super.key,
    required this.scheme,
    required this.label,
    required this.fingerprint,
  });

  final ColorScheme scheme;
  final String label;
  final String? fingerprint;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    if (fingerprint == null || fingerprint!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: t.spaceXs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: SelectableText(
              fingerprint!,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({
    super.key,
    required this.scheme,
    required this.label,
    required this.value,
  });

  final ColorScheme scheme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 26), // align with icon width in _StatusRow
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
