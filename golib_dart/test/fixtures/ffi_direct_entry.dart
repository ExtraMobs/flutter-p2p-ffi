// Controle negativo do F1: importar a rede FFI sem o import condicional.
// O dart2js e o dart2wasm têm de recusar (`dart:ffi` não existe lá);
// `test/net_ffi_test.dart` confere.
import 'package:golib_dart/src/net/sys/ffi/vm.dart';

void main() => print('ffi $sysFfiAvailable');
