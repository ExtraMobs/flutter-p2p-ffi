// Entrada que importa o shim `net` (e o motor `sys.dart`, que reexporta o
// ponto condicional da rede FFI): `test/net_ffi_test.dart` compila com
// dart2js e dart2wasm, que recusariam se `dart:ffi` fosse alcançado (F1), e
// roda na VM e no Node.
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/net.dart' as net;
import 'package:golib_dart/src/net/sys/sys.dart';

void main() {
  print('ffi ${sysFfiAvailable}');
  print(
    'ip ${net.parseIP(Golang.String.fromDart('127.0.0.1')).isNil ? 'nil' : 'ok'}',
  );
}
