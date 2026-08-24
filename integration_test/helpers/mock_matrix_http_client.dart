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
  MockMatrixHttpClient() {
    // matrix 9.0.0 made these endpoints hard requirements of the login
    // flow: `Client.checkHomeserver` fails non-retryably when
    // `/_matrix/client/versions` 404s, and the background sync refuses
    // to start until the sync filter is defined.  Register sane defaults
    // so tests don't have to repeat them; individual tests can still
    // override via [on].
    on(
      RegExp(r'_matrix/client/versions'),
      handler: (_) => _jsonResponse(200, {
            'versions': ['v1.1', 'v1.2', 'v1.3', 'v1.4', 'v1.5', 'v1.6', 'v1.7'],
          }),
    );
    on(
      RegExp(r'_matrix/client/v3/user/[^/]+/filter'),
      handler: (_) => _jsonResponse(200, {'filter_id': 'moonrelay_e2e_filter'}),
    );
    configureDeviceKeyHandlers();
  }

  // -- Route table --------------------------------------------------
  final Map<Pattern, http.Response Function(http.Request)> _handlers = {};

  /// Registers the device-key endpoints the SDK calls during login and
  /// after every sync.  In matrix 9.0.0 these are load-bearing:
  /// `OlmManager.init` throws "Upload key failed" when the keys upload
  /// response does not echo the number of signed one-time keys, and
  /// every sync tick fails inside `Client.updateUserDeviceKeys` (which
  /// re-arms the background sync loop immediately, burning CPU) when
  /// `/keys/query` 404s.
  void configureDeviceKeyHandlers() {
    final keysUploadRe = RegExp(r'_matrix/client/v3/keys/upload');
    registerRoute(keysUploadRe, (req) {
      int signedOtkCount = 0;
      try {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final oneTimeKeys = body['one_time_keys'];
        if (oneTimeKeys is Map) {
          signedOtkCount = oneTimeKeys.keys
              .where((k) => k.toString().startsWith('signed_curve25519:'))
              .length;
        }
      } catch (_) {
        // Non-JSON body; a zero count makes the SDK treat the upload as
        // successful (it compares the echo against the keys it sent).
      }
      return _jsonResponse(200, {
        // uploadKeys() returns `one_time_key_counts` to the caller, and
        // OlmManager compares its `signed_curve25519` entry against the
        // number of keys it sent.
        'one_time_key_counts': {'signed_curve25519': signedOtkCount},
      });
    });

    registerRoute(
      RegExp(r'_matrix/client/v3/keys/query'),
      (req) => _jsonResponse(200, {'device_keys': {}, 'failures': {}}),
    );
    registerRoute(
      RegExp(r'_matrix/client/v3/keys/claim'),
      (req) => _jsonResponse(200, {'one_time_keys': {}, 'failures': {}}),
    );
  }

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

  /// How many timeline events per room had been delivered at each batch
  /// token.  Used to make [buildSyncResponse] incremental (a real server
  /// only returns events newer than the client's `since` token), instead
  /// of re-sending the whole growing timeline on every tick, which made
  /// the sync loop O(n²) and progressively starved the frame pipeline in
  /// the sustained-sync regression test.
  final Map<String, Map<String, int>> _deliveredCounts = {};

  /// Build a Matrix sync response JSON map from the current room state.
  ///
  /// Pass [since] (the `since` query parameter the SDK sends) to deliver
  /// only events newer than that batch token, like a real homeserver.
  /// A null [since] (initial sync) delivers the full timeline.
  Map<String, dynamic> buildSyncResponse({String? since}) {
    _nextBatchCounter++;
    _baseBatchToken = 's$_nextBatchCounter';

    // Events already delivered by the batch the client is syncing from.
    final deliveredBefore = since == null
        ? <String, int>{}
        : (_deliveredCounts[since] ?? <String, int>{});

    final joinRooms = <String, dynamic>{};
    final newCounts = <String, int>{};
    for (final entry in _rooms.entries) {
      final room = entry.value;
      final timelineEvents = room.timelineEvents;
      final start = (deliveredBefore[entry.key] ?? 0).clamp(0, timelineEvents.length);
      final newEvents = timelineEvents.sublist(start);
      newCounts[entry.key] = timelineEvents.length;

      final timeline = newEvents.map((e) {
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

    _deliveredCounts[_baseBatchToken] = newCounts;

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

    // Cross-signing keys upload; accept whatever the SDK sends.
    final signingKeysRe = RegExp(
        r'_matrix/client/v3/keys/device_signing/upload|_matrix/client/v3/keys/signatures/upload');
    registerRoute(
        signingKeysRe, (req) => _jsonResponse(200, <String, dynamic>{}));

    // Device list: use whenDevicesRequested so tests can override.
    registerRoute(
      RegExp(r'_matrix/client/v3/devices$'),
      (req) => _jsonResponse(200, {'devices': whenDevicesRequested()}),
    );
  }

  // -- Message send / redact / typing fixtures -----------------------
  //
  // Handlers for the chat composer so integration tests can send and
  // redact messages through the real ChatBox widget.  Sent messages
  // are captured in [sentMessages] for test assertions.

  /// Installs handlers for sending messages and typing indicators.
  ///
  /// Call this from `setUp` or `configureLoginHandlers` so the ChatBox
  /// can actually send text (and the SDK does not get 404 errors on
  /// the typing PUT).
  void configureSendHandlers() {
    // Send: PUT /rooms/{roomId}/send/{eventType}/{txnId}
    registerRoute(
      RegExp(r'_matrix/client/v3/rooms/[^/]+/send/'),
      (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final eventId = '\$sent_${_randomId()}';
        _sentMessages.add(body);
        return _jsonResponse(200, <String, dynamic>{'event_id': eventId});
      },
    );

    // Typing: PUT /rooms/{roomId}/typing/{userId}
    registerRoute(
      RegExp(r'_matrix/client/v3/rooms/[^/]+/typing/'),
      (_) => _jsonResponse(200, <String, dynamic>{}),
    );

    // Redact: PUT /rooms/{roomId}/redact/{eventId}/{txnId}
    registerRoute(
      RegExp(r'_matrix/client/v3/rooms/[^/]+/redact/'),
      (_) => _jsonResponse(200, <String, dynamic>{'event_id': r'$redacted'}),
    );

    // Logout: POST /_matrix/client/v3/logout
    registerRoute(
      RegExp(r'_matrix/client/v3/logout$'),
      (_) => _jsonResponse(200, <String, dynamic>{}),
    );
  }

  /// Messages sent through the mock send handler, captured for test
  /// verification.  Reset between tests by creating a fresh mock.
  List<Map<String, dynamic>> get sentMessages =>
      List<Map<String, dynamic>>.unmodifiable(_sentMessages);
  final List<Map<String, dynamic>> _sentMessages = <Map<String, dynamic>>[];

  /// Public field: tests can rename this to a deterministic
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
