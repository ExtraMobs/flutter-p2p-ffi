/// Ponto de entrada da rede FFI (F1): `vm.dart` só quando `dart:ffi` existe;
/// no dart2js e no dart2wasm, `stub.dart` (que nunca importa `dart:ffi`).
library;

export 'stub.dart' if (dart.library.ffi) 'vm.dart';
