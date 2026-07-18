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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// A mock HTTP client that intercepts Matrix API calls for integration tests.
///
/// Routes requests by method + path pattern.  Holds mutable state for sync
/// tokens and room data so successive sync calls behave realistically.
class MockMatrixHttpClient extends http.BaseClient {
  // -- Route table --------------------------------------------------
  final Map<Pattern, http.Response Function(http.Request)> _handlers = {};

  /// Register a handler for requests whose [pathRegExp] matches the URL path.
  void on(
    Pattern pathRegExp, {
    required http.Response Function(http.Request) handler,
  }) {
    _handlers[pathRegExp] = handler;
  }

  // -- Sync state ---------------------------------------------------
  int _nextBatchCounter = 0;
  String _baseBatchToken = 's0';

  /// Return the current sync batch token.
  String get currentBatchToken => _baseBatchToken;

  /// Rooms known to sync responses, keyed by room ID.
  final Map<String, _MockRoomState> _rooms = {};

  /// Add a room to the sync state.
  void addRoom({
    required String id,
    required String name,
    required String topic,
    required List<Map<String, dynamic>> timelineEvents,
    List<Map<String, dynamic>>? stateEvents,
    int joinedMembers = 2,
  }) {
    _rooms[id] = _MockRoomState(
      name: name,
      topic: topic,
      timelineEvents: List.of(timelineEvents),
      stateEvents: stateEvents ?? <Map<String, dynamic>>[],
      joinedMembers: joinedMembers,
    );
  }

  /// Append an event to a room's timeline for the next sync response.
  void appendEvent(String roomId, Map<String, dynamic> event) {
    _rooms[roomId]?.timelineEvents.add(event);
  }

  // -- Request dispatch ---------------------------------------------

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    final method = request.method;
    final path = url.path;

    for (final entry in _handlers.entries) {
      if (_matches(entry.key, method, path, url)) {
        try {
          final response = entry
              .value(request is http.Request ? request : _toRequest(request));
          return http.StreamedResponse(
            Stream.value(utf8.encode(response.body)),
            response.statusCode,
            headers: {
              'content-type': 'application/json',
              ...response.headers,
            },
          );
        } catch (e) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(
                '{"errcode":"M_UNKNOWN","error":"Mock handler error: $e"}')),
            500,
            headers: {'content-type': 'application/json'},
          );
        }
      }
    }

    // Default: 404
    return http.StreamedResponse(
      Stream.value(utf8.encode(
          '{"errcode":"M_NOT_FOUND","error":"No mock handler for $method $path"}')),
      404,
      headers: {'content-type': 'application/json'},
    );
  }

  bool _matches(Pattern pattern, String method, String path, Uri url) {
    if (pattern is RegExp) {
      // Check full URL and path
      return pattern.hasMatch(path) || pattern.hasMatch(url.toString());
    }
    final str = pattern.toString();
    return path.contains(str) || url.toString().contains(str);
  }

  http.Request _toRequest(http.BaseRequest base) {
    final req = http.Request(base.method, base.url);
    req.headers.addAll(base.headers);
    if (base is http.StreamedRequest) {
      // Streamed requests aren't used by Matrix SDK, but handle gracefully
    }
    return req;
  }

  // -- Pre-built sync response --------------------------------------

  /// Build a Matrix sync response JSON map from the current room state.
  Map<String, dynamic> buildSyncResponse() {
    _nextBatchCounter++;
    _baseBatchToken = 's$_nextBatchCounter';

    final joinRooms = <String, dynamic>{};
    for (final entry in _rooms.entries) {
      final room = entry.value;
      final timeline = room.timelineEvents.map((e) {
        // Ensure required fields
        return {
          'type': 'm.room.message',
          'sender': '@user:matrix.org',
          'content': {'body': 'test', 'msgtype': 'm.text'},
          'event_id': '\$${_randomId()}',
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          ...e,
        };
      }).toList();

      joinRooms[entry.key] = {
        'timeline': {
          'events': timeline,
          'limited': false,
          'prev_batch': 'p$_nextBatchCounter',
        },
        'state': {
          'events': [
            {
              'type': 'm.room.name',
              'state_key': '',
              'content': {'name': room.name},
              'sender': '@user:matrix.org',
              'event_id': '\$_state_name_${entry.key}',
              'origin_server_ts': 1,
            },
            {
              'type': 'm.room.topic',
              'state_key': '',
              'content': {'topic': room.topic},
              'sender': '@user:matrix.org',
              'event_id': '\$_state_topic_${entry.key}',
              'origin_server_ts': 1,
            },
            {
              'type': 'm.room.join_rules',
              'state_key': '',
              'content': {'join_rule': 'public'},
              'sender': '@user:matrix.org',
              'event_id': '\$_state_join_${entry.key}',
              'origin_server_ts': 1,
            },
            ...room.stateEvents,
          ]
        },
        'unread_notifications': {},
        'summary': {
          'heroes': ['@user:matrix.org'],
          'mailed_members': room.joinedMembers,
          'invited_members': 0,
          'joined_members': room.joinedMembers,
        },
        'unread_thread_notifications': {},
      };
    }

    return {
      'next_batch': _baseBatchToken,
      'rooms': {
        'join': joinRooms,
        'invite': {},
        'leave': {},
      },
      'account_data': {'events': []},
      'presence': {'events': []},
      'device_lists': {'changed': [], 'left': []},
      'to_device': {'events': []},
      'device_one_time_keys_count': {},
      'org.matrix.msc2732.device_unused_fallback_key_types': [],
    };
  }

  String _randomId() {
    final r = Random();
    return '${r.nextInt(99999999)}${DateTime.now().microsecondsSinceEpoch}';
  }

  // -- Encryption fixtures -------------------------------------------
  //
  // Tests exercising the encryption flow (post-login bootstrap, the
  // devices screen, key backup, …) need a stable set of stubs for
  // the SDK's device-management and crypto endpoints.  The methods
  // below configure those handlers with plausible-looking responses
  // so the SDK's HTTP client can complete its requests without
  // 404 errors.

  /// Installs standard handlers for the cross-signing / key-backup / devices
  /// endpoints the SDK calls when [EncryptionService.init] fires.
  ///
  /// The defaults match an account that has not yet been bootstrapped:
  /// no master key, no self-signing key, no online backup.  Tests that
  /// want a different starting state can mutate the [whenDevicesRequested]
  /// hook or register extra routes before [buildTestApp] fires.
  void configureEncryptionHandlers() {
    // Devices for the current user.
    whenDevicesRequested = () => <Map<String, dynamic>>[
          {
            'device_id': currentDeviceId,
            'user_id': '@self:matrix.org',
            'display_name': 'Mock Test Device',
            'last_seen_ip': '127.0.0.1',
            'last_seen_ts': DateTime.now().millisecondsSinceEpoch,
            'app_id': 'moonrelay.e2e',
            'app_version': '0.6.0',
            'platform': 'linux',
            'url': null,
          }
        ];

    // Upload device keys (initial sync handshake).
    final keysUploadRe = RegExp(r'_matrix/client/v3/keys/upload');
    registerRoute(
        keysUploadRe, (req) => _jsonResponse(200, {'one_time_key_counts': {}}));

    // Cross-signing keys upload  accept whatever the SDK sends.
    final signingKeysRe = RegExp(
        r'_matrix/client/v3/keys/device_signing/upload|_matrix/client/v3/keys/signatures/upload');
    registerRoute(
        signingKeysRe, (req) => _jsonResponse(200, <String, dynamic>{}));

    // Device list  use whenDevicesRequested so tests can override.
    registerRoute(
      RegExp(r'_matrix/client/v3/devices$'),
      (req) => _jsonResponse(200, {'devices': whenDevicesRequested()}),
    );
  }

  /// Public field  tests can rename this to a deterministic
  /// `device_id` so login + sync responses stay referentially stable
  /// across runs.
  String currentDeviceId = 'E2ETEST-DEVICE';

  /// Hook installed by [configureEncryptionHandlers].  Returns the
  /// JSON list of devices for the `_matrix/client/v3/devices` call.
  List<Map<String, dynamic>> Function() whenDevicesRequested =
      () => <Map<String, dynamic>>[];

  /// Synonym for [on] with a more direct naming so E2E helpers
  /// can install additional routes alongside the encryption fixtures
  /// without leaking the internal mutable map.
  void registerRoute(Pattern p, http.Response Function(http.Request) h) {
    on(p, handler: h);
  }

  /// Convenience: a 200 JSON response with sensible default headers.
  http.Response _jsonResponse(int status, Object body) {
    return http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json',
    });
  }
}

/// Internal room state tracked by the mock client.
class _MockRoomState {
  _MockRoomState({
    required this.name,
    required this.topic,
    required this.timelineEvents,
    required this.stateEvents,
    required this.joinedMembers,
  });

  final String name;
  final String topic;
  final List<Map<String, dynamic>> timelineEvents;
  final List<Map<String, dynamic>> stateEvents;
  final int joinedMembers;
}
