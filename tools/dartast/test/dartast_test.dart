import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Map<String, Object?> root;

  setUpAll(() async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'bin/dartast.dart',
      '../../tests/golden/hello/hello.dart',
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    root = jsonDecode(result.stdout as String) as Map<String, Object?>;
  });

  test('JSON válido com schemaVersion 1', () {
    expect(root['schemaVersion'], 1);
    expect(root['tool'], 'dartast');
  });

  test('fixture sem erros de sintaxe', () {
    final files = root['files']! as List;
    expect(files, hasLength(1));
    final file = files.single as Map<String, Object?>;
    expect(file['path'], '../../tests/golden/hello/hello.dart');
    expect(file['errors'], isEmpty);
  });

  test('nós esperados presentes na AST', () {
    final unit = (root['files']! as List).single as Map<String, Object?>;
    final declNames = <String>{};
    final counts = <String, int>{};
    final identifierTokens = <String>{};
    void walk(Object? node) {
      if (node is Map) {
        final type = node['node'];
        if (type is String) {
          counts[type] = (counts[type] ?? 0) + 1;
          final name = node['name'];
          if (name is Map && name['token'] is String) {
            declNames.add('$type:${name['token']}');
          }
        }
        if (node['type'] == 'IDENTIFIER' && node['token'] is String) {
          identifierTokens.add(node['token'] as String);
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    walk(unit['unit']);

    // No analyzer 14 o nome de ClassDeclaration fica aninhado em `namePart`.
    expect(counts['ClassDeclaration'], greaterThanOrEqualTo(1));
    expect(identifierTokens, contains('Greeter'));
    expect(declNames, contains('MethodDeclaration:greet'));
    expect(declNames, contains('FunctionDeclaration:_add'));
    expect(declNames, contains('FunctionDeclaration:main'));
  });
}
