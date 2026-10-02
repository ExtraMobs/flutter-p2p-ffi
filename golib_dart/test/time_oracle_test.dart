// Confere que `time_vectors.dart` (os vetores que `time_test.dart` usa em
// toda plataforma) é a saída atual do oráculo Go 1.26.5. Com
// `G2D_UPDATE_GOLDEN=1`, regrava o arquivo.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'time_vectors.dart';

void main() {
  test('time_vectors.dart = saída de go run test/go_time_vectors.go', () async {
    final r = await Process.run(
      'go',
      ['run', 'test/go_time_vectors.go'],
      // `Local` do shim é o do Go com TZ=UTC.
      environment: {
        ...Platform.environment,
        'GOTOOLCHAIN': 'go1.26.5',
        'TZ': 'UTC',
      },
      stdoutEncoding: utf8,
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final out = (r.stdout as String).trim();
    if (Platform.environment['G2D_UPDATE_GOLDEN'] == '1') {
      File('test/time_vectors.dart').writeAsStringSync(
        '// GERADO por test/time_oracle_test.dart (G2D_UPDATE_GOLDEN=1) a partir\n'
        '// de `TZ=UTC GOTOOLCHAIN=go1.26.5 go run test/go_time_vectors.go`.\n'
        '// Não editar à mão.\n'
        "const timeVectorsJson = r'''$out''';\n",
      );
      return;
    }
    expect(jsonDecode(out), jsonDecode(timeVectorsJson));
  });
}
