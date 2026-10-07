// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// Diagnostic benchmark: measures how long the matrix SDK spends in
// Client.updateUserDeviceKeys() when a sync tick marks a large device
// key set as outdated (the homeserver churn the user is seeing).
//
// Run: dart run tool/device_keys_bench.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dir = await Directory.systemTemp.createTemp('moonrelay_bench');
  final db = await databaseFactory.openDatabase(
    '${dir.path}/bench.db',
    options: OpenDatabaseOptions(version: 1),
  );
  final sdkDb = MatrixSdkDatabase.buildWithoutOpen(
    'bench',
    database: db,
    sqfliteFactory: databaseFactoryFfi,
  );
  await sdkDb.open();

  // A tiny fake homeserver: /keys/query returns a configurable number of
  // device keys for one user.
  final keyCount = 24000;
  final fakeHttp = _FakeHttpClient(keyCount: keyCount);

  // Seed a stored session so Client.init() restores userID/deviceID.
  await sdkDb.updateClient(
    'https://example.org',
    'token',
    null,
    null,
    '@user:example.org',
    'DEVICE1',
    'bench',
    null,
    null,
    null,
  );

  final client = Client('bench', database: sdkDb, httpClient: fakeHttp);
  await client.init();

  // Warm up (first call builds the tracked-user set).
  await client.updateUserDeviceKeys(additionalUsers: {'@user:example.org'});

  // Mark the list outdated, as device_lists.changed does after a sync.
  client.userDeviceKeys['@user:example.org']?.outdated = true;

  // Time just the DB transaction part by pre-storing the same keys.
  final tx = Stopwatch()..start();
  final dbActions = <Future<void> Function()>[];
  for (var i = 0; i < keyCount; i++) {
    final id = 'DEV$i';
    dbActions.add(
      () => sdkDb.storeUserDeviceKey(
        '@user:example.org',
        id,
        jsonEncode(<String, dynamic>{'keys': {'ed25519:$id': 'x'}}),
        true,
        false,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
  await sdkDb.transaction(() async {
    for (final f in dbActions) {
      await f();
    }
  });
  tx.stop();
  print('DB transaction only ($keyCount storeUserDeviceKey): '
      '${tx.elapsedMilliseconds}ms');

  final sw = Stopwatch()..start();
  await client.updateUserDeviceKeys();
  sw.stop();
  print('updateUserDeviceKeys with $keyCount device keys: '
      '${sw.elapsedMilliseconds}ms');

  await client.abortSync();
  await sdkDb.close();
  await db.close();
  await dir.delete(recursive: true);
  exit(0);
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({required this.keyCount});

  final int keyCount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/keys/query')) {
      final devices = <String, dynamic>{};
      for (var i = 0; i < keyCount; i++) {
        devices['DEV$i'] = {
          'user_id': '@user:example.org',
          'device_id': 'DEV$i',
          'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
          'keys': {
            'curve25519:DEV$i': _b64(32),
            'ed25519:DEV$i': _b64(32),
          },
          'signatures': {
            '@user:example.org': {'ed25519:DEV1': _b64(64)},
          },
          'unsigned': {'device_display_name': 'bench'},
        };
      }
      return _json(200, {
        'device_keys': {'@user:example.org': devices},
        'failures': <String, dynamic>{},
      });
    }
    if (path.endsWith('/sync')) {
      return _json(200, {'next_batch': 'b1'});
    }
    if (path.endsWith('/filter')) {
      return _json(200, {'filter_id': 'f1'});
    }
    if (path.endsWith('/versions')) {
      return _json(200, {'versions': ['v1.11']});
    }
    return _json(200, {});
  }

  String _b64(int n) => base64Encode(Uint8List(n));

  http.StreamedResponse _json(int status, Object body) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}
