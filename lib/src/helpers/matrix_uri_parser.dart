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

  /// A single event inside a room, i.e. an event permalink.
  ///
  /// The app generates these (`copy link` on a message) but could not
  /// resolve them until now, so a permalink copied out of Moonrelay
  /// opened the room without focusing the message.
  event,
}

/// The result of successfully parsing a matrix URI.
class MatrixUriResult {
  const MatrixUriResult({
    required this.entityType,
    required this.entityId,
    this.viaServers = const [],
    this.displayAlias,
    this.roomId,
  });

  /// What kind of entity this URI points to.
  final MatrixUriEntity entityType;

  /// The raw Matrix identifier: a room ID (`!...`), user ID (`@...`),
  /// alias (`#...`), or, for an event permalink, the event ID
  /// (`$...`).
  final String entityId;

  /// Optional "via" servers to use when joining or peeking.
  final List<String> viaServers;

  /// Optional display alias from `matrix.to` URLs (e.g. `#alias:domain`).
  final String? displayAlias;

  /// The room an [MatrixUriEntity.event] permalink points into.  Null
  /// for every other entity type, where [entityId] is the room itself.
  final String? roomId;

  /// True if this references a room (either by ID or alias).
  bool get isRoom =>
      entityType == MatrixUriEntity.room ||
      entityType == MatrixUriEntity.roomAlias;

  /// The room this URI addresses, whether it is a room permalink or an
  /// event permalink.  Null for user and alias entities.
  String? get targetRoomId => entityType == MatrixUriEntity.event
      ? roomId
      : (isRoom ? entityId : null);

  /// The identifier to use when joining the room (alias preferred).
  String get joinId => displayAlias ?? entityId;
}

/// Parses Matrix URIs from text, supporting both the standard `matrix:` URI
/// scheme and `https://matrix.to/#/` permalink URLs.
///
/// ## Supported formats
///
/// matrix:// / matrix: scheme:
/// - `matrix:r/!roomid:domain?via=example.org`
/// - `matrix:u/@user:domain`
/// - `matrix:roomid/!roomid:domain`
///
/// matrix.to permalink:
/// - `https://matrix.to/#/!roomid:domain?via=example.org`
/// - `https://matrix.to/#/@user:domain`
/// - `https://matrix.to/#/#alias:domain`
/// - `https://matrix.to/#/!roomid:domain/$eventid` (event permalink)
///
/// matrix: scheme, per the URI spec:
/// - `matrix:roomid/!roomid:domain/$eventid` (event permalink)
class MatrixUriParser {
  MatrixUriParser._();

  /// Combined pattern for detecting any matrix URL or bare Matrix ID in text.
  ///
  /// Bare IDs are restricted to `@…:…` and `#…:…` (user / room alias) and
  /// require the local part to start with a word character, not whitespace
  /// or punctuation.  The trailing `(?<![.,;!?)])` lookbehind rejects
  /// sentence punctuation glued to the identifier, which used to make
  /// `Visit matrix.org!` detect `matrix.org` as a Matrix ID.  Bare room
  /// IDs (`!…:…`) are intentionally excluded from the *scan*; they're
  /// 26-character random strings that look identical to noise in normal
  /// prose, so an explicit `matrix:r/!…` URI is the only safe way to
  /// reference a bare room ID.
  static final RegExp detectPattern = RegExp(
    r'(?:matrix:(?:\/\/)?(?:r|u|roomid)\/[^\s<>")()]+'
    r'|https:\/\/matrix\.to\/#\/[^\s<>")()]+'
    r'|(?<![a-zA-Z0-9])([@#][^\s<>")()]+:[^\s<>")()]+)(?<![.,;!?)]))',
    caseSensitive: false,
  );

  /// Scans [text] for all matrix URIs and returns a parsed result for each
  /// one found.  Returns an empty list if none are found.
  ///
  /// Multiple URIs that resolve to the same entity (e.g. a bare user mention
  /// and a `matrix.to` permalink for the same user) produce a single result.
  static List<MatrixUriResult> parseAll(String text) {
    final results = <MatrixUriResult>[];
    final seen = <String>{};

    for (final match in detectPattern.allMatches(text)) {
      final uri = match.group(0)!;
      if (seen.contains(uri)) continue;
      seen.add(uri);

      final parsed = parse(uri);
      if (parsed != null) {
        // Deduplicate by canonical entity identity so that a bare user
        // mention (`@user:domain`) and a `matrix.to` permalink to the
        // same user don't produce separate banners.
        final key = '${parsed.entityType}|${parsed.entityId}';
        if (seen.contains(key)) continue;
        seen.add(key);

        results.add(parsed);
      }
    }

    return results;
  }

  /// Tries to parse a single matrix URI string.  Returns `null` if the
  /// string is not a recognised matrix URI format.
  ///
  /// Malformed input (e.g. a broken percent-escape in a `matrix.to`
  /// permalink sent by another user) is treated as "no match" rather
  /// than throwing, so message rendering and deep-link handling never
  /// crash on hostile or corrupt server data.
  static MatrixUriResult? parse(String uri) {
    try {
      return _parse(uri);
    } on FormatException {
      return null;
    } on ArgumentError {
      // `Uri.decodeComponent` raises ArgumentError, not FormatException,
      // for a broken escape such as a bare `%`.  A literal percent sign
      // is legal in a Matrix room id, so a hostile or corrupt
      // `matrix.to` link in a message body would otherwise throw out of
      // the parser and take the message renderer with it.  This runs on
      // every message that contains a matrix-looking string, so it has to
      // degrade to "no match" rather than propagate.
      return null;
    }
  }

  static MatrixUriResult? _parse(String uri) {
    final lower = uri.toLowerCase();
    if (lower.startsWith('matrix:')) {
      return _parseMatrixScheme(uri);
    }
    if (lower.startsWith('https://matrix.to/')) {
      return _parseMatrixTo(uri);
    }
    final firstChar = uri.isNotEmpty ? uri[0] : '';
    // Note: `!` is allowed here so direct deep links like
    // `!abcdef:matrix.org` resolve as rooms, but `detectPattern`
    // deliberately excludes bare `!` IDs from the *scan* path
    // (see the comment there for rationale).
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
    if (stripped.startsWith('r/')) {
      return _roomResult(stripped.substring(2), viaServers: []);
    } else if (stripped.startsWith('u/')) {
      final id = stripped.substring(2);
      if (!id.startsWith('@')) return null;
      return MatrixUriResult(
        entityType: MatrixUriEntity.user,
        entityId: id,
      );
    } else if (stripped.startsWith('roomid/')) {
      return _roomResult(
        stripped.substring('roomid/'.length),
        viaServers: <String>[],
      );
    }
    return null;
  }

  /// Parses the `!room:domain` / `!room:domain/$event` tail shared by
  /// the `matrix:r/` and `matrix:roomid/` forms.
  static MatrixUriResult? _roomResult(
    String rest, {
    required List<String> viaServers,
  }) {
    var body = rest;

    // Extract query parameters (via servers).
    final queryIdx = body.indexOf('?');
    if (queryIdx >= 0) {
      final query = body.substring(queryIdx + 1);
      body = body.substring(0, queryIdx);
      final params = Uri.parse('?$query').queryParametersAll;
      final vias = params['via'];
      if (vias != null && vias.isNotEmpty) {
        viaServers = vias;
      }
    }

    if (!body.startsWith('!')) return null;

    // `!room:domain/$eventid` is an event permalink.
    final slashIdx = body.indexOf('/');
    if (slashIdx >= 0) {
      final roomId = body.substring(0, slashIdx);
      final eventId = body.substring(slashIdx + 1);
      if (!roomId.startsWith('!') || !eventId.startsWith(r'$')) return null;
      return MatrixUriResult(
        entityType: MatrixUriEntity.event,
        entityId: eventId,
        roomId: roomId,
        viaServers: viaServers,
      );
    }

    return MatrixUriResult(
      entityType: MatrixUriEntity.room,
      entityId: body,
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
    String? displayAlias;

    // `!room:domain/$eventid` is an event permalink.  Split before the
    // entity-type switch so an event id (which starts with `$`) is not
    // mistaken for something else.
    final slashIdx = fragment.indexOf('/');
    if (slashIdx >= 0) {
      final roomPart = fragment.substring(0, slashIdx);
      final eventPart = fragment.substring(slashIdx + 1);
      if (!roomPart.startsWith('!') || !eventPart.startsWith(r'$')) {
        return null;
      }
      return MatrixUriResult(
        entityType: MatrixUriEntity.event,
        entityId: eventPart,
        roomId: roomPart,
        viaServers: viaServers,
      );
    }

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

  /// Parses a bare Matrix identifier (room ID, user ID, or room alias).
  ///
  /// Supported formats:
  /// - `!roomid:domain`: room ID (allowed for direct lookups)
  /// - `@user:domain`: user ID
  /// - `#alias:domain`: room alias
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

  /// Builds an `https://matrix.to/#/!room/$event` permalink for a single
  /// event.  Round-trips through [parse] back to
  /// [MatrixUriEntity.event].
  static String buildEventPermalink(
    String roomId,
    String eventId, {
    List<String>? via,
  }) {
    final buffer = StringBuffer('https://matrix.to/#/$roomId/$eventId');
    if (via != null && via.isNotEmpty) {
      buffer.write('?via=${via.join(',')}');
    }
    return buffer.toString();
  }
}
