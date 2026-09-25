import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
// A API pública do analyzer não expõe os nomes das propriedades filhas;
// `namedChildEntities` (pares nome/valor) só existe na implementação interna.
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/ast.dart' show AstNodeImpl;

const schemaVersion = 1;

void main(List<String> args) {
  final paths = <String>[];
  String? outPath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-o') {
      if (++i >= args.length) _usage('falta valor para -o');
      outPath = args[i];
    } else if (arg.startsWith('-o=')) {
      outPath = arg.substring(3);
    } else if (arg == '-h' || arg == '--help') {
      _usage(null);
    } else {
      paths.add(arg);
    }
  }
  if (paths.isEmpty) _usage('nenhum arquivo informado');

  final files = paths.map(dumpFile).toList();
  final root = <String, Object?>{
    'schemaVersion': schemaVersion,
    'tool': 'dartast',
    'files': files,
  };
  final json = const JsonEncoder.withIndent('  ').convert(root);
  if (outPath != null) {
    File(outPath).writeAsStringSync('$json\n');
  } else {
    stdout.writeln(json);
  }
}

Never _usage(String? error) {
  if (error != null) stderr.writeln('erro: $error');
  stderr.writeln('uso: dart run bin/dartast.dart <arquivo.dart...> [-o out.json]');
  exit(error == null ? 0 : 2);
}

Map<String, Object?> dumpFile(String path) {
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
    'unit': dumpNode(result.unit),
  };
}

T? _safe<T>(T? Function() fn) {
  try {
    return fn();
  } catch (_) {
    return null;
  }
}

Object? dumpEntity(Object? value) {
  if (value is AstNode) return dumpNode(value);
  if (value is Token) {
    return <String, Object?>{
      'token': value.lexeme,
      'type': value.type.name,
    };
  }
  if (value is List) return value.map(dumpEntity).toList();
  return value?.toString();
}

Map<String, Object?> dumpNode(AstNode node) {
  var typeName = node.runtimeType.toString();
  if (typeName.endsWith('Impl')) {
    typeName = typeName.substring(0, typeName.length - 4);
  }
  final map = <String, Object?>{
    'node': typeName,
    'offset': node.offset,
    'length': node.length,
  };
  if (node is Expression) {
    map['staticType'] = _safe<String>(() => node.staticType?.toString());
  }
  if (node is SimpleIdentifier) {
    map['resolved'] = _safe<String>(() => node.element?.displayName);
  } else if (node is DeclaredIdentifier) {
    map['resolved'] =
        _safe<String>(() => node.declaredFragment?.element.displayName);
  }
  if (node is AstNodeImpl) {
    for (final entity in node.namedChildEntities) {
      map[entity.name] = dumpEntity(entity.value);
    }
  }
  return map;
}
