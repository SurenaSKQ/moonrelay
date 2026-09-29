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

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:matrix/matrix.dart';

/// The largest file Moonrelay will read into memory to upload.
///
/// The Matrix SDK's [MatrixFile] is byte-backed, so a pick-and-read of a
/// several-gigabyte video allocates the whole thing on the UI isolate before
/// the first byte goes out. This is a guard rail, not a policy: it exists so
/// the common mistake (grabbing a 4K video recorded on a phone) fails
/// immediately with an explanation instead of taking the app down with it.
///
/// The number is generous on purpose. Most homeservers cap uploads well below
/// this, and a file that gets rejected by the server after a long upload is a
/// worse experience than one rejected up front.
const int kMaxUploadBytes = 512 * 1024 * 1024;

/// Raised by [readFileBytes] when the file is over [kMaxUploadBytes].
class UploadTooLargeException implements Exception {
  const UploadTooLargeException(this.name, this.bytes);

  final String name;
  final int bytes;

  @override
  String toString() =>
      '"$name" is ${_mib(bytes)} MB, over the '
      '${_mib(kMaxUploadBytes)} MB upload limit';
}

String _mib(int bytes) => '${(bytes / (1024 * 1024)).round()}';

/// Reads [file] into memory, refusing anything over [kMaxUploadBytes].
///
/// The size is checked from the picker's own metadata before the read, so
/// the check costs nothing and an oversized file never gets allocated.
///
/// Throws [UploadTooLargeException] rather than returning a sentinel, so a
/// caller cannot accidentally upload a truncated or empty result.
Future<Uint8List> readFileBytes(PlatformFile file) async {
  if (file.size > kMaxUploadBytes) {
    throw UploadTooLargeException(file.name, file.size);
  }
  return file.readAsBytes();
}
