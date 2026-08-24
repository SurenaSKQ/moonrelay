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

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';

/// An avatar that loads from a Matrix content URI with a themed placeholder
/// while the thumbnail URL resolves and the image downloads.
///
/// When [avatarUri] is `null` a generic person icon is shown instead.
///
/// ## Performance
///
/// The thumbnail-resolved URI is cached per `(client, uri, size)` triple
/// behind a [ValueNotifier].  Multiple widgets asking for the same avatar
/// all listen to the same notifier, so a single network roundtrip drives
/// every rebuild.  The widget itself uses [ListenableBuilder] (not
/// [FutureBuilder]) so a parent rebuild does not re-subscribe to a fresh
/// Future and re-instantiate the [NetworkImage] -- the resolved image URL
/// is the only thing that changes once the cache is warm.
class AvatarFromUriOrFallbackImage extends StatelessWidget {
  const AvatarFromUriOrFallbackImage({
    super.key,
    required this.client,
    this.avatarUri,
    this.onTap,
    this.radius,
  });

  final Client client;
  final Uri? avatarUri;
  final VoidCallback? onTap;
  final double? radius;

  // -- Memoization ---------------------------------------------------------
  // Each (client, uri, size) triple resolves to a single ValueNotifier
  // whose value transitions `null -> Uri` once the SDK returns. The
  // underlying Future is shared across concurrent subscribers.
  static final Map<String, _LruCache<_AvatarKey, _AvatarResolver>> _resolvers =
      <String, _LruCache<_AvatarKey, _AvatarResolver>>{};

  /// Bounded per-client LRU for active avatar resolvers.
  /// The cap is small because the only call site uses a single (uri, size)
  /// per avatar and the avatar surface is finite.
  static const int _maxEntries = 512;

  static _AvatarResolver _getResolver(Client client, Uri uri, int size) {
    final cache = _resolvers.putIfAbsent(
      _clientKey(client),
      () => _LruCache<_AvatarKey, _AvatarResolver>(_maxEntries),
    );
    final key = _AvatarKey(uri, size);
    return cache.getOrCompute(
      key,
      () => _AvatarResolver(client, uri, size),
    );
  }

  /// Builds a stable per-client key. Uses `userID` when available so a
  /// future re-login of the same account reuses the cache and so two
  /// distinct accounts never collide on the runtime hash.
  static String _clientKey(Client client) {
    final id = client.userID;
    if (id != null && id.isNotEmpty) return id;
    return 'anon:${identityHashCode(client)}';
  }

  /// Drops cached thumbnails for the given [client]. Call on logout /
  /// client disposal.
  static void clearCacheFor(Client client) {
    _resolvers.remove(_clientKey(client));
  }

  /// Drops every cached thumbnail. Useful from the settings "clear caches"
  /// affordance and from tests.
  static void clearAll() {
    _resolvers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySize = ((radius ?? 20) * 2).round();
    final uri = avatarUri;

    if (uri == null) {
      return GestureDetector(onTap: onTap, child: _placeholder(theme));
    }

    final resolver = _getResolver(client, uri, displaySize);
    return GestureDetector(
      onTap: onTap,
      child: ListenableBuilder(
        listenable: resolver,
        builder: (context, _) {
          final resolved = resolver.value;
          if (resolved != null) {
            return _avatarWithErrorHandling(context, theme, resolved);
          }
          return _placeholder(theme);
        },
      ),
    );
  }

  /// Placeholder avatar shown when no URI is available or while loading.
  Widget _placeholder(ThemeData theme) => CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );

  /// Avatar with a network image that gracefully handles load failures
  /// (e.g. empty files returned by the server).
  Widget _avatarWithErrorHandling(
    BuildContext context,
    ThemeData theme,
    Uri resolvedUri,
  ) {
    final avatarRadius = radius ?? 20.0;

    return CircleAvatar(
      radius: avatarRadius,
      backgroundImage: NetworkImage(
        resolvedUri.toString(),
        headers: {
          'authorization': 'Bearer ${client.accessToken}',
        },
      ),
      backgroundColor: theme.colorScheme.primaryContainer,
      onBackgroundImageError: (_, __) {},
    );
  }
}

@immutable
class _AvatarKey {
  const _AvatarKey(this.uri, this.size);
  final Uri uri;
  final int size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AvatarKey && other.uri == uri && other.size == size;

  @override
  int get hashCode => Object.hash(uri, size);
}

/// Resolves a Matrix thumbnail URI exactly once and exposes the result
/// as a [ValueListenable].
///
/// The same [Uri] requested from many widget instances reuses the same
/// resolver, so a single network roundtrip drives every listener.
class _AvatarResolver extends ValueNotifier<Uri?> {
  _AvatarResolver(this._client, this._uri, this._size) : super(null) {
    _kickOff();
  }

  final Client _client;
  final Uri _uri;
  final int _size;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _kickOff() {
    // Kick off the async work eagerly.  Using an immediate async
    // invocation (rather than `Future(() async {...})`) avoids
    // scheduling a Timer on platforms where `Future(...)` would defer
    // to the timer queue; it also matches the original FutureBuilder
    // behaviour where the underlying Future was created synchronously.
    _runAsync();
  }

  Future<void> _runAsync() async {
    try {
      final resolved = await withTimeoutOrFallback(
        () => _uri.getThumbnailUri(
          _client,
          width: _size,
          height: _size,
        ),
        timeout: kDefaultTimeout,
        fallback: _uri,
      );
      if (!_disposed) value = resolved;
    } catch (_) {
      if (!_disposed) value = _uri;
    }
  }
}

/// Bounded LRU map used for the avatar-thumbnail memoization.
///
/// Uses [LinkedHashMap] for O(1) insertion-order tracking; previously
/// the implementation walked a parallel [List] on every eviction which
/// made rapid scrolling across many distinct senders visibly slower.
class _LruCache<K, V> {
  _LruCache(this._maxEntries);

  final int _maxEntries;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  V getOrCompute(K key, V Function() compute) {
    final existing = _map[key];
    if (existing != null) {
      // Reinsert to move the entry to the most-recently-used end.
      _map.remove(key);
      _map[key] = existing;
      return existing;
    }
    final value = compute();
    _map[key] = value;
    while (_map.length > _maxEntries) {
      _map.remove(_map.keys.first);
    }
    return value;
  }
}
