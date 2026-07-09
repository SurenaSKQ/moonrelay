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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Opens a sticker picker that lets the user pick an image file and send
/// it as an `m.sticker` event.
///
/// Stickers in Matrix are events of type `m.sticker` with a `url` (MXC),
/// `body` (description), and optional `info` map containing dimensions,
/// mime type, and size.
Future<void> showStickerPicker(BuildContext context, Room room) async {
  // Use `pickFile` (singular) since we only need a single image; this
  // also avoids the deprecated `allowMultiple: false` form on
  // `pickFiles`.
  final result = await FilePicker.pickFile(
    type: FileType.image,
  );

  if (result == null) return;
  if (!context.mounted) return;

  final file = result;
  // Read bytes on demand via the new PlatformFile API. The legacy
  // `file.bytes` and `withData: true` parameters are deprecated in
  // file_picker 12.
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return;
  if (!context.mounted) return;

  final name = file.name;

  // Build the info map from the picked file.
  final info = <String, dynamic>{};
  if (file.size > 0) info['size'] = file.size;

  // Try to detect mime type from extension.
  final ext = name.split('.').last.toLowerCase();
  final mimeType = _mimeFromExtension(ext);
  if (mimeType != null) info['mimetype'] = mimeType;

  try {
    await withTimeout(
      () => room.sendEvent(
        {
          'body': name,
          'info': info,
        },
        type: EventTypes.Sticker,
      ),
      timeout: kUploadTimeout,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context)!.error}: '
          '${e is TimeoutException ? AppLocalizations.of(context)!.uploadTimedOut : '$e'}',
        ),
      ),
    );
  }
}

/// Maps common image extensions to their MIME types.
String? _mimeFromExtension(String ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'svg':
      return 'image/svg+xml';
    default:
      return null;
  }
}
