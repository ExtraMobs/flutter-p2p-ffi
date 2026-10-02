part of '../../time.dart';

const _lowerhex = '0123456789abcdef';

/// `quote(s)` de `time/format.go`: como `strconv.Quote`, mas sem depender de
/// `strconv`. [s] e o resultado são "strings de bytes" (um code unit por
/// byte do Go, ver [_bytesOf]). O Go percorre runas, mas toda runa não ASCII
/// (válida ou `RuneError` de 1 byte) e todo controle `< 0x20` sai byte a
/// byte em `\xHH`, então percorrer os bytes dá o mesmo resultado.
String _quote(String s) {
  final buf = StringBuffer()..write('"');
  for (final c in s.codeUnits) {
    if (c >= 0x80 || c < 0x20) {
      buf
        ..write(r'\x')
        ..write(_lowerhex[c >> 4])
        ..write(_lowerhex[c & 0xf]);
    } else if (c == 0x22 || c == 0x5c) {
      buf
        ..write('\\')
        ..writeCharCode(c);
    } else {
      buf.writeCharCode(c);
    }
  }
  buf.write('"');
  return buf.toString();
}

/// Os bytes de uma string Go como string Dart de um code unit por byte:
/// índices e comprimentos em bytes, como no Go (UTF-8 inválido intacto).
String _bytesOf(Golang.String s) => String.fromCharCodes(s.toBytes());

/// Volta de [_bytesOf].
Golang.String _fromByteString(String s) =>
    Golang.String.fromBytes(Uint8List.fromList(s.codeUnits));
