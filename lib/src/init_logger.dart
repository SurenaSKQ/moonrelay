// Copyright (C) 2024 Surena Karimpour Ghannadi
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<Logger> initializeLog() async {
  try {
    Directory cache = await getApplicationCacheDirectory();
    Directory logDir =
        await Directory(join(cache.path, 'MoonrelayLogs')).create();
    return Logger(
      printer: PrettyPrinter(
        colors: (Platform.isMacOS ? false : true),
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        printEmojis: true,
        methodCount: 5,
      ),
      output: AdvancedFileOutput(
        path: logDir.path,
        encoding: utf8,
        maxFileSizeKB: 32768,
        maxDelay: const Duration(minutes: 2),
      ),
      filter: DevelopmentFilter(),
    );
  } catch (e) {
    debugPrint("Log initialization failed at ${StackTrace.current.toString()}");
    exit(-1);
  }
}
