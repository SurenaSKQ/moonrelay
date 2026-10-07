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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every authenticated-media load must carry the account's bearer token.
///
/// Matrix serves avatars, room images, and file thumbnails over
/// authenticated HTTP. A homeserver that does not also serve its own media
/// anonymously answers `401` to an unauthenticated request, so an image
/// loaded without the token is not a broken image icon: it is a *silent*
/// fallback to whatever the widget shows when the load fails. In a client
/// whose avatars fall back to a letter, that failure is invisible in the
/// widget tree and in any widget test, because a `NetworkImage` with no
/// token looks exactly like one with a token right up until the server
/// answers.
///
/// This is therefore a source invariant rather than a behavioural test.
/// It is deliberately crude: any file that loads an image directly must also
/// mention an authorization header somewhere, and the shared
/// `AvatarFromUriOrFallbackImage` is the thing to reach for instead. That
/// catches the regression the spaces rail shipped for one release, where a
/// bare `Image.network` replaced a call that had always passed the token and
/// every space in the sidebar quietly became its initial.
void main() {
  final roots = <String>['lib/src/widgets', 'lib/src/screens', 'lib/src/chat'];

  List<File> dartFilesIn(String root) {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  test('no widget loads Matrix media without a bearer token', () {
    final offenders = <String>[];

    for (final root in roots) {
      for (final file in dartFilesIn(root)) {
        final source = file.readAsStringSync();
        final loadsImage = source.contains('Image.network(') ||
            source.contains('NetworkImage(');
        if (!loadsImage) continue;

        // `AvatarFromUriOrFallbackImage` is the sanctioned path and it
        // carries the header itself; `authHeaders` is the sanctioned way to
        // attach one to an image load that has its own shape to fit.
        final carriesHeader = source.contains('authHeaders(') ||
            source.contains('Bearer') ||
            source.contains('authorization') ||
            source.contains('AvatarFromUriOrFallbackImage');

        if (!carriesHeader) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These files load Matrix media with no Authorization header, so '
          'every avatar and thumbnail they show falls back to a placeholder '
          'on any homeserver that does not serve its own media publicly. Use '
          'AvatarFromUriOrFallbackImage, or pass '
          "{'authorization': 'Bearer \${client.accessToken}'}.\n"
          '${offenders.join('\n')}',
    );
  });

  test('the shared avatar widget is the one carrying the header', () {
    // The guard above is satisfied by a file that merely mentions the header,
    // so pin the actual mechanism too. If this ever stops holding, the test
    // above is checking a string rather than a behaviour.
    final source = File('lib/src/widgets/avatar_from_uri.dart').readAsStringSync();
    expect(
      source.contains("'authorization': 'Bearer \${client.accessToken}'"),
      isTrue,
      reason: 'AvatarFromUriOrFallbackImage stopped sending the bearer token, '
          'so every avatar in the app now depends on the homeserver serving '
          'media anonymously.',
    );
  });
}