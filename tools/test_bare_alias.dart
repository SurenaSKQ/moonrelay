import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';

void main() {
  final body =
      "Please use the #cprogramming-ot:matrix.org room for topics like this.";
  final results = MatrixUriParser.parseAll(body);
  print('Results: ${results.length}');
  for (final r in results) {
    print('  type=${r.entityType} id=${r.entityId}');
  }

  // Also test the exact match
  final m = MatrixUriParser.detectPattern.allMatches(body);
  print('Regex matches: ${m.length}');
  for (final match in m) {
    print('  matched: "${match.group(0)}"');
  }

  // Test direct parse
  final r2 = MatrixUriParser.parse('#cprogramming-ot:matrix.org');
  print('Direct parse: ${r2?.entityType} ${r2?.entityId}');
}
