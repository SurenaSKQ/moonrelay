import 'dart:developer' as developer;

import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';

void main() {
  final body =
      'Please use the #cprogramming-ot:matrix.org room for topics like this.';
  final results = MatrixUriParser.parseAll(body);
  developer.log('Results: ${results.length}', name: 'matrix_uri_parser');
  for (final r in results) {
    developer.log(
      '  type=${r.entityType} id=${r.entityId}',
      name: 'matrix_uri_parser',
    );
  }

  // Also test the exact match
  final m = MatrixUriParser.detectPattern.allMatches(body);
  developer.log('Regex matches: ${m.length}', name: 'matrix_uri_parser');
  for (final match in m) {
    developer.log(
      '  matched: "${match.group(0)}"',
      name: 'matrix_uri_parser',
    );
  }

  // Test direct parse
  final r2 = MatrixUriParser.parse('#cprogramming-ot:matrix.org');
  developer.log(
    'Direct parse: ${r2?.entityType} ${r2?.entityId}',
    name: 'matrix_uri_parser',
  );
}
