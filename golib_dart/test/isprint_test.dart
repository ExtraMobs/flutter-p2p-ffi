import 'dart:convert';
import 'dart:io';

import 'package:golib_dart/src/unicode/isprint.dart';
import 'package:test/test.dart';

void main() {
  test('isprint.dart está em dia com o unicode.IsPrint do Go', () async {
    final go = await Process.run('go', [
      'run',
      'tool/gen_isprint.go',
    ], stdoutEncoding: utf8);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    final fmt = await Process.start('dart', ['format'], runInShell: true);
    fmt.stdin.add(utf8.encode(go.stdout as String));
    await fmt.stdin.close();
    final formatted = await fmt.stdout.transform(utf8.decoder).join();
    expect(await fmt.exitCode, 0);
    final file = File('lib/src/unicode/isprint.dart').readAsStringSync();
    expect(formatted.replaceAll('\r\n', '\n'), file.replaceAll('\r\n', '\n'));
  });

  test('casos conhecidos', () {
    expect(isPrint(0x41), isTrue); // A
    expect(isPrint(0x20), isTrue); // espaço ASCII
    expect(isPrint(0xa0), isFalse); // NBSP (Zs)
    expect(isPrint(0xad), isFalse); // soft hyphen (Cf)
    expect(isPrint(0xe9), isTrue); // é
    expect(isPrint(0x301), isTrue); // acento combinante (Mn)
    expect(isPrint(0x378), isFalse); // não atribuído
    expect(isPrint(0x1f600), isTrue); // emoji
    expect(isPrint(0xe000), isFalse); // uso privado
    expect(isPrint(0x2028), isFalse); // separador de linha
    expect(isPrint(0xfffd), isTrue);
  });
}
