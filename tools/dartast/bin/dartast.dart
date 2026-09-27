import 'dart:convert';
import 'dart:io';

import 'package:dartast/dartast.dart';

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

  final json = const JsonEncoder.withIndent('  ')
      .convert(const AstDumper().document(paths));
  if (outPath != null) {
    File(outPath).writeAsStringSync('$json\n');
  } else {
    stdout.writeln(json);
  }
}

Never _usage(String? error) {
  if (error != null) stderr.writeln('erro: $error');
  stderr.writeln(
    'uso: dart run bin/dartast.dart <arquivo.dart...> [-o out.json]',
  );
  exit(error == null ? 0 : 2);
}
