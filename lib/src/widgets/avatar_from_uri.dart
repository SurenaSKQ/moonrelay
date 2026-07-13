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

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';

/// An avatar that loads from a Matrix content URI with a themed placeholder
/// while the thumbnail URL resolves and the image downloads.
///
/// When [avatarUri] is `null` a generic person icon is shown instead.
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

  // ── Memoization ─────────────────────────────────────────────────────────
  // Each (client, uri, size) triple resolves to a single Future<Uri>. The
  // cache is a true LRU bounded by entry count; previously it grew without
  // bound. Keyed by the client's `userID` (or the runtime hash as a last
  // resort) so a future re-login reuses entries and a GC'd client cannot
  // collide its hash with a freshly-allocated one.
  static final Map<String, _LruCache<String, Future<Uri>>> _thumbnailPromises =
      {};

  /// Bounded per-client LRU for in-flight + completed thumbnail promises.
  /// The cap is small because the only call site uses a single (uri, size)
  /// per avatar and the avatar surface is finite.
  static const int _maxEntries = 512;

  static Future<Uri> _getThumbnail(
    Client client,
    Uri uri,
    int displaySize,
  ) {
    final key = _clientKey(client);
    final cache = _thumbnailPromises.putIfAbsent(key, () {
      final c = _LruCache<String, Future<Uri>>(_maxEntries);
      return c;
    });
    final entry = '${uri.toString()}::$displaySize';
    return cache.getOrCompute(
      entry,
      () => withTimeoutOrFallback(
        () => uri.getThumbnailUri(
          client,
          width: displaySize,
          height: displaySize,
        ),
        timeout: kDefaultTimeout,
        fallback: uri,
      ),
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
    _thumbnailPromises.remove(_clientKey(client));
  }

  /// Drops every cached thumbnail. Useful from the settings "clear caches"
  /// affordance and from tests.
  static void clearAll() {
    _thumbnailPromises.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySize = ((radius ?? 20) * 2).round();

    return GestureDetector(
      onTap: onTap,
      child: avatarUri == null
          ? _placeholder(theme)
          : FutureBuilder<Uri>(
              future: _getThumbnail(client, avatarUri!, displaySize),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _avatarWithErrorHandling(
                    context,
                    theme,
                    snapshot.data.toString(),
                  );
                }
                // Themed placeholder while the thumbnail URL resolves.
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
    String imageUrl,
  ) {
    final avatarRadius = radius ?? 20.0;

    return CircleAvatar(
      radius: avatarRadius,
      backgroundImage: NetworkImage(
        imageUrl,
        headers: {
          'authorization': 'Bearer ${client.accessToken}',
        },
      ),
      backgroundColor: theme.colorScheme.primaryContainer,
      onBackgroundImageError: (_, __) {},
    );
  }
}

/// Bounded LRU map used for the avatar-thumbnail memoization. Insertion
/// order is tracked in [_lruOrder]; on a cache hit the entry is
/// promoted to MRU; on overflow the LRU entry is dropped.
class _LruCache<K, V> {
  _LruCache(this._maxEntries);

  final int _maxEntries;
  final Map<K, V> _map = {};
  final List<K> _lruOrder = [];

  V? get(K key) => _map[key];

  V getOrCompute(K key, V Function() compute) {
    final existing = _map[key];
    if (existing != null) {
      _touch(key);
      return existing;
    }
    final value = compute();
    _map[key] = value;
    _lruOrder.add(key);
    while (_lruOrder.length > _maxEntries) {
      final oldest = _lruOrder.removeAt(0);
      _map.remove(oldest);
    }
    return value;
  }

  void _touch(K key) {
    final idx = _lruOrder.indexOf(key);
    if (idx < 0) return;
    if (idx == _lruOrder.length - 1) return;
    _lruOrder.removeAt(idx);
    _lruOrder.add(key);
  }
}
