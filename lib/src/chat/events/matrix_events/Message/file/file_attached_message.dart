// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

class FileAttachedMessage extends StatelessWidget {
  const FileAttachedMessage({Key? key, required this.event}) : super(key: key);
  final Event event;

  // TODO: Multiple file download; split download utility; (future work) bind FFI to windows defender / ClamAV

  Future<String?> _downloadFile() async {
    if (event.hasAttachment) {
      MatrixFile attFile = await event.downloadAndDecryptAttachment();
      return await FilePicker.platform.saveFile(
          dialogTitle: 'Select download target',
          fileName: FileUtilities(event: event).getFileName(),
          bytes: attFile.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    FileUtilities fileInfo = FileUtilities(event: event);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 64, maxWidth: 96),
      child: Column(
        children: [
          SizedBox(
            height: 14,
            width: 16,
            child: Center(
                child: GestureDetector(
              onTap: () => _downloadFile(),
              child: const Icon(
                FluentIcons.download_document,
                size: 24,
              ),
            )),
          ),
          Row(
            children: [
              Center(
                child: Text(
                  "File: ${fileInfo.getFileName()} of Type: ${fileInfo.getFileMIMEType()} with extension: ${fileInfo.getFileExtention()}",
                  overflow: TextOverflow.fade,
                  maxLines: 2,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// FIXME - Make this an extentions on origin type
class FileUtilities {
  const FileUtilities({required this.event});
  final Event event;

  String? getFileMIMEType() => event.content['mimetype']?.toString();
  String? getFileExtention() =>
      event.content['filename']?.toString().split('.').last.toUpperCase();
  String? getFileName() => event.content['filename']?.toString();
}
