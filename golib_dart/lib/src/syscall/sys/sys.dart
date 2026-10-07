/// Chamadas de sistema do shim `syscall` (decisão F1): a libc pelo
/// `sysffi` na VM (`vm.dart`, só por `if (dart.library.ffi)`); no dart2js e
/// no dart2wasm, `stub.dart`, que falha como o Go em js/wasm (F4).
///
/// Todas devolvem `>= 0` ou `-errno` (numeração do linux), como o
/// `sysffi`; o shim converte para `syscall.Errno`.
library;

export 'stub.dart' if (dart.library.ffi) 'vm.dart';
