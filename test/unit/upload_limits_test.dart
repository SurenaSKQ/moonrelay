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
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/upload_limits.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlatformFile extends Mock implements PlatformFile {}

void main() {
  group('readFileBytes', () {
    late _MockPlatformFile file;

    final payload = Uint8List.fromList([1, 2, 3]);

    setUp(() {
      file = _MockPlatformFile();
      when(() => file.name).thenReturn('clip.mp4');
      when(() => file.readAsBytes()).thenAnswer((_) async => payload);
    });

    test('reads a file under the limit', () async {
      when(() => file.size).thenReturn(1024);
      expect(await readFileBytes(file), [1, 2, 3]);
    });

    test('accepts a file exactly at the limit', () async {
      when(() => file.size).thenReturn(kMaxUploadBytes);
      expect(await readFileBytes(file), [1, 2, 3]);
    });

    // The regression this pins: the check has to run against the picker's
    // size metadata *before* the read, or the file is already on the heap
    // by the time anything notices.
    test('refuses an oversized file without reading it', () async {
      when(() => file.size).thenReturn(kMaxUploadBytes + 1);
      await expectLater(
        readFileBytes(file),
        throwsA(isA<UploadTooLargeException>()),
      );
      verifyNever(() => file.readAsBytes());
    });

    test('the exception names the file and both sizes', () {
      const e = UploadTooLargeException('clip.mp4', 700 * 1024 * 1024);
      final message = e.toString();
      expect(message, contains('clip.mp4'));
      expect(message, contains('700'));
      expect(message, contains('512'));
    });
  });
}
