/// AST de arquivos Dart (`package:analyzer`) como JSON normalizado.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
// A API pública do analyzer não expõe os nomes das propriedades filhas;
// `namedChildEntities` (pares nome/valor) só existe na implementação interna.
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/ast.dart' show AstNodeImpl;

/// Versão do formato do JSON (vai em todo dump).
const schemaVersion = 1;

/// Converte a AST do analyzer em mapas JSON: cada nó tem `node`, `offset`,
/// `length` (e `staticType`/`resolved` quando houver) e os filhos pelos
/// nomes das propriedades do analyzer.
class AstDumper {
  const AstDumper();

  /// Documento raiz com o dump de cada arquivo, na ordem dada.
  Map<String, Object?> document(List<String> paths) => <String, Object?>{
    'schemaVersion': schemaVersion,
    'tool': 'dartast',
    'files': paths.map(file).toList(),
  };

  /// Um arquivo: caminho, erros de sintaxe e a CompilationUnit.
  Map<String, Object?> file(String path) {
    final content = File(path).readAsStringSync();
    final result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
      path: path,
      throwIfDiagnostics: false,
    );
    return <String, Object?>{
      'path': path,
      'errors': [
        for (final e in result.errors)
          <String, Object?>{
            'message': e.message,
            'offset': e.offset,
            'line': result.lineInfo.getLocation(e.offset).lineNumber,
            'column': result.lineInfo.getLocation(e.offset).columnNumber,
          },
      ],
      'unit': node(result.unit),
    };
  }

  /// Um nó da AST com os filhos.
  Map<String, Object?> node(AstNode n) {
    var typeName = n.runtimeType.toString();
    if (typeName.endsWith('Impl')) {
      typeName = typeName.substring(0, typeName.length - 4);
    }
    final map = <String, Object?>{
      'node': typeName,
      'offset': n.offset,
      'length': n.length,
    };
    if (n is Expression) {
      map['staticType'] = _safe<String>(() => n.staticType?.toString());
    }
    if (n is SimpleIdentifier) {
      map['resolved'] = _safe<String>(() => n.element?.displayName);
    } else if (n is DeclaredIdentifier) {
      map['resolved'] = _safe<String>(
        () => n.declaredFragment?.element.displayName,
      );
    }
    if (n is AstNodeImpl) {
      for (final child in n.namedChildEntities) {
        map[child.name] = entity(child.value);
      }
    }
    return map;
  }

  /// Um filho: nó, token (lexema e tipo), lista ou valor como texto.
  Object? entity(Object? value) {
    if (value is AstNode) return node(value);
    if (value is Token) {
      return <String, Object?>{'token': value.lexeme, 'type': value.type.name};
    }
    if (value is List) return value.map(entity).toList();
    return value?.toString();
  }
}

T? _safe<T>(T? Function() fn) {
  try {
    return fn();
  } catch (_) {
    return null;
  }
}
