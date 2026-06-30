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

/// The kind of entity a decoded matrix URI refers to.
enum MatrixUriEntity {
  /// A Matrix room (local or federated).
  room,

  /// A specific Matrix user.
  user,

  /// A room alias (e.g. `#alias:domain`).
  roomAlias,
}

/// The result of successfully parsing a matrix URI.
class MatrixUriResult {
  const MatrixUriResult({
    required this.entityType,
    required this.entityId,
    this.viaServers = const [],
    this.displayAlias,
  });

  /// What kind of entity this URI points to.
  final MatrixUriEntity entityType;

  /// The raw Matrix identifier: a room ID (`!...`), user ID (`@...`), or
  /// alias (`#...`).
  final String entityId;

  /// Optional "via" servers to use when joining or peeking.
  final List<String> viaServers;

  /// Optional display alias from `matrix.to` URLs (e.g. `#alias:domain`).
  final String? displayAlias;

  /// True if this references a room (either by ID or alias).
  bool get isRoom =>
      entityType == MatrixUriEntity.room ||
      entityType == MatrixUriEntity.roomAlias;

  /// The identifier to use when joining the room (alias preferred).
  String get joinId => displayAlias ?? entityId;
}

/// Parses Matrix URIs from text, supporting both the standard `matrix:` URI
/// scheme and `https://matrix.to/#/` permalink URLs.
///
/// ## Supported formats
///
/// **matrix:// / matrix: scheme**
/// - `matrix:r/!roomid:domain?via=example.org`
/// - `matrix:u/@user:domain`
/// - `matrix:roomid/!roomid:domain`
///
/// **matrix.to permalink**
/// - `https://matrix.to/#/!roomid:domain?via=example.org`
/// - `https://matrix.to/#/@user:domain`
/// - `https://matrix.to/#/#alias:domain`
class MatrixUriParser {
  MatrixUriParser._();

  /// Combined pattern for detecting any matrix URL or bare Matrix ID in text.
  static final RegExp detectPattern = RegExp(
    r'(?:matrix:(?:\/\/)?(?:r|u|roomid)\/[^\s<>")()]+'
    r'|https:\/\/matrix\.to\/#\/[^\s<>")()]+'
    r'|(?<![a-zA-Z0-9])([@!#][^\s<>")()]+:[^\s<>")()]+))',
    caseSensitive: false,
  );

  /// Scans [text] for all matrix URIs and returns a parsed result for each
  /// one found.  Returns an empty list if none are found.
  static List<MatrixUriResult> parseAll(String text) {
    final results = <MatrixUriResult>[];
    final seen = <String>{};

    for (final match in detectPattern.allMatches(text)) {
      final uri = match.group(0)!;
      if (seen.contains(uri)) continue;
      seen.add(uri);

      final parsed = parse(uri);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  /// Tries to parse a single matrix URI string.  Returns `null` if the
  /// string is not a recognised matrix URI format.
  static MatrixUriResult? parse(String uri) {
    final lower = uri.toLowerCase();
    if (lower.startsWith('matrix:')) {
      return _parseMatrixScheme(uri);
    }
    if (lower.startsWith('https://matrix.to/')) {
      return _parseMatrixTo(uri);
    }
    final firstChar = uri.isNotEmpty ? uri[0] : '';
    if (firstChar == '@' || firstChar == '!' || firstChar == '#') {
      return _parseBareId(uri);
    }
    return null;
  }

  /// Parses `matrix:` / `matrix://` URIs.
  static MatrixUriResult? _parseMatrixScheme(String uri) {
    // Strip the scheme prefix.
    var stripped = uri.startsWith('matrix://')
        ? uri.substring('matrix://'.length)
        : uri.substring('matrix:'.length);

    // Determine the type prefix.
    String? entityId;
    MatrixUriEntity? entityType;
    List<String> viaServers = [];

    if (stripped.startsWith('r/')) {
      entityId = stripped.substring(2);
      entityType = MatrixUriEntity.room;
    } else if (stripped.startsWith('u/')) {
      entityId = stripped.substring(2);
      entityType = MatrixUriEntity.user;
    } else if (stripped.startsWith('roomid/')) {
      entityId = stripped.substring('roomid/'.length);
      entityType = MatrixUriEntity.room;
    } else {
      return null;
    }

    // Extract query parameters (via servers).
    final queryIdx = entityId.indexOf('?');
    if (queryIdx >= 0) {
      final query = entityId.substring(queryIdx + 1);
      entityId = entityId.substring(0, queryIdx);
      final params = Uri.parse('?$query').queryParametersAll;
      final vias = params['via'];
      if (vias != null && vias.isNotEmpty) {
        viaServers = vias;
      }
    }

    // Ensure entityId starts with the expected prefix.
    if (entityType == MatrixUriEntity.room && !entityId.startsWith('!')) {
      return null;
    }
    if (entityType == MatrixUriEntity.user && !entityId.startsWith('@')) {
      return null;
    }

    return MatrixUriResult(
      entityType: entityType,
      entityId: entityId,
      viaServers: viaServers,
    );
  }

  /// Parses `https://matrix.to/#/...` permalinks.
  static MatrixUriResult? _parseMatrixTo(String uri) {
    // The fragment contains the entity after `#/`.
    final fragmentIdx = uri.indexOf('#/');
    if (fragmentIdx < 0) return null;

    var fragment = uri.substring(fragmentIdx + 2);

    // Extract query parameters (via servers).
    List<String> viaServers = [];
    String? displayAlias;
    final queryIdx = fragment.indexOf('?');
    if (queryIdx >= 0) {
      final query = fragment.substring(queryIdx + 1);
      fragment = fragment.substring(0, queryIdx);
      final params = Uri.parse('?$query').queryParametersAll;
      final vias = params['via'];
      if (vias != null && vias.isNotEmpty) {
        viaServers = vias;
      }
    }

    // URL-decode the fragment.
    fragment = Uri.decodeComponent(fragment);

    // Determine entity type from the leading character.
    MatrixUriEntity entityType;
    if (fragment.startsWith('!')) {
      entityType = MatrixUriEntity.room;
    } else if (fragment.startsWith('@')) {
      entityType = MatrixUriEntity.user;
    } else if (fragment.startsWith('#')) {
      entityType = MatrixUriEntity.roomAlias;
      // The fragment itself is an alias, so use it as displayAlias.
      displayAlias = fragment;
    } else {
      return null;
    }

    return MatrixUriResult(
      entityType: entityType,
      entityId: fragment,
      viaServers: viaServers,
      displayAlias: displayAlias,
    );
  }

  /// Parses a bare Matrix identifier (room ID, user ID, or room alias)
  /// found as plain text (not inside a matrix:// or matrix.to URL).
  ///
  /// Supported formats:
  /// - `!roomid:domain` — room ID
  /// - `@user:domain` — user ID
  /// - `#alias:domain` — room alias
  static MatrixUriResult? _parseBareId(String id) {
    // Strip common trailing punctuation that might be adjacent in text.
    id = id.replaceAll(RegExp(r'[.,;!?)\]}]+$'), '');

    if (id.length < 4) return null;

    final firstChar = id[0];
    late final MatrixUriEntity entityType;
    String? displayAlias;

    switch (firstChar) {
      case '@':
        entityType = MatrixUriEntity.user;
        break;
      case '!':
        entityType = MatrixUriEntity.room;
        break;
      case '#':
        entityType = MatrixUriEntity.roomAlias;
        displayAlias = id;
        break;
      default:
        return null;
    }

    // Must contain a colon with content on both sides.
    final colonIdx = id.indexOf(':');
    if (colonIdx < 2 || colonIdx >= id.length - 1) return null;

    return MatrixUriResult(
      entityType: entityType,
      entityId: id,
      displayAlias: displayAlias,
    );
  }

  /// Builds a canonical Matrix URI from a [roomId] (or alias) and optional
  /// [via] servers.
  ///
  /// Returns the URI as a string, e.g.:
  /// - `matrix:r/!roomid:domain?via=example.org`
  static String buildRoomUri(String roomId, {List<String>? via}) {
    final buffer = StringBuffer('matrix:r/$roomId');
    if (via != null && via.isNotEmpty) {
      buffer.write('?via=${via.join(',')}');
    }
    return buffer.toString();
  }

  /// Builds an `https://matrix.to/#/...` permalink for an entity.
  static String buildMatrixToPermalink(String entityId,
      {List<String>? via}) {
    final buffer = StringBuffer('https://matrix.to/#/$entityId');
    if (via != null && via.isNotEmpty) {
      buffer.write('?via=${via.join(',')}');
    }
    return buffer.toString();
  }
}
