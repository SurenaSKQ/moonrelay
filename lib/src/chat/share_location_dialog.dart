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
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Opens a location-share dialog that sends the device's current location
/// as a Matrix `m.location` event.
///
/// The event content follows the spec at
/// <https://spec.matrix.org/v1.13/client-server-api/#mlocation>.
/// We omit the optional `info` block because some servers (Synapse)
/// reject float values in event content with `M_BAD_JSON`.  The
/// renderer falls back to the `geo_uri` field when `info` is absent.
Future<void> showShareLocationDialog(BuildContext context, Room room) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ShareLocationDialog(room: room),
  );
}

class _ShareLocationDialog extends StatefulWidget {
  const _ShareLocationDialog({required this.room});
  final Room room;

  @override
  State<_ShareLocationDialog> createState() => _ShareLocationDialogState();
}

class _ShareLocationDialogState extends State<_ShareLocationDialog> {
  bool _busy = false;

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationPermissionDenied)),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final lat = position.latitude;
      final lon = position.longitude;

      // Build the event content without an `info` block: some Matrix
      // servers (Synapse) reject float values in event content with
      // M_BAD_JSON.  Spec-wise the `info` block is optional; the
      // renderer falls back to the geo_uri when info is absent.
      final content = <String, dynamic>{
        'msgtype': 'm.location',
        'body': 'Location: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
        'geo_uri': 'geo:${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}',
      };

      // Room.sendEvent returns null when the SDK catches a fatal
      // MatrixException internally (M_BAD_JSON, M_FORBIDDEN, etc.).
      // Without this check the dialog would pop on failure and the
      // event would land in the timeline with error status.
      final eventId = await widget.room.sendEvent(content);
      if (eventId == null) {
        throw Exception(l10n.locationFailedToFetch);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.locationFailedToFetch)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(LucideIcons.mapPin, color: cs.primary),
      title: Text(l10n.shareLocation),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.map,
              size: 64,
              color: cs.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.sendCurrentLocation,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'geo: lat, lon',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontFamily: 'JetBrainsMono',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.send, size: 18),
          label: Text(l10n.sendCurrentLocation),
          onPressed: _busy ? null : _send,
        ),
      ],
    );
  }
}